-- Phase 1 · Migration 1/9 – Grundlagen, Hilfsfunktionen, Einstellungen
-- Wissens-DB juluzutgabkiqnoaggxe. Bestehendes Schema kw bleibt unverändert (E12).

create extension if not exists vector with schema extensions;
create extension if not exists pg_trgm with schema extensions;

create schema if not exists ops;          -- Betrieb: Läufe, Fehler, Berichte, Hilfsfunktionen
create schema if not exists einstellung;  -- Schwellen, Schalter, Modellwahl, Datentöpfe

comment on schema ops is 'Betrieb der Wissens-DB: Crawl-Läufe, Fehler, Tagesberichte, gemeinsame Hilfsfunktionen.';
comment on schema einstellung is 'Einstellungen, die ohne Deployment änderbar sein müssen (E4, E5, E6). Jede Änderung wird protokolliert.';

-- ---------------------------------------------------------------
-- Hilfsfunktionen (Regel: nie überschreiben, immer versionieren)
-- ---------------------------------------------------------------

-- Blockiert UPDATE und DELETE vollständig (Rohdokumente, Abschnitte, Protokolle).
create or replace function ops.unveraenderlich()
returns trigger language plpgsql set search_path = '' as $$
begin
  raise exception 'Tabelle %.% ist unveränderlich: % nicht erlaubt. Neue Version anlegen.',
    tg_table_schema, tg_table_name, tg_op using errcode = 'P0001';
end $$;

-- Erlaubt UPDATE nur auf den als Argument genannten Spalten, DELETE nie.
-- Beispiel: execute function ops.nur_spalten_aenderbar('status','gueltig_bis','ersetzt_durch')
create or replace function ops.nur_spalten_aenderbar()
returns trigger language plpgsql set search_path = '' as $$
declare
  erlaubt text[] := tg_argv;
  alt jsonb; neu jsonb; k text;
begin
  if tg_op = 'DELETE' then
    raise exception 'Löschen in %.% nicht erlaubt. Gültigkeit beenden statt löschen.',
      tg_table_schema, tg_table_name using errcode = 'P0001';
  end if;
  alt := to_jsonb(old); neu := to_jsonb(new);
  foreach k in array erlaubt loop
    alt := alt - k; neu := neu - k;
  end loop;
  if alt is distinct from neu then
    raise exception 'In %.% dürfen nur diese Spalten geändert werden: %. Inhalt ändern = neue Version.',
      tg_table_schema, tg_table_name, array_to_string(erlaubt, ', ') using errcode = 'P0001';
  end if;
  return new;
end $$;

create or replace function ops.setze_geaendert_am()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.geaendert_am := now();
  return new;
end $$;

-- ---------------------------------------------------------------
-- Einstellungen
-- ---------------------------------------------------------------

create table einstellung.parameter (
  schluessel   text primary key,
  wert         jsonb not null,
  beschreibung text not null,
  geaendert_am timestamptz not null default now(),
  geaendert_von text not null default 'migration'
);
comment on table einstellung.parameter is 'Schwellen und Schalter. Werte als JSON, Änderungen landen in parameter_historie.';

create table einstellung.parameter_historie (
  id           uuid primary key default gen_random_uuid(),
  schluessel   text not null,
  wert_alt     jsonb,
  wert_neu     jsonb,
  geaendert_am timestamptz not null default now(),
  geaendert_von text not null
);

create or replace function einstellung.parameter_protokollieren()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'UPDATE' then
    new.geaendert_am := now();
    insert into einstellung.parameter_historie (schluessel, wert_alt, wert_neu, geaendert_von)
    values (new.schluessel, old.wert, new.wert, new.geaendert_von);
  elsif tg_op = 'INSERT' then
    insert into einstellung.parameter_historie (schluessel, wert_alt, wert_neu, geaendert_von)
    values (new.schluessel, null, new.wert, new.geaendert_von);
  end if;
  return new;
end $$;

create trigger parameter_protokoll
  before insert or update on einstellung.parameter
  for each row execute function einstellung.parameter_protokollieren();
create trigger parameter_historie_unveraenderlich
  before update or delete on einstellung.parameter_historie
  for each row execute function ops.unveraenderlich();

-- Lesezugriff mit Typ, damit Funktionen keine Zahlen im Code tragen.
create or replace function einstellung.zahl(p_schluessel text)
returns numeric language sql stable set search_path = '' as $$
  select (wert #>> '{}')::numeric from einstellung.parameter where schluessel = p_schluessel
$$;

create table einstellung.modell (
  id          uuid primary key default gen_random_uuid(),
  aufgabe     text not null check (aufgabe in ('extraktion','embedding','analyse','klassifikation','zusammenfassung')),
  anbieter    text not null,                -- z. B. 'lovable-gateway' (E5)
  modell      text not null,                -- z. B. 'google/gemini-2.5-flash'
  dimensionen int,                          -- nur für Embeddings
  parameter   jsonb not null default '{}',
  aktiv       boolean not null default true,
  gueltig_ab  timestamptz not null default now(),
  gueltig_bis timestamptz,
  bemerkung   text
);
comment on table einstellung.modell is 'Modellwahl je Aufgabe (E5). Genau ein aktives Modell je Aufgabe. Wechsel = neue Zeile, alte bekommt gueltig_bis.';
create unique index modell_ein_aktives_je_aufgabe on einstellung.modell (aufgabe) where aktiv;
create trigger modell_nur_schliessen
  before update or delete on einstellung.modell
  for each row execute function ops.nur_spalten_aenderbar('aktiv','gueltig_bis','bemerkung');

create table einstellung.datentopf (
  id           uuid primary key default gen_random_uuid(),
  code         text not null unique,
  bezeichnung  text not null,
  zielbereich  text not null check (zielbereich in ('wissen','kennwert','wiki','lern')),
  beschreibung text,
  aktiv        boolean not null default true,
  erstellt_am  timestamptz not null default now(),
  geaendert_am timestamptz
);
comment on table einstellung.datentopf is 'Datentöpfe für die Management-Oberfläche (E4). Jede Quelle gehört zu genau einem Topf.';
create trigger datentopf_geaendert before update on einstellung.datentopf
  for each row execute function ops.setze_geaendert_am();

-- ---------------------------------------------------------------
-- Ein Quellenregister: kw.quelle wird erweitert, nicht dupliziert (E12)
-- Bestehende Spalten und Zeilen von kw.quelle bleiben unverändert.
-- ---------------------------------------------------------------

alter table kw.quelle
  add column datentopf_id       uuid references einstellung.datentopf(id),
  add column quelltyp           text check (quelltyp in ('datenblatt','ausschreibung','kennwert','markt','fachartikel','lernfall','altbestand')),
  add column domain             text,
  add column nutzungsrecht      text not null default 'unklar'
             check (nutzungsrecht in ('frei','mit_quellenangabe','lizenz','unklar','verboten')),
  add column crawl_regel        jsonb not null default '{}',
  add column robots_geprueft_am date,
  add column agb_geprueft_am    date,
  add column naechster_lauf     timestamptz,
  add column geaendert_am       timestamptz;

-- E1: Gecrawlt wird nur, was öffentlich und erlaubt ist. Lizenzquellen nur per Import.
alter table kw.quelle add constraint quelle_crawl_nur_wenn_erlaubt
  check (not (ist_aktiv and crawl_regel <> '{}'::jsonb)
         or nutzungsrecht in ('frei','mit_quellenangabe'));

comment on column kw.quelle.crawl_regel is 'Firecrawl-Einstellungen je Quelle (Start-URLs, Include/Exclude, Tiefe, Formate). Leer = keine Crawl-Quelle.';
comment on column kw.quelle.nutzungsrecht is 'E1: frei / mit_quellenangabe dürfen gecrawlt werden; lizenz nur per Import; unklar und verboten nie.';

create trigger quelle_geaendert before update on kw.quelle
  for each row execute function ops.setze_geaendert_am();
