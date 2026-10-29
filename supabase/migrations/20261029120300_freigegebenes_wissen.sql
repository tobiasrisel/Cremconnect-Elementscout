-- Phase 1 · Migration 4/9 – Freigegebenes Wissen
-- Kostenkennwerte bleiben in kw (E12, E13). Hier: Akteure, Produkte, Merkmale, Ausschreibungspositionen, Regelwerke.
-- Jede Zeile führt über herkunft_fakt_id auf Fakt → Dokumentversion → URL, Abrufdatum (Regel 4).

create schema if not exists ref;
comment on schema ref is 'Geprüftes und freigegebenes Wissen. Versioniert über gueltig_ab/gueltig_bis/ersetzt_durch, nie gelöscht.';

-- Regelwerke immer mit Fassung (GEFMA-Regel 4)
create table ref.regelwerk (
  id         uuid primary key default gen_random_uuid(),
  code       text not null unique,            -- z. B. 'VDMA_24186_1', 'BETRSICHV'
  titel      text not null,
  herausgeber text,
  art        text not null check (art in ('gesetz','verordnung','norm','richtlinie','technische_regel'))
);
create table ref.regelwerk_fassung (
  id           uuid primary key default gen_random_uuid(),
  regelwerk_id uuid not null references ref.regelwerk(id),
  ausgabe      text not null,                 -- z. B. '2018-12'
  gueltig_ab   date,
  gueltig_bis  date,
  herkunft_fakt_id uuid references ext.fakt(id),
  unique (regelwerk_id, ausgabe)
);

-- Akteure: natürliche und juristische Personen getrennt, Rollen n:m mit Zeitbezug (GEFMA-Regel 5)
create table ref.akteur (
  id               uuid primary key default gen_random_uuid(),
  name             text not null,
  personenart      text not null default 'juristische_person'
                   check (personenart in ('natuerliche_person','juristische_person')),
  website          text,
  land             text,
  kw_hersteller_id uuid unique references kw.hersteller(id),   -- Verknüpfung statt Kopie (E12)
  herkunft_fakt_id uuid references ext.fakt(id),
  erstellt_am      timestamptz not null default now(),
  gueltig_bis      date,
  constraint akteur_mit_herkunft check (kw_hersteller_id is not null or herkunft_fakt_id is not null)
);
create index akteur_name_trgm on ref.akteur using gin (name extensions.gin_trgm_ops);
create trigger akteur_nur_pflege before update or delete on ref.akteur
  for each row execute function ops.nur_spalten_aenderbar('website','land','gueltig_bis');

create table ref.akteur_rolle (
  id               uuid primary key default gen_random_uuid(),
  akteur_id        uuid not null references ref.akteur(id),
  rolle_code       text not null,             -- z. B. 'hersteller', 'haendler', 'herausgeber', 'verband'
  rolle_katalog    text not null default 'eigen',   -- 'eigen' oder 'GEFMA_924_7'
  kontext          text,
  gueltig_von      date not null default current_date,
  gueltig_bis      date,
  herkunft_fakt_id uuid references ext.fakt(id),
  unique (akteur_id, rolle_katalog, rolle_code, gueltig_von)
);
create trigger akteur_rolle_nur_schliessen before update or delete on ref.akteur_rolle
  for each row execute function ops.nur_spalten_aenderbar('gueltig_bis');

create table ref.produkt (
  id               uuid primary key default gen_random_uuid(),
  hersteller_id    uuid not null references ref.akteur(id),
  modellname       text not null,
  familie          text,
  artikelnummer    text,
  gtin             text,
  beschreibung     text,
  herkunft_fakt_id uuid not null references ext.fakt(id),
  status           text not null default 'freigegeben' check (status in ('geprueft','freigegeben','abgeloest')),
  gueltig_ab       date not null default current_date,
  gueltig_bis      date,
  ersetzt_durch    uuid references ref.produkt(id),
  erstellt_am      timestamptz not null default now()
);
create unique index produkt_aktuell_eindeutig on ref.produkt (hersteller_id, lower(modellname), coalesce(artikelnummer, ''))
  where gueltig_bis is null;
create index produkt_modell_trgm on ref.produkt using gin (modellname extensions.gin_trgm_ops);
create trigger produkt_nur_schliessen before update or delete on ref.produkt
  for each row execute function ops.nur_spalten_aenderbar('status','gueltig_bis','ersetzt_durch');

create table ref.produktmerkmal (
  id               uuid primary key default gen_random_uuid(),
  produkt_id       uuid not null references ref.produkt(id),
  merkmal_code     text not null,              -- z. B. 'nennleistung_kw', 'anschluss_dn'
  bezeichnung      text not null,
  wert_text        text,
  wert_zahl        numeric,
  einheit          text,
  herkunft_fakt_id uuid not null references ext.fakt(id),
  status           text not null default 'freigegeben' check (status in ('geprueft','freigegeben','abgeloest')),
  gueltig_ab       date not null default current_date,
  gueltig_bis      date,
  ersetzt_durch    uuid references ref.produktmerkmal(id),
  check (wert_text is not null or wert_zahl is not null)
);
create unique index produktmerkmal_aktuell on ref.produktmerkmal (produkt_id, merkmal_code) where gueltig_bis is null;
create trigger produktmerkmal_nur_schliessen before update or delete on ref.produktmerkmal
  for each row execute function ops.nur_spalten_aenderbar('status','gueltig_bis','ersetzt_durch');

-- Originale zum Produkt bereitstellen (E2)
create table ref.produktdokument (
  id                  uuid primary key default gen_random_uuid(),
  produkt_id          uuid not null references ref.produkt(id),
  dokument_version_id uuid not null references roh.dokument_version(id),
  rolle               text not null check (rolle in ('datenblatt','montageanleitung','wartungsanleitung',
                                                      'ausschreibungstext','zertifikat','preisliste','sonstiges')),
  erstellt_am         timestamptz not null default now(),
  unique (produkt_id, dokument_version_id, rolle)
);
create trigger produktdokument_unveraenderlich before update or delete on ref.produktdokument
  for each row execute function ops.unveraenderlich();

-- Ausschreibungspositionen. Codes als Text (GEFMA-Regel 6); Facility- und Service-Bezug (Regel 1) wo bekannt.
create table ref.ausschreibungsposition (
  id                uuid primary key default gen_random_uuid(),
  kurztext          text not null,
  langtext          text not null,
  einheit           text,
  din276_kg         text check (din276_kg ~ '^[0-9]{3}$'),
  facility_code     text,          -- GEFMA 924-2 / FAC-ID
  service_code      text,          -- GEFMA 924-3
  hersteller_neutral boolean not null,
  produkt_id        uuid references ref.produkt(id),
  herkunft_fakt_id  uuid not null references ext.fakt(id),
  status            text not null default 'freigegeben' check (status in ('geprueft','freigegeben','abgeloest')),
  gueltig_ab        date not null default current_date,
  gueltig_bis       date,
  ersetzt_durch     uuid references ref.ausschreibungsposition(id),
  erstellt_am       timestamptz not null default now(),
  check (hersteller_neutral or produkt_id is not null)
);
create index ausschreibung_kg_idx on ref.ausschreibungsposition (din276_kg) where gueltig_bis is null;
create index ausschreibung_text_trgm on ref.ausschreibungsposition using gin (kurztext extensions.gin_trgm_ops);
create trigger ausschreibung_nur_schliessen before update or delete on ref.ausschreibungsposition
  for each row execute function ops.nur_spalten_aenderbar('status','gueltig_bis','ersetzt_durch');
