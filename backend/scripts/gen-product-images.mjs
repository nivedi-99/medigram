#!/usr/bin/env node
/**
 * gen-product-images.mjs — generates one clean pharmaceutical product shot
 * per catalogue category with the Gemini image model and writes it to
 * web/assets/products/<slug>.png (idempotent: skips existing files).
 *
 *   node scripts/gen-product-images.mjs
 */
import { readFileSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));

function loadEnv() {
  const envPath = path.join(here, '..', '.env');
  const out = {};
  if (existsSync(envPath)) {
    for (const line of readFileSync(envPath, 'utf8').split(/\r?\n/)) {
      const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.+?)\s*$/);
      if (m) out[m[1]] = m[2];
    }
  }
  return out;
}

const { GEMINI_API_KEY } = loadEnv();
if (!GEMINI_API_KEY) {
  console.error('[images] missing GEMINI_API_KEY in backend/.env');
  process.exit(2);
}

const MODEL = 'gemini-3-pro-image';
const OUT_DIR = path.join(here, '..', '..', 'web', 'assets', 'products');

const CATEGORIES = [
  ['Pain Killers', 'pain-killers', 'blister packs of analgesic tablets and a topical pain-relief gel tube'],
  ['Antibiotics', 'antibiotics', 'capsule blister packs and a small vial of injectable antibiotic'],
  ['Erectile Dysfunction', 'erectile-dysfunction', 'discreet blue tablet blister packs'],
  ['Steroids', 'steroids', '10 ml oily injection ampoules in a tray'],
  ['Anti-Anxiety', 'anti-anxiety', 'small tablet blister packs and a pill organizer'],
  ['Hair Care', 'hair-care', 'a minoxidil dropper bottle, shampoo bottle and tablet strip'],
  ['Sleeping Pills', 'sleeping-pills', 'soft-blue tablet blister packs beside a night-themed box'],
  ['Anti Parasitic', 'anti-parasitic', 'tablet blister packs and vials for antiparasitic therapy'],
  ['Anti Diabetic', 'anti-diabetic', 'an insulin pen, glucose test strips and metformin blister packs'],
  ['Skin Care', 'skin-care', 'pharmaceutical cream tubes and a serum bottle'],
  ['Womens Health', 'womens-health', 'tablet strips and folic acid bottle in soft pink styling'],
  ['Weight Loss', 'weight-loss', 'capsule blister packs, a measuring tape and a protein scoop'],
  ['Veterinary', 'veterinary', 'large animal-injection vials and a pour-on bottle with a paw icon'],
  ['Wakefulness', 'wakefulness', 'white tablet blister packs with a bright alert-themed box'],
  ['Anti Cancer', 'anti-cancer', 'oncology injection vials in a protective tray and tablet packs'],
  ['Ayurvedic', 'ayurvedic', 'herbal capsules, a chyawanprash jar and turmeric powder with green leaves'],
  ['Contraceptives', 'contraceptives', 'cycle-pack pill wallets and an IUD device in sterile packaging'],
  ['Drops & Syrups', 'drops-syrups', 'paediatric syrup bottles with measuring cups and ORS sachets'],
  ['HCG & HGH', 'hcg-hgh', 'vials with solvent ampoules in cold-chain packaging'],
  ['Health Supplements', 'health-supplements', 'protein jar, omega-3 softgel blister and multivitamin bottles'],
  ['Mens Health', 'mens-health', 'tablet blister packs in deep blue styling'],
  ['Pharmaceutical Tablets', 'pharmaceutical-tablets', 'assorted white tablet blister packs and pill bottles'],
  ['PrEP', 'prep', 'blue-white pill bottles with red-ribbon themed box'],
  ['Heart & BP', 'heart-bp', 'cardiovascular tablet blisters beside a stethoscope'],
];

function promptFor(subject) {
  return (
    `Professional pharmaceutical export catalogue photograph: ${subject}. ` +
    'Arranged neatly on a clean pure-white studio background, soft diffused lighting, ' +
    'subtle shadows, crisp focus, unbranded plain packaging with no readable text, ' +
    'centered balanced composition, commercial product photography style.'
  );
}

async function generate(category, slug, subject) {
  const outPath = path.join(OUT_DIR, `${slug}.png`);
  if (existsSync(outPath)) {
    console.log(`[images] ${slug}: exists, skipping`);
    return;
  }
  const body = {
    contents: [{ parts: [{ text: promptFor(subject) }] }],
    generationConfig: { responseModalities: ['TEXT', 'IMAGE'] },
  };
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_API_KEY}`,
    { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) },
  );
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`${category} -> HTTP ${res.status}: ${text.slice(0, 200)}`);
  }
  const json = await res.json();
  const parts = json?.candidates?.[0]?.content?.parts ?? [];
  const image = parts.find((p) => p.inlineData?.data);
  if (!image) throw new Error(`${category} -> no image part in response`);
  writeFileSync(outPath, Buffer.from(image.inlineData.data, 'base64'));
  console.log(`[images] ${slug}: saved (${category})`);
}

mkdirSync(OUT_DIR, { recursive: true });
let done = 0;
for (const [category, slug, subject] of CATEGORIES) {
  try {
    await generate(category, slug, subject);
    done++;
  } catch (err) {
    console.error(`[images] FAILED ${category}: ${err.message}`);
  }
  await new Promise((r) => setTimeout(r, 800));
}
console.log(`[images] DONE — ${done}/${CATEGORIES.length} category images in ${OUT_DIR}`);