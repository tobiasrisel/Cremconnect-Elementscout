-- Phase 1 · Nachtrag – Indizes für Fremdschlüssel der neuen Tabellen (Supabase-Advisor „unindexed_foreign_keys“).
-- kw bleibt unberührt; einzige Ausnahme ist die neue Spalte kw.quelle.datentopf_id aus Migration 1.

create index if not exists extraktionslauf_modell_id_fkey_idx on ext.extraktionslauf (modell_id);
create index if not exists fakt_abschnitt_id_fkey_idx on ext.fakt (abschnitt_id);
create index if not exists fakt_extraktionslauf_id_fkey_idx on ext.fakt (extraktionslauf_id);
create index if not exists fakt_vorgaenger_id_fkey_idx on ext.fakt (vorgaenger_id);
create index if not exists preisregel_altbestand_quelle_id_fkey_idx on ext.preisregel_altbestand (quelle_id);
create index if not exists pruefbefund_bezug_fakt_id_fkey_idx on ext.pruefbefund (bezug_fakt_id);
create index if not exists quelle_datentopf_id_fkey_idx on kw.quelle (datentopf_id);
create index if not exists register_element_baugruppe_knoten_id_fkey_idx on map.register_element (baugruppe_knoten_id);
create index if not exists zuordnung_register_element_id_fkey_idx on map.zuordnung (register_element_id);
create index if not exists akteur_herkunft_fakt_id_fkey_idx on ref.akteur (herkunft_fakt_id);
create index if not exists akteur_rolle_herkunft_fakt_id_fkey_idx on ref.akteur_rolle (herkunft_fakt_id);
create index if not exists ausschreibungsposition_ersetzt_durch_fkey_idx on ref.ausschreibungsposition (ersetzt_durch);
create index if not exists ausschreibungsposition_herkunft_fakt_id_fkey_idx on ref.ausschreibungsposition (herkunft_fakt_id);
create index if not exists ausschreibungsposition_produkt_id_fkey_idx on ref.ausschreibungsposition (produkt_id);
create index if not exists produkt_ersetzt_durch_fkey_idx on ref.produkt (ersetzt_durch);
create index if not exists produkt_herkunft_fakt_id_fkey_idx on ref.produkt (herkunft_fakt_id);
create index if not exists produktdokument_dokument_version_id_fkey_idx on ref.produktdokument (dokument_version_id);
create index if not exists produktmerkmal_ersetzt_durch_fkey_idx on ref.produktmerkmal (ersetzt_durch);
create index if not exists produktmerkmal_herkunft_fakt_id_fkey_idx on ref.produktmerkmal (herkunft_fakt_id);
create index if not exists regelwerk_fassung_herkunft_fakt_id_fkey_idx on ref.regelwerk_fassung (herkunft_fakt_id);
create index if not exists artikel_dokument_version_id_fkey_idx on wiki.artikel (dokument_version_id);
create index if not exists artikel_extraktionslauf_id_fkey_idx on wiki.artikel (extraktionslauf_id);
create index if not exists artikel_vorgaenger_id_fkey_idx on wiki.artikel (vorgaenger_id);
