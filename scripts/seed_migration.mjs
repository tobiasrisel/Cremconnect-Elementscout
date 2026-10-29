// Erzeugt supabase/migrations/20261029002241_seed_startdaten.sql aus seed/altbestand_preise.json
import { readFileSync, writeFileSync } from "node:fs";
const s = JSON.parse(readFileSync("seed/altbestand_preise.json", "utf8"));
const q = (v) => v === null || v === undefined ? "null" : `'${String(v).replace(/'/g, "''")}'`;
const regeln = [
  ...s.herstellerregeln.map(r => ({ ...r, art: "herstellerregel", bezeichnung: null, quellenangabe_alt: null })),
  ...s.preisdeckel.map(r => ({ ...r, art: "preisdeckel", hersteller: null })),
];
const rows = regeln.map(r => `  (${q(r.id)}, ${q(r.art)}, ${r.reihenfolge}, ${q(r.hersteller)}, ${q(r.bezeichnung)}, ${q(r.muster)}, ${q(r.muster_flags)}, ${r.marktpreis_netto_max}, ${r.ersatzkosten_netto_max}, ${q(r.quellenangabe_alt)})`).join(",\n");
const sql = `-- Phase 1 · Migration 9/9 – Startdaten
-- Erzeugt mit scripts/seed_migration.mjs aus seed/altbestand_preise.json – nicht von Hand ändern.

-- Einstellungen (E5, E6, E13). Kein Wert im Code.
insert into einstellung.parameter (schluessel, wert, beschreibung) values
  ('auto_freigabe_schwelle', '0.80', 'E6: Fakten ab dieser Konfidenz automatisch freigeben, wenn keine Prüfregel fehler meldet.'),
  ('auto_freigabe_ausgenommen', '["kostenkennwert"]', 'E13: Fakttypen, die nie automatisch freigegeben werden (Person und Datum nötig).'),
  ('verfall_monate', '12', 'Phase 3: Kennwerte und Preise älter als diese Monate markieren und neu crawlen.'),
  ('tagesbericht_uhrzeit', '"07:00 Europe/Berlin"', 'E6: Zeitpunkt des täglichen Berichts neuer Dokumente.'),
  ('tagesbericht_empfaenger', 'null', 'E6: Empfänger des Tagesberichts – noch festzulegen.'),
  ('crawler_kontakt', 'null', 'Kontaktangabe im User-Agent des Crawlers – noch festzulegen.');

-- Modellwahl (E5: Lovable-Gateway mit Google Gemini; wie bisher in ElementScout)
insert into einstellung.modell (aufgabe, anbieter, modell, dimensionen, parameter, bemerkung) values
  ('extraktion', 'lovable-gateway', 'google/gemini-2.5-flash', null, '{"temperature":0}', 'wie analyze-component'),
  ('embedding', 'lovable-gateway', 'google/gemini-embedding-2', 3072, '{}', 'wie learning-store.ts'),
  ('analyse', 'lovable-gateway', 'google/gemini-2.5-flash', null, '{"temperature":0}', 'wie analyze-component'),
  ('klassifikation', 'lovable-gateway', 'google/gemini-2.5-flash', null, '{"temperature":0}', 'Zuordnung zum Register');

-- Datentöpfe (E4)
insert into einstellung.datentopf (code, bezeichnung, zielbereich, beschreibung) values
  ('herstellerdaten', 'Herstellerdatenblätter und Produktdaten', 'wissen', 'Datenblätter, Produktseiten, Wartungsangaben'),
  ('ausschreibung', 'Ausschreibungspositionen', 'wissen', 'Leistungstexte und Positionen'),
  ('kennwerte', 'Kostenkennwerte', 'kennwert', 'Fließt nach Prüfung durch eine Person in kw (E12, E13)'),
  ('fachartikel', 'Fachartikel für das Wiki', 'wiki', 'E8'),
  ('lernfaelle', 'Lernfälle aus ElementScout', 'lern', 'E9'),
  ('altbestand', 'Altbestand ElementScout', 'wissen', 'Regex-Preisregeln 2024/2025 ohne Einzelbeleg');

-- Bestehende kw-Quellen dem passenden Topf zuordnen; Lizenzquellen bleiben inaktiv (E1)
update kw.quelle set datentopf_id = (select id from einstellung.datentopf where code = 'kennwerte'),
                     quelltyp = 'kennwert',
                     nutzungsrecht = case when code in ('BKI_ALTBAU','SIRADOS') then 'lizenz' else 'unklar' end
 where datentopf_id is null;

-- Quelle für den Altbestand (wird nicht gecrawlt)
insert into kw.quelle (code, bezeichnung, art, herausgeber, url, weitergabe, lizenzhinweis, ist_aktiv,
                       datentopf_id, quelltyp, nutzungsrecht)
values ('ALTBESTAND_ES', 'Altbestand ElementScout-Preisregeln 2024/2025', 'schaetzung', 'CREMConnect / FlowRE',
        ${q(s.quelle.herkunft)}, 'intern', ${q(s.quelle.hinweis)}, false,
        (select id from einstellung.datentopf where code = 'altbestand'), 'altbestand', 'frei');

insert into ext.preisregel_altbestand (id, art, reihenfolge, hersteller, bezeichnung, muster, muster_flags,
  marktpreis_netto_max, ersatzkosten_netto_max, quellenangabe_alt, quelle_id, herkunft_commit)
select v.id::uuid, v.art, v.reihenfolge, v.hersteller, v.bezeichnung, v.muster, v.muster_flags,
       v.mp, v.ek, v.qa, (select id from kw.quelle where code = 'ALTBESTAND_ES'), ${q(s.quelle.commit)}
from (values
${rows}
) as v(id, art, reihenfolge, hersteller, bezeichnung, muster, muster_flags, mp, ek, qa);

-- Hersteller aus kw verknüpfen, nicht kopieren (E12)
insert into ref.akteur (name, website, kw_hersteller_id)
select h.name, h.url, h.id from kw.hersteller h
on conflict (kw_hersteller_id) do nothing;
insert into ref.akteur_rolle (akteur_id, rolle_code, kontext)
select a.id, 'hersteller', 'aus kw.hersteller' from ref.akteur a where a.kw_hersteller_id is not null
on conflict do nothing;
`;
writeFileSync("supabase/migrations/20261029002241_seed_startdaten.sql", sql);
console.log("Regeln:", regeln.length, "davon Hersteller", s.herstellerregeln.length, "Deckel", s.preisdeckel.length);
