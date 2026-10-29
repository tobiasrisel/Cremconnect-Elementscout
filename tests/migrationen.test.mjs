// Lokaler Test der Migrationen in PGlite (Postgres 17 als WebAssembly, mit pgvector und pg_trgm).
// Aufruf: npm run test:db
import { PGlite } from "@electric-sql/pglite";
import { vector } from "@electric-sql/pglite/vector";
import { pg_trgm } from "@electric-sql/pglite/contrib/pg_trgm";
import { readFileSync, readdirSync } from "node:fs";
import assert from "node:assert/strict";

const db = new PGlite({ extensions: { vector, pg_trgm } });
let ok = 0;
const pruefe = async (name, fn) => {
  try { await fn(); ok++; console.log("  ok  ", name); }
  catch (e) { console.error("  FEHL", name, "\n       ", e.message); process.exitCode = 1; }
};
const wert = async (sql, p = []) => (await db.query(sql, p)).rows[0];
const wirft = async (sql, muster, p = []) => {
  let fehler = null;
  try { await db.query(sql, p); } catch (e) { fehler = e; }
  assert.ok(fehler, `erwartet Fehler bei: ${sql.slice(0, 80)}`);
  if (muster) assert.match(fehler.message, muster);
};

await db.exec(readFileSync("tests/supabase_stub.sql", "utf8"));
const dateien = readdirSync("supabase/migrations").filter(f => f.endsWith(".sql")).sort();
for (const f of dateien) {
  try { await db.exec(readFileSync(`supabase/migrations/${f}`, "utf8")); console.log("migriert", f); }
  catch (e) { console.error("MIGRATION FEHLGESCHLAGEN", f, "\n", e.message); process.exit(1); }
}

console.log("\nPrüfungen");

await pruefe("Seed: 67 Herstellerregeln + 6 Preisdeckel", async () => {
  const r = await wert(`select count(*) filter (where art='herstellerregel')::int h, count(*) filter (where art='preisdeckel')::int d from ext.preisregel_altbestand`);
  assert.deepEqual(r, { h: 67, d: 6 });
});
await pruefe("Seed: Regex-Muster wortgleich (Stichprobe Wilo 25/0,5-6)", async () => {
  const r = await wert(`select muster from ext.preisregel_altbestand where art='herstellerregel' and reihenfolge=3`);
  assert.equal(r.muster, String.raw`stratos\s+pico\s+plus.*25\/0,?5-6`);
});
await pruefe("Seed: 7 Hersteller aus kw verknüpft, Rolle hersteller", async () => {
  const r = await wert(`select count(*)::int n, count(distinct kw_hersteller_id)::int k, (select count(*)::int from ref.akteur_rolle) rollen from ref.akteur`);
  assert.deepEqual(r, { n: 7, k: 7, rollen: 7 });
});
await pruefe("kw.quelle: Bestandszeilen erhalten, Lizenzquellen inaktiv mit nutzungsrecht lizenz", async () => {
  const r = await wert(`select count(*)::int n, count(*) filter (where nutzungsrecht='lizenz' and not ist_aktiv)::int lizenz from kw.quelle where code <> 'ALTBESTAND_ES'`);
  assert.deepEqual(r, { n: 6, lizenz: 2 });
});
await pruefe("E1: Lizenzquelle mit Crawl-Regel darf nicht aktiv werden", async () => {
  await wirft(`update kw.quelle set crawl_regel='{"start":["https://bki.de"]}', ist_aktiv=true where code='BKI_ALTBAU'`, /quelle_crawl_nur_wenn_erlaubt/);
});
await pruefe("Einstellungen: Schwelle 0.80, Änderung wird protokolliert", async () => {
  assert.equal(Number((await wert(`select einstellung.zahl('auto_freigabe_schwelle') v`)).v), 0.8);
  await db.query(`update einstellung.parameter set wert='0.85', geaendert_von='test' where schluessel='auto_freigabe_schwelle'`);
  const h = await wert(`select count(*)::int n from einstellung.parameter_historie where schluessel='auto_freigabe_schwelle'`);
  assert.equal(h.n, 2);
  await db.query(`update einstellung.parameter set wert='0.80', geaendert_von='test' where schluessel='auto_freigabe_schwelle'`);
});

// Pipeline-Durchlauf
const quelle = (await wert(`insert into kw.quelle (code, bezeichnung, art, weitergabe, quelltyp, nutzungsrecht, crawl_regel, datentopf_id)
  values ('TEST_WILO','Wilo Datenblätter (Test)','hersteller','frei','datenblatt','mit_quellenangabe','{"start":["https://wilo.com/de"]}',
          (select id from einstellung.datentopf where code='herstellerdaten')) returning id`)).id;
const lauf = (await wert(`insert into ops.crawl_lauf (quelle_id) values ($1) returning id`, [quelle])).id;
const h1 = "a".repeat(64), h2 = "b".repeat(64);

let dv1;
await pruefe("Änderungserkennung: gleicher Hash = keine neue Version, neuer Hash = Version 2", async () => {
  const a = await wert(`select * from roh.version_anlegen($1,'https://wilo.com/db.pdf',$2,$3,'pdf')`, [quelle, h1, lauf]);
  const b = await wert(`select * from roh.version_anlegen($1,'https://wilo.com/db.pdf',$2,$3,'pdf')`, [quelle, h1, lauf]);
  const c = await wert(`select * from roh.version_anlegen($1,'https://wilo.com/db.pdf',$2,$3,'pdf')`, [quelle, h2, lauf]);
  assert.equal(a.ist_neu, true); assert.equal(a.version, 1);
  assert.equal(b.ist_neu, false); assert.equal(b.dokument_version_id, a.dokument_version_id);
  assert.equal(c.ist_neu, true); assert.equal(c.version, 2);
  dv1 = a.dokument_version_id;
});
await pruefe("Rohdokument-Version ist unveränderlich", async () => {
  await wirft(`update roh.dokument_version set mime_typ='x' where id=$1`, /unveränderlich/, [dv1]);
  await wirft(`delete from roh.dokument_version where id=$1`, /unveränderlich/, [dv1]);
});

const xl = (await wert(`insert into ext.extraktionslauf (dokument_version_id, aufgabe, modell, prompt_version, schema_version)
  values ($1,'extraktion','google/gemini-2.5-flash','p1','s1') returning id`, [dv1])).id;
const neuerFakt = async (typ, konf, extra = "") => (await wert(
  `insert into ext.fakt (extraktionslauf_id, dokument_version_id, fakttyp, merkmal, wert_zahl, einheit, bezugsgroesse, konfidenz)
   values ($1,$2,$3,'nennleistung',${extra || "0.045"},'kW',${typ === "kostenkennwert" ? "'je Stück'" : "null"},$4) returning id`,
  [xl, dv1, typ, konf])).id;

await pruefe("E6: Datenblatt-Fakt ab 0,80 wird automatisch freigegeben und protokolliert", async () => {
  const f = await neuerFakt("produktmerkmal", 0.85);
  assert.equal((await wert(`select ext.auto_freigabe($1) r`, [f])).r, true);
  const s = await wert(`select f.status, w.durch, w.automatisch from ext.fakt f join ext.statuswechsel w on w.fakt_id=f.id where f.id=$1`, [f]);
  assert.deepEqual(s, { status: "freigegeben", durch: "auto", automatisch: true });
});
await pruefe("E6: unter 0,80 bleibt roh (Tagesbericht)", async () => {
  const f = await neuerFakt("produktmerkmal", 0.79);
  assert.equal((await wert(`select ext.auto_freigabe($1) r`, [f])).r, false);
  assert.equal((await wert(`select count(*)::int n from ops.offene_fakten where id=$1`, [f])).n, 1);
});
await pruefe("Prüffehler verhindert Auto-Freigabe", async () => {
  const f = await neuerFakt("produktmerkmal", 0.95);
  await db.query(`insert into ext.pruefbefund (fakt_id, regel, ergebnis) values ($1,'plausibel','fehler')`, [f]);
  assert.equal((await wert(`select ext.auto_freigabe($1) r`, [f])).r, false);
});
await pruefe("E13: Kostenkennwert 0,95 wird nie automatisch freigegeben", async () => {
  const f = await neuerFakt("kostenkennwert", 0.95, "480");
  assert.equal((await wert(`select ext.auto_freigabe($1) r`, [f])).r, false);
  await wirft(`select ext.fakt_status_setzen($1,'freigegeben','test','auto',true)`, /E13/, [f]);
  await db.query(`select ext.fakt_status_setzen($1,'freigegeben','geprüft','Tobias Risel',false)`, [f]);
  assert.equal((await wert(`select status from ext.fakt where id=$1`, [f])).status, "freigegeben");
});
await pruefe("Kostenkennwert ohne Bezugsgröße wird abgewiesen", async () => {
  await wirft(`insert into ext.fakt (extraktionslauf_id, dokument_version_id, fakttyp, wert_zahl, konfidenz) values ($1,$2,'kostenkennwert',100,0.9)`, /fakt_kennwert_vollstaendig/, [xl, dv1]);
});
await pruefe("Fakt-Inhalt unveränderlich, Status nur über Funktion, Löschen verboten", async () => {
  const f = await neuerFakt("produktmerkmal", 0.5);
  await wirft(`update ext.fakt set wert_zahl=1 where id=$1`, /unveränderlich/, [f]);
  await wirft(`update ext.fakt set status='geprueft' where id=$1`, /fakt_status_setzen/, [f]);
  await wirft(`delete from ext.fakt where id=$1`, /nicht gelöscht/, [f]);
});
await pruefe("ref: Produkt braucht Herkunft, Inhalt nur durch neue Version", async () => {
  const f = await neuerFakt("produkt", 0.9);
  const akteur = (await wert(`select id from ref.akteur where name='Wilo SE'`)).id;
  const p = (await wert(`insert into ref.produkt (hersteller_id, modellname, herkunft_fakt_id) values ($1,'Stratos PICO plus 25/1-6',$2) returning id`, [akteur, f])).id;
  await wirft(`update ref.produkt set modellname='x' where id=$1`, /nur diese Spalten/, [p]);
  await db.query(`update ref.produkt set gueltig_bis=current_date where id=$1`, [p]);
  await wirft(`insert into ref.produkt (hersteller_id, modellname) values ($1,'ohne Herkunft')`, /null value|not-null/i, [akteur]);
});
await pruefe("map: Zuordnung braucht genau ein Registerziel", async () => {
  await db.query(`insert into map.katalog (code, name, lizenzpflichtig, fassung) values ('GEFMA_924_2','Facilities',true,'2017-09')`);
  const k = (await wert(`insert into map.register_knoten (id, katalog_code, code, bezeichnung, din276_kg, im_suchumfang) values (gen_random_uuid(),'GEFMA_924_2','421','Wärmeerzeugungsanlagen','421',true) returning id`)).id;
  await db.query(`insert into map.zuordnung (ziel_art, ziel_id, register_knoten_id, herkunft, erstellt_von) values ('produkt', gen_random_uuid(), $1, 'ki', 'test')`, [k]);
  await wirft(`insert into map.zuordnung (ziel_art, ziel_id, herkunft, erstellt_von) values ('produkt', gen_random_uuid(), 'ki', 'test')`, /check/i);
});

// Lernspeicher – genau so, wie learning-store.ts ihn aufruft
const vec = (f) => "[" + Array.from({ length: 3072 }, (_, i) => f(i).toFixed(6)).join(",") + "]";
await pruefe("Lernspeicher: Insert über public-Sicht mit 3072-dim Vektorliteral", async () => {
  await db.query(`insert into public.learning_cases (id, component_name, category, component_key, materials, building_details, qualification_qa, analysis_result, cost_min, cost_max, image_embedding, text_embedding, quality_score)
    values (gen_random_uuid(),'Umwälzpumpe','Heizung','421|heizung|umwälzpumpe',array['Wilo'],'{}','{}','{"name":"Umwälzpumpe"}',300,900,$1,$2,0.5)`,
    [vec(i => Math.sin(i)), vec(i => Math.cos(i))]);
  assert.equal((await wert(`select count(*)::int n from lern.learning_cases`)).n, 1);
});
await pruefe("Lernspeicher: match_learning_cases findet identisches Bild (Ähnlichkeit ≈ 1)", async () => {
  const r = (await db.query(`select * from public.match_learning_cases($1, 5, 0.88)`, [vec(i => Math.sin(i))])).rows;
  assert.equal(r.length, 1); assert.ok(r[0].similarity > 0.999, `similarity ${r[0].similarity}`);
  const leer = (await db.query(`select * from public.match_learning_cases($1, 5, 0.88)`, [vec(i => Math.cos(i * 7))])).rows;
  assert.equal(leer.length, 0);
});
await pruefe("Lernspeicher: bump_qualification_pattern zählt Treffer und Fälle", async () => {
  await db.query(`select public.bump_qualification_pattern('421|heizung|umwälzpumpe','identification.model','{"question":"Typenschild?"}')`);
  await db.query(`select public.bump_qualification_pattern('421|heizung|umwälzpumpe','identification.model','{"question":"Typenschild?"}')`);
  const r = await wert(`select hit_count, cases_seen from public.qualification_patterns`);
  assert.deepEqual(r, { hit_count: 2, cases_seen: 1 });
});
await pruefe("Buckets roh-dokumente und learning-images privat angelegt", async () => {
  const r = (await db.query(`select id, public from storage.buckets order by id`)).rows;
  assert.deepEqual(r, [{ id: "learning-images", public: false }, { id: "roh-dokumente", public: false }]);
});

// Sicherheit
await pruefe("RLS auf allen neuen Tabellen aktiv", async () => {
  const r = (await db.query(`select n.nspname||'.'||c.relname t from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where c.relkind='r' and n.nspname in ('ops','einstellung','roh','ext','ref','map','wiki','lern') and not c.relrowsecurity`)).rows;
  assert.deepEqual(r, []);
});
await pruefe("anon/authenticated: kein Zugriff auf neue Schemas und Lernspeicher", async () => {
  for (const s of ["ops", "einstellung", "roh", "ext", "ref", "map", "wiki", "lern"]) {
    for (const rolle of ["anon", "authenticated"]) {
      const r = await wert(`select has_schema_privilege($1,$2,'USAGE') u`, [rolle, s]);
      assert.equal(r.u, false, `${rolle} hat USAGE auf ${s}`);
    }
  }
  const v = await wert(`select has_table_privilege('anon','public.learning_cases','SELECT') a, has_function_privilege('anon','public.match_learning_cases(text,int,double precision)','EXECUTE') f`);
  assert.deepEqual(v, { a: false, f: false });
});
await pruefe("service_role: darf lesen/schreiben, aber nicht löschen", async () => {
  const r = await wert(`select has_table_privilege('service_role','ext.fakt','INSERT') i, has_table_privilege('service_role','ext.fakt','DELETE') d, has_function_privilege('service_role','public.bump_qualification_pattern(text,text,jsonb)','EXECUTE') f`);
  assert.deepEqual(r, { i: true, d: false, f: true });
});
await pruefe("Wochenkennzahl liefert Zeile mit Lauf und Fakten", async () => {
  const r = await wert(`select laeufe, fakten_neu, auto_freigegeben from ops.kennzahl_woche order by woche desc limit 1`);
  assert.ok(Number(r.laeufe) >= 1 && Number(r.fakten_neu) >= 1 && Number(r.auto_freigegeben) >= 1, JSON.stringify(r));
});

console.log(`\n${ok} Prüfungen bestanden${process.exitCode ? ", es gibt Fehler" : ""}.`);
