-- Stellvertreter für die Supabase-Umgebung und den Ist-Stand von kw (Stand 29.10.2026),
-- damit die Migrationen lokal in PGlite laufen. Nur für Tests.

create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;

create schema extensions;
create schema storage;
create table storage.buckets (id text primary key, name text not null, public boolean default false);

create schema kw;
create type kw.quellenart as enum ('bauprojekt','auftragshistorie','betriebskostenabrechnung','amtliche_statistik','kostendatenbank','hersteller','haendler','schaetzung');
create type kw.weitergabe as enum ('frei','intern','auf_anfrage');

create table kw.quelle (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  bezeichnung text not null,
  art kw.quellenart not null,
  herausgeber text,
  url text,
  weitergabe kw.weitergabe not null default 'intern',
  lizenzhinweis text,
  lizenz_geprueft_am date,
  lizenz_geprueft_von text,
  abrufintervall interval,
  letzter_abruf timestamptz,
  ist_aktiv boolean not null default true,
  erstellt_am timestamptz not null default now()
);
insert into kw.quelle (code, bezeichnung, art, weitergabe, abrufintervall, ist_aktiv) values
  ('BKI_ALTBAU','BKI Baukosten Altbau','kostendatenbank','intern','1 year',false),
  ('DESTATIS_61262','Baupreisindex Instandhaltung Wohngebaeude','amtliche_statistik','frei','3 mons',true),
  ('EIGENE_IH','Auftragshistorie laufende Instandhaltung','auftragshistorie','frei','3 mons',true),
  ('EPA_2016','Einheitspreisabkommen und Meldungskatalog 2016','bauprojekt','frei','1 year',true),
  ('SIRADOS','sirAdos Baudaten','kostendatenbank','intern','1 year',false),
  ('SWSG_BK_2016','Baukostenermittlungen Modernisierung 2016','bauprojekt','frei',null,true);

create table kw.hersteller (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  bereich text,
  url text,
  katalog_offen boolean,
  preise_offen boolean,
  bemerkung text,
  erstellt_am timestamptz not null default now()
);
insert into kw.hersteller (code, name) values
  ('BUDERUS','Buderus'),('GC','GC-Gruppe'),('GRUNDFOS','Grundfos'),('RAABKARCHER','Raab Karcher'),
  ('VAILLANT','Vaillant'),('VIESSMANN','Viessmann'),('WILO','Wilo SE');
