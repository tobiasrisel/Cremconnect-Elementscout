-- Phase 1 · Migration 3/9 – Zwischenebene: Extraktion, Abschnitte, Fakten, Prüfung, Freigabe

create schema if not exists ext;
comment on schema ext is 'Zwischenebene: technisch zerlegte Inhalte mit Modell, Version und Konfidenz. Status roh → geprueft → freigegeben.';

create table ext.extraktionslauf (
  id                  uuid primary key default gen_random_uuid(),
  dokument_version_id uuid not null references roh.dokument_version(id),
  aufgabe             text not null check (aufgabe in ('extraktion','embedding','klassifikation','zusammenfassung')),
  modell_id           uuid references einstellung.modell(id),
  modell              text not null,           -- Kopie zum Zeitpunkt des Laufs
  prompt_version      text not null,
  schema_version      text not null,
  gestartet_am        timestamptz not null default now(),
  beendet_am          timestamptz,
  status              text not null default 'laeuft' check (status in ('laeuft','ok','fehler')),
  token_ein           int,
  token_aus           int,
  fehler              text
);
create index extraktionslauf_dv_idx on ext.extraktionslauf (dokument_version_id);
create trigger extraktionslauf_nur_abschluss before update or delete on ext.extraktionslauf
  for each row execute function ops.nur_spalten_aenderbar('beendet_am','status','token_ein','token_aus','fehler');

create table ext.abschnitt (
  id                  uuid primary key default gen_random_uuid(),
  dokument_version_id uuid not null references roh.dokument_version(id),
  extraktionslauf_id  uuid not null references ext.extraktionslauf(id),
  position            int  not null,
  ueberschrift        text,
  text                text not null,
  seite_von           int,
  seite_bis           int,
  embedding           extensions.halfvec(3072),
  embedding_modell    text,
  unique (extraktionslauf_id, position)
);
comment on table ext.abschnitt is 'Textabschnitte eines Dokuments für Suche und Belegstellen. Unveränderlich.';
create index abschnitt_dv_idx on ext.abschnitt (dokument_version_id);
create index abschnitt_embedding_idx on ext.abschnitt using hnsw (embedding extensions.halfvec_cosine_ops);
create trigger abschnitt_unveraenderlich before update or delete on ext.abschnitt
  for each row execute function ops.unveraenderlich();

create table ext.fakt (
  id                  uuid primary key default gen_random_uuid(),
  extraktionslauf_id  uuid not null references ext.extraktionslauf(id),
  dokument_version_id uuid not null references roh.dokument_version(id),
  abschnitt_id        uuid references ext.abschnitt(id),
  fakttyp             text not null check (fakttyp in (
                        'produkt','produktmerkmal','hersteller','ausschreibungstext',
                        'kostenkennwert','wartungsangabe','normbezug','marktinfo')),
  gegenstand          jsonb not null default '{}',  -- {hersteller, familie, modell, artikelnummer, ...}
  merkmal             text,
  wert_text           text,
  wert_zahl           numeric,
  wert_von            numeric,
  wert_bis            numeric,
  einheit             text,
  bezugsgroesse       text,                         -- z. B. 'je m²', 'je Stück'
  region              text,
  stand               date,
  belegstelle         text,                         -- Zitat oder Seite im Dokument
  konfidenz           numeric(4,3) not null check (konfidenz between 0 and 1),
  status              text not null default 'roh'
                      check (status in ('roh','geprueft','freigegeben','verworfen','ersetzt')),
  version             int  not null default 1 check (version >= 1),
  vorgaenger_id       uuid references ext.fakt(id),
  erstellt_am         timestamptz not null default now(),
  -- Keine Zahl ohne Bezug: Kennwerte brauchen Wert und Bezugsgröße.
  constraint fakt_kennwert_vollstaendig check (
    fakttyp <> 'kostenkennwert'
    or (bezugsgroesse is not null and coalesce(wert_zahl, wert_von, wert_bis) is not null)),
  constraint fakt_spanne_geordnet check (wert_von is null or wert_bis is null or wert_von <= wert_bis),
  constraint fakt_version_mit_vorgaenger check ((version = 1) = (vorgaenger_id is null))
);
comment on table ext.fakt is 'Ein zerlegter Fakt mit Herkunft (Dokumentversion, Lauf, Belegstelle). Inhalt unveränderlich; nur der Status wechselt über ext.fakt_status_setzen.';
create index fakt_dv_idx on ext.fakt (dokument_version_id);
create index fakt_status_idx on ext.fakt (status, fakttyp);
create index fakt_gegenstand_idx on ext.fakt using gin (gegenstand);

create table ext.statuswechsel (
  id          uuid primary key default gen_random_uuid(),
  fakt_id     uuid not null references ext.fakt(id),
  von         text not null,
  nach        text not null,
  grund       text,
  durch       text not null,          -- Person oder 'auto'
  automatisch boolean not null default false,
  am          timestamptz not null default now()
);
create index statuswechsel_fakt_idx on ext.statuswechsel (fakt_id, am);
create trigger statuswechsel_unveraenderlich before update or delete on ext.statuswechsel
  for each row execute function ops.unveraenderlich();

create table ext.pruefbefund (
  id       uuid primary key default gen_random_uuid(),
  fakt_id  uuid not null references ext.fakt(id),
  regel    text not null,             -- z. B. 'einheit_vorhanden', 'plausibel', 'dublette', 'widerspruch'
  ergebnis text not null check (ergebnis in ('ok','warnung','fehler')),
  detail   text,
  bezug_fakt_id uuid references ext.fakt(id),   -- bei Dublette/Widerspruch der andere Fakt
  am       timestamptz not null default now()
);
create index pruefbefund_fakt_idx on ext.pruefbefund (fakt_id);
create trigger pruefbefund_unveraenderlich before update or delete on ext.pruefbefund
  for each row execute function ops.unveraenderlich();

-- Inhalt eines Fakts ist unveränderlich; Status nur über ext.fakt_status_setzen.
create or replace function ext.fakt_schutz()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'Fakten werden nicht gelöscht, sondern verworfen.' using errcode = 'P0001';
  end if;
  if (to_jsonb(old) - 'status') is distinct from (to_jsonb(new) - 'status') then
    raise exception 'Inhalt eines Fakts ist unveränderlich. Korrektur = neue Version mit vorgaenger_id.' using errcode = 'P0001';
  end if;
  if old.status is distinct from new.status
     and coalesce(current_setting('wissen.statuswechsel', true), '') <> 'an' then
    raise exception 'Status nur über ext.fakt_status_setzen ändern (Protokollpflicht).' using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger fakt_schutz before update or delete on ext.fakt
  for each row execute function ext.fakt_schutz();

create or replace function ext.fakt_status_setzen(
  p_fakt_id uuid, p_nach text, p_grund text, p_durch text, p_automatisch boolean default false)
returns void language plpgsql set search_path = '' as $$
declare
  v_von text; v_typ text;
  v_ausgenommen jsonb;
begin
  select status, fakttyp into v_von, v_typ from ext.fakt where id = p_fakt_id for update;
  if v_von is null then
    raise exception 'Fakt % nicht gefunden.', p_fakt_id;
  end if;
  if p_nach not in ('roh','geprueft','freigegeben','verworfen','ersetzt') then
    raise exception 'Unbekannter Status %.', p_nach;
  end if;
  if v_von = p_nach then
    return;
  end if;
  if p_durch is null or btrim(p_durch) = '' then
    raise exception 'Statuswechsel braucht eine verantwortliche Person oder ''auto''.';
  end if;
  -- E13: bestimmte Fakttypen nie automatisch freigeben (Kostenkennwerte → Person und Datum)
  select wert into v_ausgenommen from einstellung.parameter where schluessel = 'auto_freigabe_ausgenommen';
  if p_automatisch and p_nach = 'freigegeben'
     and coalesce(v_ausgenommen, '[]'::jsonb) ? v_typ then
    raise exception 'Fakttyp % darf nicht automatisch freigegeben werden (E13).', v_typ using errcode = 'P0001';
  end if;

  perform set_config('wissen.statuswechsel', 'an', true);
  update ext.fakt set status = p_nach where id = p_fakt_id;
  perform set_config('wissen.statuswechsel', '', true);

  insert into ext.statuswechsel (fakt_id, von, nach, grund, durch, automatisch)
  values (p_fakt_id, v_von, p_nach, p_grund, p_durch, p_automatisch);
end $$;

-- E6: ab Schwelle automatisch frei, wenn keine Prüfregel 'fehler' meldet und der Typ nicht ausgenommen ist.
-- Gibt true zurück, wenn freigegeben wurde; sonst bleibt der Fakt für den Tagesbericht offen.
create or replace function ext.auto_freigabe(p_fakt_id uuid)
returns boolean language plpgsql set search_path = '' as $$
declare
  v_schwelle numeric := einstellung.zahl('auto_freigabe_schwelle');
  v_ausgenommen jsonb;
  f record;
begin
  select * into f from ext.fakt where id = p_fakt_id;
  select wert into v_ausgenommen from einstellung.parameter where schluessel = 'auto_freigabe_ausgenommen';
  if f.id is null or f.status <> 'roh' or v_schwelle is null then
    return false;
  end if;
  if coalesce(v_ausgenommen, '[]'::jsonb) ? f.fakttyp then
    return false;
  end if;
  if f.konfidenz < v_schwelle then
    return false;
  end if;
  if exists (select 1 from ext.pruefbefund b where b.fakt_id = f.id and b.ergebnis = 'fehler') then
    return false;
  end if;
  perform ext.fakt_status_setzen(f.id, 'freigegeben',
    format('Konfidenz %s ≥ Schwelle %s, keine Prüffehler', f.konfidenz, v_schwelle), 'auto', true);
  return true;
end $$;

-- Altbestand der Preisregeln aus ElementScout (Phase 0). Status roh: ohne Einzelbeleg.
create table ext.preisregel_altbestand (
  id                     uuid primary key,
  art                    text not null check (art in ('herstellerregel','preisdeckel')),
  reihenfolge            int  not null,
  hersteller             text,
  bezeichnung            text,
  muster                 text not null,
  muster_flags           text not null default '',
  marktpreis_netto_max   numeric not null,
  ersatzkosten_netto_max numeric not null,
  waehrung               text not null default 'EUR',
  quellenangabe_alt      text,
  quelle_id              uuid not null references kw.quelle(id),
  herkunft_commit        text not null,
  status                 text not null default 'roh' check (status in ('roh','geprueft','freigegeben','verworfen','ersetzt')),
  unique (art, reihenfolge),
  check ((art = 'herstellerregel') = (hersteller is not null))
);
comment on table ext.preisregel_altbestand is 'Wortgleiche Übernahme der Regex-Preisregeln aus analyze-component (Commit ed03c8f0). Reihenfolge ist fachlich relevant: erste passende Regel gewinnt.';
create trigger preisregel_altbestand_nur_status before update or delete on ext.preisregel_altbestand
  for each row execute function ops.nur_spalten_aenderbar('status');
