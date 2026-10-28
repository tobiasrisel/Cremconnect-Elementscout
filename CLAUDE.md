# Briefing für Claude Code – Wissensdatenbank & Crawler (Repo `tobiasrisel/Cremconnect-Elementscout`)

Stand: 26.10.2026 · Auftraggeber: Tobias Risel
Ausführliche Bestandsaufnahme: https://claude.ai/artifact/QDydmtdy1phemaV3y8qGCG

## Auftrag in einem Satz

Baue eine eigenständige, mandantenunabhängige Wissensdatenbank, die laufend
Herstellerdatenblätter, Ausschreibungspositionen und Kostenkennwerte crawlt,
technisch zerlegt, mit Quelle ablegt und über eine API allen Anwendungen
bereitstellt. ElementScout wird später ihr erster Nutzer, Cremconnect wird
zuletzt angebunden.

## Was NICHT zum Auftrag gehört

- Keine mobilen Apps, keine Mandanten-Oberflächen.
- Keine Schreibzugriffe auf `cc-core` (Cremconnect). Lesen nur, wenn ausdrücklich verlangt.
- Keine Änderungen am Lovable-Projekt ElementScout, bevor Phase 3 abgenommen ist.
- Keine lizenzpflichtigen Quellen crawlen (z. B. BKI, STLB-Bau, sirAdos). Im Zweifel: Quelle im
  Register anlegen, `aktiv = false`, und nachfragen.

## Arbeitsweise (verbindlich)

1. **Schritt für Schritt.** Jede Phase endet mit einer Abnahme gegen ihre Vorgabe.
   Erst nach meiner Freigabe geht es weiter. Zwischenstand kurz berichten, nicht weiterbauen.
2. **Migrationen statt Klickerei.** Jede Schemaänderung als versionierte SQL-Migration im Repo
   (`supabase/migrations/`), lokal mit Supabase CLI getestet, dann angewendet.
3. **Jede Zeile hat eine eindeutige ID** (UUID) und – wo fachlich – Quelle, Gültig-ab/-bis und
   Status (`roh` / `geprueft` / `freigegeben`).
4. **Keine Zahl ohne Herkunft.** Jeder Kennwert, Preis oder Merkmal führt zurück auf
   Quell-URL, Abrufdatum und Dokumentversion.
5. **Nie überschreiben, immer versionieren.** Rohdokumente und Fakten bekommen neue Versionen,
   alte bleiben lesbar.
6. **RLS auf allen Tabellen.** Zugriff von außen nur über die API bzw. Service-Role.
7. Bei Datenmodellfragen die GEFMA-Vorgaben des Skills `cremconnect-datenmodell` beachten
   (DIN 276, GEFMA/FAC-ID als Klassifikation).
8. Unklare Fachfragen nicht raten: als offene Frage notieren und mich fragen.

## Ausgangslage

| Was | Wo | Hinweis |
| --- | --- | --- |
| ElementScout (Prototyp) | Lovable-Projekt `7b15c408-3dca-4178-8402-4fce00fbfc48` | noch **kein GitHub-Repo** |
| Fachlogik heute | Edge Function `supabase/functions/analyze-component/index.ts` (ca. 900 Zeilen) | Systemprompt, ~70 Herstellerpreis-Regeln, 6 Preisdeckel hart im Code |
| Lernspeicher-Code | `supabase/functions/_shared/learning-store.ts` | Ziel-DB nicht auffindbar, vermutlich nie aktiv |
| Cremconnect-Kern | Supabase `cc-core` (`xyyvahigowejjygaxhtk`) | Schemas `auf`, `org`, `ort`, `tdd`, `api` – nur lesen |
| Leeres Projekt für Wissens-DB | Supabase `CC-Core-Reference-cost_database` (`juluzutgabkiqnoaggxe`, eu-central-1) | Kandidat für die Wissens-DB, Entscheidung offen |
| Crawler-Dienst | Firecrawl (als Connector verfügbar) | Alternative: eigener Worker |
| Cremconnect-Code | GitHub `tobiasrisel/cremconnect-v2` | nicht anfassen |

## Phasen

### Phase 0 – Sichern
- [x] Repo `tobiasrisel/Cremconnect-Elementscout` angelegt (README, diese Datei als `CLAUDE.md`) – 28.10.2026.
- [ ] Mir die Schritte nennen, um ElementScout in Lovable mit GitHub zu verbinden (mache ich selbst).
- [ ] Preisregeln und Preisdeckel aus `analyze-component/index.ts` als JSON/CSV extrahieren
      (`seed/altbestand_preise.json`), Quelle „Altbestand 2024/2025“.

**Abnahme:** Repo existiert, Seed-Datei vollständig (Anzahl Regeln = Anzahl im Code).

### Phase 1 – Datenmodell der Wissens-DB
Schemas (Namen als Vorschlag, Begründung bei Abweichung):

- `quelle` – Quellenregister: Domain, Quelltyp (`datenblatt` | `ausschreibung` | `kennwert` | `markt`),
  Crawl-Regel, Takt, Nutzungserlaubnis/Lizenz, `aktiv`.
- `roh` – Rohdokumente: URL, Inhalts-Hash, Abrufdatum, Storage-Pfad, Version, Quelle.
- `ext` – Zwischenebene: Abschnitt, Fakt (Merkmal, Wert, Einheit, Bezug), Embedding (pgvector),
  Extraktionsmodell + Version, Konfidenz, Status.
- `ref` – freigegebenes Wissen: Hersteller, Produkt, Produktmerkmal, Ausschreibungsposition,
  Kostenkennwert (Bezugseinheit, Region, Stand), Akteur.
- `map` – Zuordnungen zu DIN 276, GEFMA/FAC-ID und später `tdd.elementtyp` (keine harten
  Fremdschlüssel nach cc-core).
- `ops` – Crawl-Läufe, Fehler, Kennzahlen.

**Abnahme:** ER-Diagramm + Migrationen im Repo, RLS aktiv, Supabase-Advisors ohne kritische Befunde,
Seed aus Phase 0 eingespielt.

### Phase 2 – Crawler-Pipeline
1. Planer: `pg_cron` stößt je Quelle nach Takt an.
2. Abruf: Firecrawl oder eigener Worker; robots.txt, Drosselung, User-Agent mit Kontakt.
3. Änderungserkennung per Hash – nur Neues/Geändertes weiter.
4. Ablage: Rohdokument im Storage, versioniert.
5. Extraktion: PDF-Text und Tabellen, dann KI-Extraktion in festes JSON-Schema je Dokumenttyp.
6. Prüfregeln: Einheit vorhanden, Plausibilitätsbereich, Dubletten (Hersteller + Typ),
   Widerspruch zu vorhandenem Fakt markieren.
7. Überwachung: Lauf-Protokoll, Fehlerquote, neue Fakten pro Woche.

Startumfang: Hersteller Wilo, Grundfos, Viessmann, Buderus, Vaillant, Kermi, Zehnder, Geberit,
Grohe, Danfoss – deren Datenblätter und Ausschreibungstexte. Kostenkennwerte zunächst nur aus
frei nutzbaren Quellen.

**Abnahme:** läuft zwei Wochen unbeaufsichtigt; Stichprobe von 20 Fakten ist vollständig
rückverfolgbar; Fehlerquote dokumentiert.

### Phase 3 – Nachqualifizieren (danach Stopp und Rücksprache)
- Schlichte Web-Prüfoberfläche: sichten, korrigieren, freigeben, zurückstufen; Historie bleibt.
- Konflikte (zwei Quellen, zwei Werte) sichtbar, Entscheidung mit Begründung.
- Verfall: Kennwerte älter als 12 Monate markieren und neu crawlen.

**Abnahme:** mindestens 200 freigegebene Fakten zu den Startherstellern.

Phase 4 (Wissens-API + ElementScout umstellen) und Phase 5 (Cremconnect-Anbindung) werden
erst nach Abnahme von Phase 3 gebrieft.

## Offene Entscheidungen (vor Start klären, nicht selbst entscheiden)

1. Wissens-DB in `juluzutgabkiqnoaggxe` oder neues Projekt?
2. Firecrawl (Dienst) oder eigener Worker?
3. Original-PDFs dauerhaft speichern oder nur Fakten + Link + Hash?
4. KI für Extraktion: Lovable-Gateway oder direkt beim Anbieter?
5. Wer gibt frei, ab welcher Konfidenz automatisch?

## Erster Schritt

Lies diese Datei, prüfe die Ausgangslage (Lovable-Dateien, beide Supabase-Projekte nur lesend),
stelle mir die offenen Entscheidungen als kurze Rückfrage und starte dann Phase 0.
