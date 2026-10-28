# Entscheidungen

Festgelegt von Tobias Risel am 28.10.2026. Neue Entscheidungen werden oben ergänzt, alte nicht gelöscht.

| # | Frage | Entscheidung | Folge / Hinweis |
| --- | --- | --- | --- |
| E1 | Welche Quellen? | Alle verfügbaren Quellen. | Gecrawlt wird alles, was öffentlich zugänglich ist und dessen robots.txt und Nutzungsbedingungen das erlauben. Lizenzpflichtige Sammlungen (BKI, STLB-Bau, sirAdos) kommen nur mit Lizenz per Import und stehen bis dahin im Quellenregister mit `aktiv = false`. |
| E2 | Original-PDFs speichern? | Ja, Originale dauerhaft speichern und den Anwendungen bereitstellen. | Ablage versioniert im Storage, mit Hash und Quell-URL. Bereitstellung an Nutzer immer mit Quellenangabe; Weitergabe nach außen je Quelle prüfen (Urheberrecht der Hersteller). |
| E3 | Wissens-DB wohin? | Leeres Supabase-Projekt `CC-Core-Reference-cost_database` (`juluzutgabkiqnoaggxe`). | Wird ab Phase 1 genutzt. |
| E4 | Crawler-Betrieb | Firecrawl. Dazu eine **Management-Oberfläche als eigenes Projekt**, in der Quellen, Takt, Regeln und weitere Datentöpfe eingestellt werden. | Eigenes Projekt, getrennt von ElementScout. Einstellungen liegen in der Wissens-DB (`quelle`), die Oberfläche bearbeitet nur diese. |
| E5 | KI für Extraktion und Analyse | Frage: Claude, ChatGPT oder Gemini direkt nutzen? | Ja, alle drei sind direkt per API mit eigenem Schlüssel nutzbar. Umsetzung als Anbieter-Schicht: Modell je Aufgabe (Extraktion, Embedding, Analyse) in der Management-Oberfläche wählbar, Modell und Version werden an jedem Fakt gespeichert. **Offen:** Mit welchem Anbieter starten wir, und liegen API-Schlüssel vor? |
| E6 | Freigabe | Ab 80 % Konfidenz automatisch frei; alles darunter geht in einen **täglichen Bericht der neuen Dokumente**. | Schwelle 0,80 als Einstellung in der DB, nicht im Code. |
| E7 | Suchumfang | DIN 276 KG 300–500 (HOAI-Bezug): alles, was in der Registerstruktur verbaut ist oder fachlich damit zusammenhängt. | Startumfang (10 Hersteller) bleibt der erste Schritt; danach Ausweitung entlang der Registerstruktur. **Offen:** Ist mit „Registerstruktur“ das Elementtyp-Register in cc-core (`tdd.elementtyp`, 217 Typen) gemeint? Dann wird es lesend als Suchliste genutzt. |
| E8 | Fachartikel | Fachartikel für ein Wiki in einer **separaten Datenbank**. | Eigene Datenbank für Fachartikel, gleiche Pipeline (Quelle → Roh → Zwischenebene). **Offen:** eigenes Supabase-Projekt (zusätzliche Kosten) oder eigenes Schema im selben Projekt? |
| E9 | Lernspeicher (`LEARN_SUPABASE_*`) | War nie eingerichtet und muss erledigt werden. | Schema `lern` in der Wissens-DB (Phase 1). Danach nur die drei Secrets in Lovable setzen – der Code dafür existiert bereits. Ausnahme von „keine Änderungen an ElementScout vor Phase 3“, freigegeben am 28.10.2026. Technisch: Code nutzt 3072-dimensionale Embeddings; dafür `halfvec` statt `vector` für den HNSW-Index. |
| E10 | ElementScout öffentlich? | Aktuell Werbetool (öffentlich), später Modul für Mandanten. | Keine Mandantenfunktionen im Startsetup. |
| E11 | IP-Speicherung und Geolokalisierung | Behalten. | Datenschutzerklärung muss das abdecken. |
