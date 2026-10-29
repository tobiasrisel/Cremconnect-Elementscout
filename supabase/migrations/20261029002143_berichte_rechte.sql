-- Phase 1 · Migration 8/9 – Tagesbericht, Kennzahlen, RLS und Rechte

-- ---------------------------------------------------------------
-- Tagesbericht neuer Dokumente (E6) und Wochenkennzahlen
-- ---------------------------------------------------------------

create table ops.tagesbericht (
  id               uuid primary key default gen_random_uuid(),
  tag              date not null unique,
  erstellt_am      timestamptz not null default now(),
  inhalt           jsonb not null,           -- neue Dokumente, offene Fakten < Schwelle, Kennwerte zur Prüfung
  anzahl_dokumente int not null default 0,
  anzahl_offen     int not null default 0,
  versendet_am     timestamptz,
  versendet_an     text
);
create trigger tagesbericht_nur_versand before update or delete on ops.tagesbericht
  for each row execute function ops.nur_spalten_aenderbar('versendet_am','versendet_an');

-- Offene Fakten für den Tagesbericht: alles im Status roh (unter Schwelle, mit Prüffehler oder ausgenommener Typ).
create view ops.offene_fakten with (security_invoker = true) as
select f.id, f.fakttyp, f.merkmal, f.wert_text, f.wert_zahl, f.einheit, f.konfidenz, f.erstellt_am,
       d.url, dv.version, dv.abgerufen_am, q.code as quelle,
       exists (select 1 from ext.pruefbefund b where b.fakt_id = f.id and b.ergebnis = 'fehler') as hat_pruefFehler
from ext.fakt f
join roh.dokument_version dv on dv.id = f.dokument_version_id
join roh.dokument d on d.id = dv.dokument_id
join kw.quelle q on q.id = d.quelle_id
where f.status = 'roh';

create view ops.kennzahl_woche with (security_invoker = true) as
with w as (
  select date_trunc('week', gestartet_am)::date as woche,
         count(*) as laeufe,
         count(*) filter (where status in ('fehler','abgebrochen')) as laeufe_fehler,
         sum(dokumente_neu) as dokumente_neu,
         sum(dokumente_geaendert) as dokumente_geaendert
  from ops.crawl_lauf group by 1
), f as (
  select date_trunc('week', erstellt_am)::date as woche,
         count(*) as fakten_neu
  from ext.fakt group by 1
), s as (
  select date_trunc('week', am)::date as woche,
         count(*) filter (where nach = 'freigegeben' and automatisch) as auto_freigegeben,
         count(*) filter (where nach = 'freigegeben' and not automatisch) as von_hand_freigegeben
  from ext.statuswechsel group by 1
)
select coalesce(w.woche, f.woche, s.woche) as woche,
       coalesce(w.laeufe, 0) as laeufe,
       case when coalesce(w.laeufe, 0) = 0 then null
            else round(w.laeufe_fehler::numeric / w.laeufe, 3) end as fehlerquote,
       coalesce(w.dokumente_neu, 0) as dokumente_neu,
       coalesce(w.dokumente_geaendert, 0) as dokumente_geaendert,
       coalesce(f.fakten_neu, 0) as fakten_neu,
       coalesce(s.auto_freigegeben, 0) as auto_freigegeben,
       coalesce(s.von_hand_freigegeben, 0) as von_hand_freigegeben
from w full join f using (woche) full join s using (woche);

-- ---------------------------------------------------------------
-- RLS auf allen neuen Tabellen (Regel 6). Keine Policies: Zugriff nur über service_role.
-- ---------------------------------------------------------------
do $$
declare r record;
begin
  for r in
    select n.nspname, c.relname
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where c.relkind = 'r' and n.nspname in ('ops','einstellung','roh','ext','ref','map','wiki','lern')
  loop
    execute format('alter table %I.%I enable row level security', r.nspname, r.relname);
  end loop;
end $$;

-- ---------------------------------------------------------------
-- Rechte: neue Schemas nur für service_role. anon/authenticated haben keinen Zugriff.
-- ---------------------------------------------------------------
do $$
declare s text;
begin
  foreach s in array array['ops','einstellung','roh','ext','ref','map','wiki','lern'] loop
    execute format('revoke all on schema %I from public, anon, authenticated', s);
    execute format('revoke all on all tables in schema %I from public, anon, authenticated', s);
    execute format('revoke all on all functions in schema %I from public, anon, authenticated', s);
    execute format('grant usage on schema %I to service_role', s);
    execute format('grant select, insert, update on all tables in schema %I to service_role', s);
    execute format('grant execute on all functions in schema %I to service_role', s);
    execute format('alter default privileges in schema %I grant select, insert, update on tables to service_role', s);
    execute format('alter default privileges in schema %I grant execute on functions to service_role', s);
  end loop;
end $$;

-- public-Sichten und -Funktionen des Lernspeichers: nur service_role (Supabase gibt in public sonst anon/authenticated frei)
revoke all on public.learning_cases, public.qualification_patterns from public, anon, authenticated;
grant select, insert, update on public.learning_cases, public.qualification_patterns to service_role;
revoke all on function public.match_learning_cases(text, int, double precision) from public, anon, authenticated;
revoke all on function public.bump_qualification_pattern(text, text, jsonb) from public, anon, authenticated;
grant execute on function public.match_learning_cases(text, int, double precision) to service_role;
grant execute on function public.bump_qualification_pattern(text, text, jsonb) to service_role;

-- Die Erweiterung von kw.quelle ändert nichts an den bestehenden Rechten von kw.
