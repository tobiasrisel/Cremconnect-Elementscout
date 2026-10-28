# Phase 0 – Abnahmeprotokoll

Stand: 28.10.2026

| Vorgabe | Ergebnis | Nachweis |
| --- | --- | --- |
| Repo existiert | erledigt | `tobiasrisel/Cremconnect-Elementscout`, privat, Branch `main` |
| Seed-Datei vollständig | erledigt | `seed/altbestand_preise.json`: 67 Herstellerregeln (23 Hersteller), 6 Preisdeckel – so viele Regeln wie im Code (`analyze-component/index.ts`, Commit ed03c8f0) |
| Lovable-GitHub-Schritte genannt | erledigt | unten |

Die Regeln sind 1:1 übernommen, auch Muster und Reihenfolge (die erste passende Regel gewinnt).
Status aller Einträge: `roh`, weil die Werte keinen Einzelbeleg haben. Belege liefert der
Crawler in Phase 2.

## ElementScout in Lovable mit GitHub verbinden

Quelle: [Lovable-Doku GitHub](https://docs.lovable.dev/integrations/github), abgerufen 28.10.2026.

1. Im Lovable-Projekt **Project settings → Git → GitHub** öffnen (oder über das **+** neben dem
   Chat-Eingabefeld: **Project → GitHub**).
2. Falls der Workspace noch keine GitHub-Verbindung hat: **Add connection → Add account**, im
   Popup das Konto `tobiasrisel` wählen, Repositories freigeben und **Install & Authorize**.
3. In den GitHub-Einstellungen des Projekts bei dieser Verbindung auf **Connect** klicken.

Lovable legt dabei **immer ein neues, privates Repository** an und synchronisiert in beide
Richtungen. Ein vorhandenes Repo wie dieses lässt sich nicht verbinden. Der App-Code von
ElementScout landet deshalb in einem eigenen Repo, getrennt von dieser Wissensdatenbank.
Das Repo lässt sich danach umbenennen, ohne dass die Synchronisation abbricht.
