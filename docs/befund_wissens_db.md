# Befund: Wissens-DB `juluzutgabkiqnoaggxe` ist nicht leer

Festgestellt am 29.10.2026 (nur lesend geprüft).

Die Bestandsaufnahme vom 25.10.2026 hat nur das Schema `public` geprüft und das Projekt
deshalb als „leer“ geführt. Das war falsch. Im Projekt liegt eine **Kennwert-Datenbank**
(Schema `kw`, 10 Migrationen vom 12.09.2026) mit Ausgabesichten im Schema `api`.

| Tabelle | Zeilen | Zweck laut Kommentar |
| --- | --- | --- |
| `kw.quelle` | 6 | Quellen inkl. Lizenz/Weitergabe, Abrufintervall, aktiv (BKI und sirAdos inaktiv) |
| `kw.dokument` | 28 | Register der Unterlagen, aus denen Kennwerte abgeleitet sind |
| `kw.crawllauf`, `kw.crawlbefund` | 0 | Crawler vorbereitet; Befund wird erst mit Person + Datum übernommen |
| `kw.hersteller` | 7 | Buderus, GC-Gruppe, Grundfos, Raab Karcher, Vaillant, Viessmann, Wilo |
| `kw.produkt` | 0 | Produkt mit Listenpreis, Merkmalen, Baugruppe |
| `kw.fassung` | 4 | Kennwertstände je Katalog, genau eine freigegeben |
| `kw.epa_position` | 139 | Einheitspreise je Bauteil aus Vergabe |
| `kw.meldungstyp`, `kw.meldungstyp_kennwert` | 119 / 119 | Referenzkosten je Meldungstyp (EPA 2016) |
| `kw.beleg`, `kw.belegposition` | 4 / 181 | anonymisierte Projektbelege |
| `kw.baugruppe` | 104 | Spiegel des Bauteilkatalogs aus cc-core |
| `kw.zuordnung` | 64 | Kostenstelle → Baugruppe |
| `kw.modernisierung`, `kw.instandhaltung`, `kw.betriebskosten` | 0 | Kennwertkataloge, noch leer |
| `kw.audit`, `kw.auditposition`, `kw.regel`, `kw.bezugsgroesse`, `kw.preisindex`, `kw.gewerksgruppe` | – | Nachqualifizierung, Regeln, Stammdaten |

Wichtig für den Entwurf:
- `kw` hat bereits ein Quellenregister und vorbereitete Crawl-Tabellen.
- `kw` verlangt für jede Kennwertänderung **Person und Datum** – das kollidiert mit der
  Auto-Freigabe ab 0,80 (E6), wenn diese auch für Kostenkennwerte gelten soll.
- Storage ist leer, `public` ist leer, `vector`, `pg_cron`, `pg_net` sind verfügbar, aber nicht installiert.

Register in cc-core (für E7, lesend): GEFMA 924-2 Facilities 867 Knoten (davon KG 3xx: 122,
4xx: 406, 5xx: 110), REG-IS-Ergänzungen 3, Baugruppen/Bauteile `IH_BAUTEIL` 504,
`tdd.elementtyp` 217, `tdd.bauelement` 136. `tec.hersteller` und `tec.produktmodell` sind leer.
