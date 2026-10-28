# Cremconnect-Elementscout – Wissensdatenbank

Mandantenunabhängige Wissensdatenbank für alle Anwendungen von CREMconnect / FlowRE.

Ein Crawler sammelt laufend **Herstellerdatenblätter**, **Ausschreibungspositionen** und
**Kostenkennwerte**, zerlegt sie technisch und legt jede Angabe mit Quelle, Abrufdatum und
Version ab. Anwendungen (zuerst ElementScout, zuletzt Cremconnect) lesen nur über eine API.

## Aufbau

| Ordner | Inhalt |
| --- | --- |
| `supabase/migrations/` | versionierte SQL-Migrationen der Wissens-DB |
| `seed/` | Startdaten, u. a. Altbestand der Preisregeln aus ElementScout |
| `docs/` | Datenmodell, Entscheidungen, Abnahmeprotokolle |

## Stufen der Daten

1. `roh` – Rohdokumente, versioniert, mit Hash
2. `ext` – Zwischenebene: Abschnitte, Fakten, Kennwerte
3. `ref` – geprüft und freigegeben

Arbeitsweise und Phasenplan: siehe [`CLAUDE.md`](CLAUDE.md).
