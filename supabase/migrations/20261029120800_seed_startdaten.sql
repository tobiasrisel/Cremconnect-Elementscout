-- Phase 1 · Migration 9/9 – Startdaten
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
        'ElementScout (Lovable) supabase/functions/analyze-component/index.ts', 'intern', 'Werte ohne Einzelbeleg aus CREMConnect 2024/2025 übernommen; Status ''roh'', Nachweis über Crawler nötig.', false,
        (select id from einstellung.datentopf where code = 'altbestand'), 'altbestand', 'frei');

insert into ext.preisregel_altbestand (id, art, reihenfolge, hersteller, bezeichnung, muster, muster_flags,
  marktpreis_netto_max, ersatzkosten_netto_max, quellenangabe_alt, quelle_id, herkunft_commit)
select v.id::uuid, v.art, v.reihenfolge, v.hersteller, v.bezeichnung, v.muster, v.muster_flags,
       v.mp, v.ek, v.qa, (select id from kw.quelle where code = 'ALTBESTAND_ES'), 'ed03c8f012b65fac5980930f24b7f7c2735cbd1b'
from (values
  ('087fbfd0-de9b-540c-9946-08fdcf33595f', 'herstellerregel', 1, 'Wilo', null, 'stratos\s+pico\s+plus.*25\/1-6', 'i', 900, 1240, null),
  ('e6c3b163-7de5-57de-88c1-10ff4b4cb93c', 'herstellerregel', 2, 'Wilo', null, 'stratos\s+pico\s+plus.*25\/1-4', 'i', 750, 1005, null),
  ('532539fa-ee5b-55bb-adc3-12f6198a71e9', 'herstellerregel', 3, 'Wilo', null, 'stratos\s+pico\s+plus.*25\/0,?5-6', 'i', 655, 910, null),
  ('f4679e21-3587-592d-aac2-4fdd7ea04134', 'herstellerregel', 4, 'Wilo', null, 'stratos\s+pico\s+plus.*25\/0,?5-4', 'i', 600, 855, null),
  ('f416fd84-375d-5a71-8455-a57a43ecc164', 'herstellerregel', 5, 'Wilo', null, 'yonos\s+pico\s+plus.*25\/1-6', 'i', 380, 635, null),
  ('6eb218a2-688a-5084-a87e-6f77db852d7e', 'herstellerregel', 6, 'Wilo', null, 'yonos\s+pico\s+plus.*25\/1-4', 'i', 320, 575, null),
  ('2a04a2e7-f216-5b89-a34b-dde7d5021aaf', 'herstellerregel', 7, 'Wilo', null, 'wilo.*stratos', 'i', 680, 935, null),
  ('dc253baa-7686-5f80-ba55-0916133a0225', 'herstellerregel', 8, 'Wilo', null, 'wilo.*yonos', 'i', 350, 605, null),
  ('85b2bb2b-1b30-5049-8652-084682b7e8fb', 'herstellerregel', 9, 'Wilo', null, '\bwilo\b', 'i', 500, 800, null),
  ('686b9471-b483-5da2-a3d3-1e912b60e968', 'herstellerregel', 10, 'Grundfos', null, 'alpha3.*25-40\s*180', 'i', 450, 705, null),
  ('d0e53ded-b458-5caa-9efa-86e396fea5ed', 'herstellerregel', 11, 'Grundfos', null, 'alpha3.*25-60\s*180', 'i', 480, 735, null),
  ('7408b2b6-706c-5001-86a6-4f1ca62a10de', 'herstellerregel', 12, 'Grundfos', null, 'alpha3.*25-80\s*180', 'i', 520, 775, null),
  ('090b868c-5552-5327-9736-266ea4bfc3ce', 'herstellerregel', 13, 'Grundfos', null, 'grundfos.*alpha', 'i', 460, 715, null),
  ('3bf00eb3-cc71-573c-b53f-6841ecd2dd6c', 'herstellerregel', 14, 'Grundfos', null, 'grundfos.*magna', 'i', 1250, 1580, null),
  ('ad647c34-37e6-51cf-b30a-13553492111b', 'herstellerregel', 15, 'Grundfos', null, 'grundfos.*ups', 'i', 280, 535, null),
  ('b24dfe62-4ff9-5d13-9a2d-17b4530f0df3', 'herstellerregel', 16, 'Grundfos', null, 'grundfos', 'i', 500, 800, null),
  ('2ec17abb-91b1-5f6c-b264-944c73d5a775', 'herstellerregel', 17, 'Viessmann', null, 'vitodens\s*200', 'i', 4800, 6950, null),
  ('4d7b4e3d-860c-5698-b007-3ab9aff3b498', 'herstellerregel', 18, 'Viessmann', null, 'vitodens\s*300', 'i', 5600, 7850, null),
  ('a11fbeff-05ad-5528-ab12-c977f36e93d5', 'herstellerregel', 19, 'Viessmann', null, 'vitodens\s*100', 'i', 3200, 5100, null),
  ('2998fcbe-e7b8-592f-ace4-b4186e0b0a82', 'herstellerregel', 20, 'Viessmann', null, 'vitocal\s*200', 'i', 8500, 11200, null),
  ('0d1b96be-fda5-56b9-b7fd-eeac79e3748d', 'herstellerregel', 21, 'Viessmann', null, 'vitocal\s*250', 'i', 9800, 12800, null),
  ('7a44d287-d5ba-52fb-8a19-be3cd301367a', 'herstellerregel', 22, 'Viessmann', null, 'vitocal\s*300', 'i', 12500, 15800, null),
  ('0d43b7d6-d8c3-5e48-a2af-3d3c4c7d1577', 'herstellerregel', 23, 'Viessmann', null, 'viessmann.*vitodens', 'i', 4200, 6250, null),
  ('ba58bc18-4b3f-56c9-9902-d390338f2567', 'herstellerregel', 24, 'Viessmann', null, 'viessmann.*vitocal', 'i', 9500, 12500, null),
  ('34234c4b-f64e-54b7-a89e-4489a6ae9979', 'herstellerregel', 25, 'Viessmann', null, 'viessmann.*vitoladens', 'i', 5800, 8200, null),
  ('6d420f1e-d2dd-53ec-9e87-9080eeed4c5f', 'herstellerregel', 26, 'Viessmann', null, 'viessmann', 'i', 4500, 6600, null),
  ('e38fbd84-04dd-59f8-9616-ee926a575a4a', 'herstellerregel', 27, 'Buderus', null, 'logamax\s*plus\s*gb172', 'i', 3400, 5350, null),
  ('fe677ac8-3262-59b6-bb77-ca816007611f', 'herstellerregel', 28, 'Buderus', null, 'logamax\s*plus\s*gb192', 'i', 4200, 6250, null),
  ('5aa29361-848f-5d6c-af03-d1cf81005663', 'herstellerregel', 29, 'Buderus', null, 'logano\s*plus\s*kb192', 'i', 5800, 8100, null),
  ('1dc69ce8-d6ac-55b4-a152-1a2dafdb8722', 'herstellerregel', 30, 'Buderus', null, 'logatherm\s*wlw', 'i', 9200, 12100, null),
  ('d0f421bb-217f-59b1-a12c-a7aa44032102', 'herstellerregel', 31, 'Buderus', null, 'logatherm\s*wps', 'i', 11500, 14800, null),
  ('04f998b3-7fca-5491-8695-16f3b1815b6e', 'herstellerregel', 32, 'Buderus', null, 'buderus', 'i', 4000, 6050, null),
  ('6f48d60b-33d9-5c16-896e-a1d197400756', 'herstellerregel', 33, 'Vaillant', null, 'ecotec\s*plus', 'i', 3800, 5750, null),
  ('fb4763fb-9dd4-5d52-baaf-4b01d3e4cf04', 'herstellerregel', 34, 'Vaillant', null, 'ecotec\s*exclusive', 'i', 4500, 6600, null),
  ('f27d561f-1bd7-5263-a637-b0e231ea5530', 'herstellerregel', 35, 'Vaillant', null, 'arotherm\s*plus', 'i', 9800, 12800, null),
  ('fdaa303e-9e48-5dce-97ea-8f63b430abee', 'herstellerregel', 36, 'Vaillant', null, 'vaillant', 'i', 4200, 6250, null),
  ('e0216219-075b-5017-9c83-f9d2e7d00407', 'herstellerregel', 37, 'Wolf', null, '\bwolf\b', 'i', 3900, 5850, null),
  ('3ae00187-c617-5bfa-ae32-f8d25f5fa643', 'herstellerregel', 38, 'Junkers/Bosch', null, 'cerapur|junkers|bosch.*heiz', 'i', 3600, 5500, null),
  ('3495c977-fc7b-594c-8519-c548e8876e4b', 'herstellerregel', 39, 'Schüco', null, 'sch(ü|u)co', 'i', 600, 950, null),
  ('73c7f8ce-12d2-5b92-8db8-8e21b7b2e6c8', 'herstellerregel', 40, 'Hörmann', null, 'h(ö|o)rmann', 'i', 1500, 2100, null),
  ('cd6f2ca6-76cb-5e6d-9ff2-004c5946058a', 'herstellerregel', 41, 'Grohe', null, 'grohe.*grohtherm', 'i', 380, 580, null),
  ('faa8cfdc-0a16-5862-82b4-1ffa83587e0b', 'herstellerregel', 42, 'Grohe', null, 'grohe', 'i', 200, 380, null),
  ('91cd2415-ddad-56af-ae57-8d5c5f3e0d32', 'herstellerregel', 43, 'Geberit', null, 'geberit.*duofix', 'i', 280, 520, null),
  ('b6898e03-025d-541d-9756-1ca76cb088cf', 'herstellerregel', 44, 'Geberit', null, 'geberit.*sigma', 'i', 150, 320, null),
  ('052366b1-7e4d-5418-81bc-0678405f3196', 'herstellerregel', 45, 'Geberit', null, 'geberit', 'i', 220, 420, null),
  ('44fc6381-5c84-594e-9b81-b2c9e8424099', 'herstellerregel', 46, 'Danfoss', null, 'danfoss.*(ra-n|ra.*2000|eco|living)', 'i', 85, 175, null),
  ('998ec3a3-5526-581c-b2b9-836eaa70f800', 'herstellerregel', 47, 'Danfoss', null, 'danfoss', 'i', 180, 350, null),
  ('f30e48ae-fc64-56cb-a3f1-9a7de6533440', 'herstellerregel', 48, 'KSB', null, 'ksb', 'i', 950, 1380, null),
  ('1b6def97-081e-5421-a93d-04f458b94c10', 'herstellerregel', 49, 'Stiebel-Eltron', null, 'stiebel', 'i', 3500, 5000, null),
  ('7c5035df-ddea-5d01-9945-94fc0895a498', 'herstellerregel', 50, 'Daikin', null, 'daikin.*altherma', 'i', 9800, 12800, null),
  ('b110e54e-97ff-5064-9d7d-a56c35ffb53f', 'herstellerregel', 51, 'Daikin', null, 'daikin', 'i', 2500, 3450, null),
  ('59491af7-251f-5cd9-a1ba-2ed939bc5ac2', 'herstellerregel', 52, 'Zehnder', null, 'zehnder.*charleston', 'i', 500, 1000, null),
  ('49fb82d2-1042-573d-a9ba-6c452108a9b0', 'herstellerregel', 53, 'Zehnder', null, 'zehnder.*nova', 'i', 500, 900, null),
  ('b1676422-2271-5d6d-a9fb-3f933bf7dd5a', 'herstellerregel', 54, 'Zehnder', null, 'zehnder.*(fina|plano|yucca|metropolitan)', 'i', 500, 850, null),
  ('598d2f93-5609-5bd5-b782-e4f4ea8161d3', 'herstellerregel', 55, 'Zehnder', null, 'zehnder.*comfoair', 'i', 3200, 4350, null),
  ('9f98a526-a2b1-57b8-ad40-db04add24088', 'herstellerregel', 56, 'Zehnder', null, 'zehnder', 'i', 500, 900, null),
  ('8e97918f-689f-5293-93cd-ed5e912db929', 'herstellerregel', 57, 'Kermi', null, 'kermi.*therm-?x2.*(profil|plan|line)', 'i', 500, 850, null),
  ('fa3961aa-a9df-5afd-865f-e839de79b22c', 'herstellerregel', 58, 'Kermi', null, 'kermi.*verteo', 'i', 500, 900, null),
  ('d1861f81-171a-5c4b-a7b2-423d310c24e6', 'herstellerregel', 59, 'Kermi', null, 'kermi.*basic-?50', 'i', 280, 520, null),
  ('7e8f3466-0c03-5ab3-9a8d-15548ffc7336', 'herstellerregel', 60, 'Kermi', null, 'kermi.*(atea|pasa|raya)', 'i', 500, 950, null),
  ('b9248525-0f72-5701-85b9-2d184c9763bc', 'herstellerregel', 61, 'Kermi', null, 'kermi', 'i', 480, 810, null),
  ('72d04128-847c-53ff-908f-5698f95cf6f7', 'herstellerregel', 62, 'Oventrop', null, 'oventrop', 'i', 75, 155, null),
  ('70d79d03-212a-57e8-b310-a891e98a966a', 'herstellerregel', 63, 'IMI Hydronic', null, '(imi.*hydronic|heimeier|pneumatex|ta.*stad)', 'i', 65, 150, null),
  ('1f8ff269-d800-5c33-8daf-76275f0cfa02', 'herstellerregel', 64, 'VELUX', null, 'velux', 'i', 820, 1330, null),
  ('cf58dd9d-8275-5e4d-bae2-77a4dc42b28e', 'herstellerregel', 65, 'ROTO', null, '\broto\b', 'i', 650, 1075, null),
  ('c14dbd5d-669b-5b7a-9896-e27896d38734', 'herstellerregel', 66, 'Braas', null, 'braas', 'i', 70, 130, null),
  ('90d31ebb-4a18-58cb-b478-19d6ca8b5513', 'herstellerregel', 67, 'Sto', null, '\bsto\b|stotherm', 'i', 210, 265, null),
  ('7e458388-dc58-5361-ad42-2fd26239638c', 'preisdeckel', 1, null, 'Heizkörper Standard (Typ 22)', 'heizk(ö|o)rper|radiator|plattenheizk(ö|o)rper', 'i', 500, 900, 'Herstellerdatenbank Heizkörper Typ 22 / Kermi / Zehnder 2024/2025 – Endkunde ≤ 500 € netto'),
  ('64ac08a2-91ca-5623-97b0-d3d9dc99fbfe', 'preisdeckel', 2, null, 'Thermostatventil', 'thermostatventil|thermostatkopf', 'i', 150, 300, 'Herstellerdatenbank Heimeier / Danfoss / Oventrop 2024/2025'),
  ('21ccc37e-db8f-5580-9439-e350f58b45d8', 'preisdeckel', 3, null, 'Umwälzpumpe Standard', 'umw(ä|a)lzpumpe|zirkulationspumpe', 'i', 900, 1300, 'Herstellerdatenbank Wilo / Grundfos 2024/2025'),
  ('0e1f61be-c76a-5a26-8088-2b6c4bdfad4a', 'preisdeckel', 4, null, 'Fenster Kunststoff Standard', 'kunststofffenster|fenster.*kunststoff', 'i', 950, 1300, 'Endkundenpreise Kunststofffenster 3-fach 2024/2025'),
  ('20627aa0-1242-53fa-8b1c-79acb2a0437e', 'preisdeckel', 5, null, 'Innentür Standard', 'innent(ü|u)r', 'i', 600, 800, 'Endkundenpreise Innentür + Zarge 2024/2025'),
  ('2baf0a52-5f1f-582f-817e-b2f0ca54201d', 'preisdeckel', 6, null, 'Ausdehnungsgefäß 25L', 'ausdehnungsgef(ä|a)(ss|ß)', 'i', 280, 450, 'Endkundenpreise MAG/AG 2024/2025')
) as v(id, art, reihenfolge, hersteller, bezeichnung, muster, muster_flags, mp, ek, qa);

-- Hersteller aus kw verknüpfen, nicht kopieren (E12)
insert into ref.akteur (name, website, kw_hersteller_id)
select h.name, h.url, h.id from kw.hersteller h
on conflict (kw_hersteller_id) do nothing;
insert into ref.akteur_rolle (akteur_id, rolle_code, kontext)
select a.id, 'hersteller', 'aus kw.hersteller' from ref.akteur a where a.kw_hersteller_id is not null
on conflict do nothing;
