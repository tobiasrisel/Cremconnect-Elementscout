-- Phase 1 · Migration 5/9 – Gespiegeltes Register aus cc-core und Zuordnungen (E7)
-- cc-core bleibt führend. Hier nur Lesekopie, ohne harte Fremdschlüssel nach cc-core.
-- Die Spiegelung (Befüllung) folgt in Phase 2 als geplanter Abgleich.

create schema if not exists map;
comment on schema map is 'Register aus cc-core (technische Anlagen, Baugruppen, Elemente) als Suchliste und Zuordnungen des Wissens dazu. GEFMA-Kataloge nur intern nutzen (Lizenz).';

create table map.katalog (
  code            text primary key,        -- wie kat.katalog.code in cc-core, z. B. 'GEFMA_924_2', 'IH_BAUTEIL'
  name            text not null,
  herausgeber     text,
  lizenzpflichtig boolean not null,
  fassung         text not null,
  quelle_system   text not null default 'cc-core',
  gespiegelt_am   timestamptz not null default now()
);

create table map.register_knoten (
  id             uuid primary key,          -- = kat.knoten.id in cc-core (kein FK, anderes Projekt)
  katalog_code   text not null references map.katalog(code),
  code           text not null,             -- Codes als Text (GEFMA-Regel 6)
  parent_id      uuid,                       -- is-part-of / Katalogbaum wie in cc-core
  ebene          int,
  bezeichnung    text not null,
  din276_kg      text check (din276_kg ~ '^[0-9]{3}$'),
  im_suchumfang  boolean not null default false,   -- E7: KG 300–500
  suchbegriffe   text[] not null default '{}',
  gespiegelt_am  timestamptz not null default now(),
  gueltig_bis    date,
  unique (katalog_code, code)
);
create index register_knoten_suchumfang on map.register_knoten (katalog_code) where im_suchumfang;
create index register_knoten_bez_trgm on map.register_knoten using gin (bezeichnung extensions.gin_trgm_ops);

create table map.register_element (
  id                  uuid primary key default gen_random_uuid(),
  art                 text not null check (art in ('elementtyp','bauelement')),
  cc_core_id          uuid,                 -- tdd.elementtyp.id (bauelement hat nur einen Code)
  code                text not null,
  typ_nr              int,
  bezeichnung         text not null,
  baugruppe_knoten_id uuid references map.register_knoten(id),
  din276_kg           text check (din276_kg ~ '^[0-9]{3}$'),
  im_suchumfang       boolean not null default false,
  gespiegelt_am       timestamptz not null default now(),
  gueltig_bis         date,
  unique (art, code, typ_nr)
);
create index register_element_bez_trgm on map.register_element using gin (bezeichnung extensions.gin_trgm_ops);

-- Wissen ↔ Register (n:m). Genau ein Registerziel je Zeile.
create table map.zuordnung (
  id                  uuid primary key default gen_random_uuid(),
  ziel_art            text not null check (ziel_art in ('fakt','produkt','ausschreibungsposition','abschnitt','wiki_artikel','lernfall')),
  ziel_id             uuid not null,
  register_knoten_id  uuid references map.register_knoten(id),
  register_element_id uuid references map.register_element(id),
  beziehung           text not null default 'ist' check (beziehung in ('ist','teil_von','verwandt')),
  konfidenz           numeric(4,3) check (konfidenz between 0 and 1),
  herkunft            text not null check (herkunft in ('ki','regel','manuell')),
  modell              text,
  erstellt_am         timestamptz not null default now(),
  erstellt_von        text not null,
  gueltig_bis         date,
  check (num_nonnulls(register_knoten_id, register_element_id) = 1)
);
create unique index zuordnung_eindeutig on map.zuordnung
  (ziel_art, ziel_id, coalesce(register_knoten_id, register_element_id), beziehung) where gueltig_bis is null;
create index zuordnung_knoten_idx on map.zuordnung (register_knoten_id) where gueltig_bis is null;
create trigger zuordnung_nur_schliessen before update or delete on map.zuordnung
  for each row execute function ops.nur_spalten_aenderbar('gueltig_bis');

-- Austauschbarkeit der Kataloge (GEFMA ↔ DIN 276 ↔ IFC): Zugriff nur über Mapping (Lizenzhinweis im Skill)
create table map.klassifikation_mapping (
  id           uuid primary key default gen_random_uuid(),
  von_katalog  text not null,
  von_code     text not null,
  nach_katalog text not null,
  nach_code    text not null,
  beziehung    text not null check (beziehung in ('gleich','enthalten_in','enthaelt','ueberlappt')),
  quelle       text not null,
  erstellt_am  timestamptz not null default now(),
  unique (von_katalog, von_code, nach_katalog, nach_code)
);
