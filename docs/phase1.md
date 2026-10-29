# Phase 1 – Abnahmeprotokoll

Stand: 29.10.2026 · Wissens-DB `juluzutgabkiqnoaggxe`

## Abnahme gegen die Vorgabe

| Vorgabe | Ergebnis | Nachweis |
| --- | --- | --- |
| ER-Diagramm im Repo | erledigt | `docs/datenmodell.md`, `docs/datenmodell_er.png` |
| Migrationen im Repo | erledigt | 10 Dateien in `supabase/migrations/`, Dateinamen = Versionen in der DB-Historie |
| Lokal getestet | erledigt, mit Abweichung | 24 Prüfungen in PGlite (`npm run test:db`). Supabase CLI/Docker war in der Arbeitsumgebung nicht verfügbar; PGlite ist Postgres 17 mit pgvector und pg_trgm, Supabase-Rollen und Storage als Stellvertreter (`tests/supabase_stub.sql`). |
| Angewendet | erledigt | 10 Migrationen am 29.10.2026 auf `juluzutgabkiqnoaggxe` |
| RLS aktiv | erledigt | alle 32 neuen Tabellen; anon/authenticated ohne Schema-Zugriff |
| Advisors ohne kritische Befunde | erledigt | Sicherheit: keine Fehler. INFO „RLS ohne Policy“ ist gewollt (nur service_role). WARN nur bei drei älteren `kw`-Funktionen (nicht angefasst). Performance: Fremdschlüssel-Indizes nachgezogen. |
| Seed aus Phase 0 eingespielt | erledigt | `ext.preisregel_altbestand`: 67 Herstellerregeln + 6 Preisdeckel, Muster wortgleich (Stichprobe geprüft) |

Zusätzlich auf der echten DB geprüft: 7 Hersteller aus `kw.hersteller` in `ref.akteur` verknüpft,
`kw` weiter mit 23 Tabellen und 139 EPA-Positionen unverändert, Lizenzquellen BKI und sirAdos
mit `nutzungsrecht = lizenz` und inaktiv, Buckets `roh-dokumente` und `learning-images` privat.

## Was die Datenbank jetzt erzwingt

Siehe Tabelle „Regeln, die die Datenbank selbst erzwingt“ in `docs/datenmodell.md` –
u. a. Unveränderlichkeit, Herkunftspflicht, Änderungserkennung per Hash, E1, E6, E13.

## Lernspeicher (E9) – noch ein Schritt bei Tobias

Die Datenbank ist bereit. Damit ElementScout lernt, im Lovable-Projekt ElementScout drei Secrets setzen:

| Secret | Wert |
| --- | --- |
| `LEARN_SUPABASE_URL` | `https://juluzutgabkiqnoaggxe.supabase.co` |
| `LEARN_SUPABASE_SERVICE_KEY` | Service-Role-Key aus Supabase → Project Settings → API (nicht weitergeben) |
| `LEARN_VISITOR_SALT` | eine lange Zufallszeichenfolge |

Der Code in `learning-store.ts` schaltet sich danach von selbst ein. Keine Code-Änderung nötig.

## Bewusst auf Phase 2 verschoben

- **Spiegelung des Registers** aus cc-core in `map.register_knoten` / `map.register_element`
  (GEFMA 924-2 KG 300–500: 638 Knoten, Baugruppen 504, Elementtypen 217, Bauelemente 136) –
  als geplanter Abgleich, nicht als Einmal-Kopie.
- **Zugriffsweg für die Management-Oberfläche:** Die neuen Schemas sind nicht über die REST-API
  freigegeben. Phase 2 entscheidet zwischen freigegebenen Schemas oder einer schmalen API-Schicht
  aus Funktionen.
- `pg_cron` / `pg_net` werden erst mit dem Planer installiert.

## Offen bei Tobias

1. Empfänger des Tagesberichts (`einstellung.parameter.tagesbericht_empfaenger`).
2. Kontaktangabe für den User-Agent des Crawlers (`crawler_kontakt`).
3. Empfehlung: RLS auch auf den 23 `kw`-Tabellen einschalten. Heute sind sie nur dadurch geschützt,
   dass anon/authenticated keinen Schema-Zugriff haben. Ohne Policies ändert das für service_role nichts.
   Nicht umgesetzt, weil `kw` unverändert bleiben soll (E12).
