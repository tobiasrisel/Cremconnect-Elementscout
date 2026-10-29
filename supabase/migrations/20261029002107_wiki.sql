-- Phase 1 · Migration 6/9 – Fachartikel für das Wiki (E8: eigener Bereich in derselben DB)

create schema if not exists wiki;
comment on schema wiki is 'Fachartikel für das Wiki. Gleiche Pipeline wie das übrige Wissen: Quelle → Rohdokument → Artikel/Abschnitte.';

create table wiki.artikel (
  id                  uuid primary key default gen_random_uuid(),
  dokument_version_id uuid not null references roh.dokument_version(id),
  extraktionslauf_id  uuid references ext.extraktionslauf(id),
  titel               text not null,
  autor               text,
  herausgeber         text,
  veroeffentlicht_am  date,
  sprache             text not null default 'de',
  zusammenfassung     text,
  status              text not null default 'roh' check (status in ('roh','geprueft','freigegeben','verworfen','ersetzt')),
  version             int  not null default 1 check (version >= 1),
  vorgaenger_id       uuid references wiki.artikel(id),
  erstellt_am         timestamptz not null default now(),
  check ((version = 1) = (vorgaenger_id is null))
);
create index artikel_titel_trgm on wiki.artikel using gin (titel extensions.gin_trgm_ops);
create trigger artikel_nur_status before update or delete on wiki.artikel
  for each row execute function ops.nur_spalten_aenderbar('status');

create table wiki.abschnitt (
  id               uuid primary key default gen_random_uuid(),
  artikel_id       uuid not null references wiki.artikel(id),
  position         int  not null,
  ueberschrift     text,
  text             text not null,
  embedding        extensions.halfvec(3072),
  embedding_modell text,
  unique (artikel_id, position)
);
create index wiki_abschnitt_embedding_idx on wiki.abschnitt using hnsw (embedding extensions.halfvec_cosine_ops);
create trigger wiki_abschnitt_unveraenderlich before update or delete on wiki.abschnitt
  for each row execute function ops.unveraenderlich();
