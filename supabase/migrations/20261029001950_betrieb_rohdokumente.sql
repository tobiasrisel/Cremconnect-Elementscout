-- Phase 1 · Migration 2/9 – Crawl-Läufe und Rohdokumente
-- Rohdokumente werden nie überschrieben: jede inhaltliche Änderung ist eine neue Version (Regel 5).

create schema if not exists roh;
comment on schema roh is 'Rohdokumente: jede abgerufene Datei mit URL, Inhalts-Hash, Abrufdatum und Version. Originale im privaten Bucket roh-dokumente (E2).';

-- ---------------------------------------------------------------
-- Crawl-Läufe und Fehler
-- ---------------------------------------------------------------

create table ops.crawl_lauf (
  id                     uuid primary key default gen_random_uuid(),
  quelle_id              uuid not null references kw.quelle(id),
  gestartet_am           timestamptz not null default now(),
  beendet_am             timestamptz,
  status                 text not null default 'laeuft'
                         check (status in ('laeuft','ok','teilweise','fehler','abgebrochen')),
  ausgeloest_durch       text not null default 'zeitplan',   -- zeitplan | manuell:<name>
  firecrawl_job_id       text,
  seiten_gefunden        int not null default 0,
  dokumente_neu          int not null default 0,
  dokumente_geaendert    int not null default 0,
  dokumente_unveraendert int not null default 0,
  fehler_anzahl          int not null default 0,
  credits                numeric,
  bemerkung              text
);
comment on table ops.crawl_lauf is 'Ein Lauf je Quelle und Zeitpunkt. Ersetzt für den neuen Crawler kw.crawllauf (E12).';
create index crawl_lauf_quelle_idx on ops.crawl_lauf (quelle_id, gestartet_am desc);
-- Zähler und Abschluss dürfen sich während des Laufs ändern, Herkunft nicht.
create trigger crawl_lauf_nur_fortschritt
  before update or delete on ops.crawl_lauf
  for each row execute function ops.nur_spalten_aenderbar(
    'beendet_am','status','firecrawl_job_id','seiten_gefunden','dokumente_neu',
    'dokumente_geaendert','dokumente_unveraendert','fehler_anzahl','credits','bemerkung');

create table ops.fehler (
  id            uuid primary key default gen_random_uuid(),
  crawl_lauf_id uuid references ops.crawl_lauf(id),
  url           text,
  phase         text not null check (phase in ('abruf','ablage','extraktion','pruefung','freigabe','bericht','sonstiges')),
  meldung       text not null,
  details       jsonb not null default '{}',
  am            timestamptz not null default now()
);
create index fehler_lauf_idx on ops.fehler (crawl_lauf_id);
create trigger fehler_unveraenderlich before update or delete on ops.fehler
  for each row execute function ops.unveraenderlich();

-- ---------------------------------------------------------------
-- Rohdokumente
-- ---------------------------------------------------------------

create table roh.dokument (
  id                   uuid primary key default gen_random_uuid(),
  quelle_id            uuid not null references kw.quelle(id),
  url                  text not null unique,
  dokumentart          text not null default 'sonstiges'
                       check (dokumentart in ('pdf','html','bild','tabelle','sonstiges')),
  erstmals_gefunden_am timestamptz not null default now(),
  zuletzt_gesehen_am   timestamptz not null default now(),
  ist_verschwunden     boolean not null default false
);
comment on table roh.dokument is 'Eine Zeile je URL. Inhalte stehen ausschließlich in dokument_version.';
create index dokument_quelle_idx on roh.dokument (quelle_id);
create trigger dokument_nur_sichtung
  before update or delete on roh.dokument
  for each row execute function ops.nur_spalten_aenderbar('zuletzt_gesehen_am','ist_verschwunden','dokumentart');

create table roh.dokument_version (
  id             uuid primary key default gen_random_uuid(),
  dokument_id    uuid not null references roh.dokument(id),
  version        int  not null check (version >= 1),
  inhalt_sha256  text not null check (inhalt_sha256 ~ '^[0-9a-f]{64}$'),
  abgerufen_am   timestamptz not null default now(),
  crawl_lauf_id  uuid references ops.crawl_lauf(id),
  http_status    int,
  mime_typ       text,
  groesse_bytes  bigint,
  storage_pfad   text,            -- Pfad im Bucket roh-dokumente (Original, E2)
  text_inhalt    text,            -- extrahierter Text / Markdown des Abrufs
  metadaten      jsonb not null default '{}',
  unique (dokument_id, version),
  unique (dokument_id, inhalt_sha256)
);
comment on table roh.dokument_version is 'Unveränderlich. Gleicher Hash = keine neue Version (Änderungserkennung). Jede Zahl in ext/ref führt hierher zurück.';
create index dokument_version_lauf_idx on roh.dokument_version (crawl_lauf_id);
create trigger dokument_version_unveraenderlich before update or delete on roh.dokument_version
  for each row execute function ops.unveraenderlich();

-- Legt eine Version an, wenn sich der Inhalt geändert hat. Gibt die Version zurück und ob sie neu ist.
create or replace function roh.version_anlegen(
  p_quelle_id uuid, p_url text, p_inhalt_sha256 text,
  p_crawl_lauf_id uuid default null, p_dokumentart text default 'sonstiges',
  p_http_status int default null, p_mime_typ text default null, p_groesse_bytes bigint default null,
  p_storage_pfad text default null, p_text_inhalt text default null, p_metadaten jsonb default '{}')
returns table (dokument_id uuid, dokument_version_id uuid, version int, ist_neu boolean)
language plpgsql set search_path = '' as $$
declare
  v_dok uuid; v_ver uuid; v_nr int;
begin
  insert into roh.dokument (quelle_id, url, dokumentart)
  values (p_quelle_id, p_url, p_dokumentart)
  on conflict (url) do update set zuletzt_gesehen_am = now(), ist_verschwunden = false
  returning id into v_dok;

  select dv.id, dv.version into v_ver, v_nr
  from roh.dokument_version dv
  where dv.dokument_id = v_dok and dv.inhalt_sha256 = p_inhalt_sha256;

  if v_ver is not null then
    return query select v_dok, v_ver, v_nr, false;
    return;
  end if;

  select coalesce(max(dv.version), 0) + 1 into v_nr
  from roh.dokument_version dv where dv.dokument_id = v_dok;

  insert into roh.dokument_version (dokument_id, version, inhalt_sha256, crawl_lauf_id, http_status,
                                    mime_typ, groesse_bytes, storage_pfad, text_inhalt, metadaten)
  values (v_dok, v_nr, p_inhalt_sha256, p_crawl_lauf_id, p_http_status,
          p_mime_typ, p_groesse_bytes, p_storage_pfad, p_text_inhalt, coalesce(p_metadaten, '{}'))
  returning id into v_ver;

  return query select v_dok, v_ver, v_nr, true;
end $$;

-- Privater Bucket für Originale (E2). Weitergabe nach außen nur je Quelle geprüft.
insert into storage.buckets (id, name, public)
values ('roh-dokumente', 'roh-dokumente', false)
on conflict (id) do nothing;
