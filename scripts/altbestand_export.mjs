// Erzeugt seed/altbestand_preise.json aus scripts/altbestand_quelle.ts
// Aufruf: node --experimental-strip-types scripts/altbestand_export.mjs
import { writeFileSync } from "node:fs";
import { createHash } from "node:crypto";
const { MANUFACTURER_OVERRIDES, GENERIC_CAPS } = await import("./altbestand_quelle.ts");

const quelle = {
  bezeichnung: "Altbestand 2024/2025",
  herkunft: "ElementScout (Lovable) supabase/functions/analyze-component/index.ts",
  commit: "ed03c8f012b65fac5980930f24b7f7c2735cbd1b",
  stand_code: "2026-10-24",
  hinweis: "Werte ohne Einzelbeleg aus CREMConnect 2024/2025 übernommen; Status 'roh', Nachweis über Crawler nötig.",
  waehrung: "EUR", basis: "netto",
};
// stabile IDs (UUID v5-artig aus Inhalt), damit ein erneuter Export dieselben IDs liefert
const sid = (s) => { const h = createHash("sha1").update("cc-knowledge-altbestand:" + s).digest("hex");
  return `${h.slice(0,8)}-${h.slice(8,12)}-5${h.slice(13,16)}-${(8 | (parseInt(h[16],16) & 3)).toString(16)}${h.slice(17,20)}-${h.slice(20,32)}`; };

const herstellerregeln = MANUFACTURER_OVERRIDES.map((r, i) => ({
  id: sid(`hersteller|${i}|${r.match.source}`),
  reihenfolge: i + 1,            // erste passende Regel gewinnt – Reihenfolge ist fachlich relevant
  hersteller: r.brand,
  muster: r.match.source, muster_flags: r.match.flags,
  marktpreis_netto_max: r.marketPrice,       // reiner Netto-Einkaufspreis (UVP)
  ersatzkosten_netto_max: r.replacementCost, // Vollersatz inkl. Montage
  status: "roh",
}));
const preisdeckel = GENERIC_CAPS.map((c, i) => ({
  id: sid(`deckel|${i}|${c.match.source}`),
  reihenfolge: i + 1,
  bezeichnung: c.key,
  muster: c.match.source, muster_flags: c.match.flags,
  marktpreis_netto_max: c.maxMarketPrice,
  ersatzkosten_netto_max: c.maxReplacementCost,
  quellenangabe_alt: c.source,
  status: "roh",
}));
const out = { quelle, anzahl: { herstellerregeln: herstellerregeln.length, preisdeckel: preisdeckel.length }, herstellerregeln, preisdeckel };
writeFileSync("seed/altbestand_preise.json", JSON.stringify(out, null, 2) + "\n");
console.log(out.anzahl, "Hersteller:", [...new Set(herstellerregeln.map(r => r.hersteller))].length);
