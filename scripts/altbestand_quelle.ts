// Wortgleiche Kopie der Preisregeln aus dem Lovable-Projekt ElementScout
// (supabase/functions/analyze-component/index.ts, Commit ed03c8f0, Stand 24.10.2026).
// Nur zur Übernahme in seed/altbestand_preise.json – nicht weiter pflegen.

export const MANUFACTURER_OVERRIDES = [
  // Wilo Pumpen
  { brand: "Wilo", match: /stratos\s+pico\s+plus.*25\/1-6/i, marketPrice: 900, replacementCost: 1240 },
  { brand: "Wilo", match: /stratos\s+pico\s+plus.*25\/1-4/i, marketPrice: 750, replacementCost: 1005 },
  { brand: "Wilo", match: /stratos\s+pico\s+plus.*25\/0,?5-6/i, marketPrice: 655, replacementCost: 910 },
  { brand: "Wilo", match: /stratos\s+pico\s+plus.*25\/0,?5-4/i, marketPrice: 600, replacementCost: 855 },
  { brand: "Wilo", match: /yonos\s+pico\s+plus.*25\/1-6/i, marketPrice: 380, replacementCost: 635 },
  { brand: "Wilo", match: /yonos\s+pico\s+plus.*25\/1-4/i, marketPrice: 320, replacementCost: 575 },
  { brand: "Wilo", match: /wilo.*stratos/i, marketPrice: 680, replacementCost: 935 },
  { brand: "Wilo", match: /wilo.*yonos/i, marketPrice: 350, replacementCost: 605 },
  { brand: "Wilo", match: /\bwilo\b/i, marketPrice: 500, replacementCost: 800 },

  // Grundfos Pumpen
  { brand: "Grundfos", match: /alpha3.*25-40\s*180/i, marketPrice: 450, replacementCost: 705 },
  { brand: "Grundfos", match: /alpha3.*25-60\s*180/i, marketPrice: 480, replacementCost: 735 },
  { brand: "Grundfos", match: /alpha3.*25-80\s*180/i, marketPrice: 520, replacementCost: 775 },
  { brand: "Grundfos", match: /grundfos.*alpha/i, marketPrice: 460, replacementCost: 715 },
  { brand: "Grundfos", match: /grundfos.*magna/i, marketPrice: 1250, replacementCost: 1580 },
  { brand: "Grundfos", match: /grundfos.*ups/i, marketPrice: 280, replacementCost: 535 },
  { brand: "Grundfos", match: /grundfos/i, marketPrice: 500, replacementCost: 800 },

  // Viessmann Heizung
  { brand: "Viessmann", match: /vitodens\s*200/i, marketPrice: 4800, replacementCost: 6950 },
  { brand: "Viessmann", match: /vitodens\s*300/i, marketPrice: 5600, replacementCost: 7850 },
  { brand: "Viessmann", match: /vitodens\s*100/i, marketPrice: 3200, replacementCost: 5100 },
  { brand: "Viessmann", match: /vitocal\s*200/i, marketPrice: 8500, replacementCost: 11200 },
  { brand: "Viessmann", match: /vitocal\s*250/i, marketPrice: 9800, replacementCost: 12800 },
  { brand: "Viessmann", match: /vitocal\s*300/i, marketPrice: 12500, replacementCost: 15800 },
  { brand: "Viessmann", match: /viessmann.*vitodens/i, marketPrice: 4200, replacementCost: 6250 },
  { brand: "Viessmann", match: /viessmann.*vitocal/i, marketPrice: 9500, replacementCost: 12500 },
  { brand: "Viessmann", match: /viessmann.*vitoladens/i, marketPrice: 5800, replacementCost: 8200 },
  { brand: "Viessmann", match: /viessmann/i, marketPrice: 4500, replacementCost: 6600 },

  // Buderus Heizung
  { brand: "Buderus", match: /logamax\s*plus\s*gb172/i, marketPrice: 3400, replacementCost: 5350 },
  { brand: "Buderus", match: /logamax\s*plus\s*gb192/i, marketPrice: 4200, replacementCost: 6250 },
  { brand: "Buderus", match: /logano\s*plus\s*kb192/i, marketPrice: 5800, replacementCost: 8100 },
  { brand: "Buderus", match: /logatherm\s*wlw/i, marketPrice: 9200, replacementCost: 12100 },
  { brand: "Buderus", match: /logatherm\s*wps/i, marketPrice: 11500, replacementCost: 14800 },
  { brand: "Buderus", match: /buderus/i, marketPrice: 4000, replacementCost: 6050 },

  // Vaillant / Wolf / Junkers
  { brand: "Vaillant", match: /ecotec\s*plus/i, marketPrice: 3800, replacementCost: 5750 },
  { brand: "Vaillant", match: /ecotec\s*exclusive/i, marketPrice: 4500, replacementCost: 6600 },
  { brand: "Vaillant", match: /arotherm\s*plus/i, marketPrice: 9800, replacementCost: 12800 },
  { brand: "Vaillant", match: /vaillant/i, marketPrice: 4200, replacementCost: 6250 },
  { brand: "Wolf", match: /\bwolf\b/i, marketPrice: 3900, replacementCost: 5850 },
  { brand: "Junkers/Bosch", match: /cerapur|junkers|bosch.*heiz/i, marketPrice: 3600, replacementCost: 5500 },

  // Schüco / Hörmann
  { brand: "Schüco", match: /sch(ü|u)co/i, marketPrice: 600, replacementCost: 950 },
  { brand: "Hörmann", match: /h(ö|o)rmann/i, marketPrice: 1500, replacementCost: 2100 },

  // Grohe / Geberit
  { brand: "Grohe", match: /grohe.*grohtherm/i, marketPrice: 380, replacementCost: 580 },
  { brand: "Grohe", match: /grohe/i, marketPrice: 200, replacementCost: 380 },
  { brand: "Geberit", match: /geberit.*duofix/i, marketPrice: 280, replacementCost: 520 },
  { brand: "Geberit", match: /geberit.*sigma/i, marketPrice: 150, replacementCost: 320 },
  { brand: "Geberit", match: /geberit/i, marketPrice: 220, replacementCost: 420 },

  // Danfoss / KSB
  { brand: "Danfoss", match: /danfoss.*(ra-n|ra.*2000|eco|living)/i, marketPrice: 85, replacementCost: 175 },
  { brand: "Danfoss", match: /danfoss/i, marketPrice: 180, replacementCost: 350 },
  { brand: "KSB", match: /ksb/i, marketPrice: 950, replacementCost: 1380 },

  // Stiebel-Eltron / Daikin
  { brand: "Stiebel-Eltron", match: /stiebel/i, marketPrice: 3500, replacementCost: 5000 },
  { brand: "Daikin", match: /daikin.*altherma/i, marketPrice: 9800, replacementCost: 12800 },
  { brand: "Daikin", match: /daikin/i, marketPrice: 2500, replacementCost: 3450 },

  // Zehnder Heizkörper / Lüftung
  { brand: "Zehnder", match: /zehnder.*charleston/i, marketPrice: 500, replacementCost: 1000 },
  { brand: "Zehnder", match: /zehnder.*nova/i, marketPrice: 500, replacementCost: 900 },
  { brand: "Zehnder", match: /zehnder.*(fina|plano|yucca|metropolitan)/i, marketPrice: 500, replacementCost: 850 },
  { brand: "Zehnder", match: /zehnder.*comfoair/i, marketPrice: 3200, replacementCost: 4350 },
  { brand: "Zehnder", match: /zehnder/i, marketPrice: 500, replacementCost: 900 },

  // Kermi Heizkörper
  { brand: "Kermi", match: /kermi.*therm-?x2.*(profil|plan|line)/i, marketPrice: 500, replacementCost: 850 },
  { brand: "Kermi", match: /kermi.*verteo/i, marketPrice: 500, replacementCost: 900 },
  { brand: "Kermi", match: /kermi.*basic-?50/i, marketPrice: 280, replacementCost: 520 },
  { brand: "Kermi", match: /kermi.*(atea|pasa|raya)/i, marketPrice: 500, replacementCost: 950 },
  { brand: "Kermi", match: /kermi/i, marketPrice: 480, replacementCost: 810 },

  // Oventrop / IMI / Heimeier – Armaturen
  { brand: "Oventrop", match: /oventrop/i, marketPrice: 75, replacementCost: 155 },
  { brand: "IMI Hydronic", match: /(imi.*hydronic|heimeier|pneumatex|ta.*stad)/i, marketPrice: 65, replacementCost: 150 },

  // VELUX / ROTO
  { brand: "VELUX", match: /velux/i, marketPrice: 820, replacementCost: 1330 },
  { brand: "ROTO", match: /\broto\b/i, marketPrice: 650, replacementCost: 1075 },

  // Braas Dach
  { brand: "Braas", match: /braas/i, marketPrice: 70, replacementCost: 130 },

  // Sto Fassade
  { brand: "Sto", match: /\bsto\b|stotherm/i, marketPrice: 210, replacementCost: 265 },
];

export const GENERIC_CAPS = [
  { key: "Heizkörper Standard (Typ 22)", match: /heizk(ö|o)rper|radiator|plattenheizk(ö|o)rper/i, maxMarketPrice: 500, maxReplacementCost: 900, source: "Herstellerdatenbank Heizkörper Typ 22 / Kermi / Zehnder 2024/2025 – Endkunde ≤ 500 € netto" },
  { key: "Thermostatventil", match: /thermostatventil|thermostatkopf/i, maxMarketPrice: 150, maxReplacementCost: 300, source: "Herstellerdatenbank Heimeier / Danfoss / Oventrop 2024/2025" },
  { key: "Umwälzpumpe Standard", match: /umw(ä|a)lzpumpe|zirkulationspumpe/i, maxMarketPrice: 900, maxReplacementCost: 1300, source: "Herstellerdatenbank Wilo / Grundfos 2024/2025" },
  { key: "Fenster Kunststoff Standard", match: /kunststofffenster|fenster.*kunststoff/i, maxMarketPrice: 950, maxReplacementCost: 1300, source: "Endkundenpreise Kunststofffenster 3-fach 2024/2025" },
  { key: "Innentür Standard", match: /innent(ü|u)r/i, maxMarketPrice: 600, maxReplacementCost: 800, source: "Endkundenpreise Innentür + Zarge 2024/2025" },
  { key: "Ausdehnungsgefäß 25L", match: /ausdehnungsgef(ä|a)(ss|ß)/i, maxMarketPrice: 280, maxReplacementCost: 450, source: "Endkundenpreise MAG/AG 2024/2025" },
];
