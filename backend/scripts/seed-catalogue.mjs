#!/usr/bin/env node
/**
 * seed-catalogue.mjs — normalizes category names and expands the export
 * catalogue so every category carries a solid set of products (idempotent:
 * existing product names are never duplicated; renames are applied once).
 *
 *   node scripts/seed-catalogue.mjs
 *
 * Uses SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY from backend/.env.
 * All entries are original generic (INN-based) export listings authored for
 * MediGram — no third-party catalogue content is copied.
 */
import { readFileSync, existsSync } from 'node:fs';
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

const env = loadEnv();
const BASE = (env.SUPABASE_URL || '').replace(/\/$/, '');
const KEY = env.SUPABASE_SERVICE_ROLE_KEY;
if (!BASE || !KEY) {
  console.error('[seed] missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY in backend/.env');
  process.exit(2);
}

const HEADERS = {
  apikey: KEY,
  Authorization: `Bearer ${KEY}`,
  'Content-Type': 'application/json',
};

async function rest(method, urlPath, body) {
  const res = await fetch(`${BASE}/rest/v1/${urlPath}`, {
    method,
    headers: { ...HEADERS, Prefer: 'return=minimal' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`${method} ${urlPath} -> HTTP ${res.status}: ${text.slice(0, 300)}`);
  }
  if (method === 'GET') {
    const text = await res.text();
    return text ? JSON.parse(text) : [];
  }
  return null;
}

/** Category-name normalization applied to existing rows (once — idempotent). */
const RENAMES = {
  'Steriods': 'Steroids',
  'Anti-Biotics': 'Antibiotics',
  'Ed Medicines': 'Erectile Dysfunction',
  'Anti Parasites': 'Anti Parasitic',
  'Anti-Diabetics': 'Anti Diabetic',
  'Skin Cream': 'Skin Care',
  "Women's Personal Use": 'Womens Health',
  'Dogs Medicines': 'Veterinary',
};

/** [name, category, manufacturer, description, priceUSD, moq] */
const PRODUCTS = [
// --- Pain Killers (top-up) ---
['Etoricoxib 90 mg Tablets', 'Pain Killers', 'MedRelief Labs', 'COX-2 selective analgesic tablets, 10x10 export pack.', 2.40, 100],
['Naproxen 250 mg Tablets', 'Pain Killers', 'MedRelief Labs', 'NSAID tablets for musculoskeletal pain, 25x10 blister pack.', 1.35, 200],
['Aceclofenac 100 mg Tablets', 'Pain Killers', 'Wellcura Pharma', 'NSAID tablets, alu-alu blister, 10x10 export pack.', 1.10, 300],
['Diclofenac Sodium 75 mg/ml Injection', 'Pain Killers', 'Wellcura Pharma', 'Aqueous injection, 3 ml ampoules, pack of 10.', 0.85, 500],
['Nimesulide 100 mg Dispersible Tablets', 'Pain Killers', 'MedRelief Labs', 'Dispersible analgesic tablets, 10x10 pack.', 0.95, 300],
['Serratiopeptidase 10 mg Tablets', 'Pain Killers', 'Wellcura Pharma', 'Enzyme anti-inflammatory tablets, 10x10 export pack.', 1.60, 200],
// --- Antibiotics (top-up) ---
['Azithromycin 500 mg Tablets', 'Antibiotics', 'BioCure Labs', 'Macrolide antibiotic tablets, 3x10 blister pack.', 1.90, 200],
['Amoxicillin 500 mg Capsules', 'Antibiotics', 'BioCure Labs', 'Broad-spectrum penicillin capsules, 10x10 pack.', 1.25, 500],
['Cefixime 200 mg Tablets', 'Antibiotics', 'Wellcura Pharma', 'Third-generation cephalosporin tablets, 10x10 pack.', 2.10, 200],
['Levofloxacin 500 mg Tablets', 'Antibiotics', 'BioCure Labs', 'Fluoroquinolone tablets, 10x10 export pack.', 1.75, 200],
['Doxycycline 100 mg Capsules', 'Antibiotics', 'MedRelief Labs', 'Tetracycline-class capsules, 10x10 pack.', 1.05, 500],
['Ceftriaxone 1 g Injection', 'Antibiotics', 'Wellcura Pharma', 'Sterile powder for injection with diluent, vial of 1.', 1.45, 500],
// --- Erectile Dysfunction (top-up) ---
['Sildenafil Citrate 100 mg Tablets', 'Erectile Dysfunction', 'VitaCore Pharma', 'Film-coated tablets, 4-count and 10x10 export packs.', 0.90, 500],
['Tadalafil 20 mg Tablets', 'Erectile Dysfunction', 'VitaCore Pharma', 'PD5 inhibitor tablets, 4-count and 10x10 packs.', 1.05, 500],
['Vardenafil 10 mg Tablets', 'Erectile Dysfunction', 'MedRelief Labs', 'PD5 inhibitor tablets, 10x10 blister pack.', 1.30, 300],
['Avanafil 100 mg Tablets', 'Erectile Dysfunction', 'VitaCore Pharma', 'Second-generation PD5 inhibitor, 10x10 pack.', 1.85, 200],
['Dapoxetine 60 mg Tablets', 'Erectile Dysfunction', 'MedRelief Labs', 'Short-acting SSRI tablets, 10x10 export pack.', 1.15, 300],
// --- Steroids (top-up) ---
['Testosterone Enanthate 250 mg/ml Injection', 'Steroids', 'AndroTech Labs', 'Oily injection, 10x1 ml ampoules, export pack.', 3.20, 200],
['Nandrolone Decanoate 250 mg/ml Injection', 'Steroids', 'AndroTech Labs', 'Oily injection, 10x1 ml ampoules.', 3.40, 200],
['Stanozolol 10 mg Tablets', 'Steroids', 'AndroTech Labs', 'Oral steroid tablets, 100-tablet export pack.', 1.50, 200],
['Oxandrolone 10 mg Tablets', 'Steroids', 'AndroTech Labs', 'Oral steroid tablets, 100-tablet pack.', 2.60, 100],
['Methandienone 10 mg Tablets', 'Steroids', 'AndroTech Labs', 'Oral steroid tablets, 100-tablet pack.', 1.20, 200],
// --- Anti-Anxiety (top-up) ---
['Escitalopram 10 mg Tablets', 'Anti-Anxiety', 'NeuroCure Pharma', 'SSRI tablets, 10x10 alu-alu export pack.', 1.30, 200],
['Sertraline 50 mg Tablets', 'Anti-Anxiety', 'NeuroCure Pharma', 'SSRI tablets, 10x10 export pack.', 1.20, 200],
['Buspirone 10 mg Tablets', 'Anti-Anxiety', 'MedRelief Labs', 'Anxiolytic tablets, 10x10 blister pack.', 1.10, 200],
['Alprazolam 0.5 mg Tablets', 'Anti-Anxiety', 'NeuroCure Pharma', 'Benzodiazepine tablets — export under licence, 10x10 pack.', 0.95, 200],
['Clonazepam 2 mg Tablets', 'Anti-Anxiety', 'NeuroCure Pharma', 'Benzodiazepine tablets — export under licence, 10x10 pack.', 1.00, 200],
// --- Hair Care (top-up) ---
['Minoxidil 5% Topical Solution', 'Hair Care', 'DermaCare India', '60 ml scalp solution with dropper, 24 bottles per carton.', 2.80, 200],
['Finasteride 1 mg Tablets', 'Hair Care', 'Wellcura Pharma', 'DHT-blocker tablets, 10x10 export pack.', 1.40, 300],
['Biotin 10 mg Tablets', 'Hair Care', 'Nutriva Labs', 'Hair-health supplement tablets, 10x10 pack.', 1.05, 500],
['Ketoconazole 2% Shampoo', 'Hair Care', 'DermaCare India', 'Antifungal shampoo, 100 ml bottles, 48 per carton.', 1.90, 200],
['Saw Palmetto 320 mg Softgels', 'Hair Care', 'Nutriva Labs', 'Herbal DHT-support softgels, 10x10 pack.', 1.55, 300],
// --- Sleeping Pills (top-up) ---
['Zolpidem 10 mg Tablets', 'Sleeping Pills', 'NeuroCure Pharma', 'Short-course hypnotic tablets — export under licence, 10x10 pack.', 1.25, 200],
['Eszopiclone 3 mg Tablets', 'Sleeping Pills', 'NeuroCure Pharma', 'Non-benzodiazepine hypnotic tablets, 10x10 pack.', 1.65, 200],
['Melatonin 10 mg Tablets', 'Sleeping Pills', 'Nutriva Labs', 'Sleep-support supplement tablets, 10x10 export pack.', 1.00, 500],
['Doxylamine 25 mg Tablets', 'Sleeping Pills', 'MedRelief Labs', 'Antihistamine sleep-aid tablets, 10x10 pack.', 0.90, 300],
['Suvorexant 20 mg Tablets', 'Sleeping Pills', 'NeuroCure Pharma', 'Orexin-antagonist tablets, 10x10 export pack.', 2.90, 100],
['Temazepam 15 mg Tablets', 'Sleeping Pills', 'NeuroCure Pharma', 'Benzodiazepine hypnotic — export under licence, 10x10 pack.', 1.20, 200],
// --- Anti Parasitic (top-up) ---
['Ivermectin 12 mg Tablets', 'Anti Parasitic', 'MedRelief Labs', 'Antiparasitic tablets, 10x10 export pack.', 1.20, 300],
['Albendazole 400 mg Tablets', 'Anti Parasitic', 'Wellcura Pharma', 'Anthelmintic tablets, 10x10 pack.', 0.80, 500],
['Praziquantel 600 mg Tablets', 'Anti Parasitic', 'MedRelief Labs', 'Antischistosomal tablets, 10x10 blister pack.', 1.85, 200],
['Artemether 80 mg/ml Injection', 'Anti Parasitic', 'Wellcura Pharma', 'Antimalarial injection, 6x1 ml ampoules per pack.', 2.30, 200],
['Hydroxychloroquine 200 mg Tablets', 'Anti Parasitic', 'BioCure Labs', 'Antimalarial / antirheumatic tablets, 10x10 pack.', 1.30, 200],
// --- Anti Diabetic (top-up) ---
['Metformin 850 mg Tablets', 'Anti Diabetic', 'GlucoCare Pharma', 'Biguanide tablets, 10x10 export pack.', 1.00, 500],
['Glimepiride 2 mg Tablets', 'Anti Diabetic', 'GlucoCare Pharma', 'Sulfonylurea tablets, 10x10 blister pack.', 1.15, 300],
['Sitagliptin 50 mg Tablets', 'Anti Diabetic', 'GlucoCare Pharma', 'DPP-4 inhibitor tablets, 10x10 pack.', 2.70, 100],
['Dapagliflozin 10 mg Tablets', 'Anti Diabetic', 'GlucoCare Pharma', 'SGLT2 inhibitor tablets, 3x10 export pack.', 3.10, 100],
['Empagliflozin 25 mg Tablets', 'Anti Diabetic', 'GlucoCare Pharma', 'SGLT2 inhibitor tablets, 3x10 export pack.', 3.30, 100],
['Insulin Glargine 100 IU/ml Pen', 'Anti Diabetic', 'GlucoCare Pharma', 'Long-acting insulin pen, 3 ml, cold-chain shipped.', 9.80, 100],
// --- Skin Care (top-up) ---
['Tretinoin 0.025% Cream', 'Skin Care', 'DermaCare India', 'Retinoid cream, 30 g tubes, 48 per carton.', 1.90, 200],
['Hydroquinone 4% Cream', 'Skin Care', 'DermaCare India', 'Depigmenting cream, 30 g tubes, 48 per carton.', 2.20, 200],
['Isotretinoin 20 mg Capsules', 'Skin Care', 'Wellcura Pharma', 'Oral retinoid capsules — export under licence, 10x10 pack.', 2.40, 100],
['Azelaic Acid 15% Gel', 'Skin Care', 'DermaCare India', 'Acne/rosacea gel, 30 g tubes, 48 per carton.', 2.05, 200],
['Clotrimazole 1% Cream', 'Skin Care', 'DermaCare India', 'Antifungal cream, 20 g tubes, 96 per carton.', 0.85, 500],
['Salicylic Acid 2% Solution', 'Skin Care', 'DermaCare India', 'Keratolytic solution, 30 ml bottles, 48 per carton.', 1.15, 300],
// --- Womens Health (top-up) ---
['Clomiphene 50 mg Tablets', 'Womens Health', 'Wellcura Pharma', 'Ovulation-induction tablets, 10x10 export pack.', 1.60, 200],
['Letrozole 2.5 mg Tablets', 'Womens Health', 'Wellcura Pharma', 'Aromatase-inhibitor tablets, 10x10 pack.', 1.75, 200],
['Levonorgestrel 1.5 mg Tablets', 'Womens Health', 'MedRelief Labs', 'Emergency contraceptive tablets, 1-tab packs, 100 per box.', 0.75, 500],
['Medroxyprogesterone 150 mg/ml Injection', 'Womens Health', 'Wellcura Pharma', 'Contraceptive injection, 1 ml vial, pack of 10.', 1.90, 200],
['Estradiol Valerate 2 mg Tablets', 'Womens Health', 'MedRelief Labs', 'HRT tablets, 10x10 export pack.', 1.30, 200],
['Folic Acid 5 mg Tablets', 'Womens Health', 'Nutriva Labs', 'Prenatal support tablets, 10x10 blister pack.', 0.55, 1000],
// --- Weight Loss (top-up) ---
['Orlistat 120 mg Capsules', 'Weight Loss', 'Nutriva Labs', 'Lipase-inhibitor capsules, 3x10 export pack.', 2.30, 200],
['Cetilistat 120 mg Capsules', 'Weight Loss', 'Nutriva Labs', 'Next-gen lipase inhibitor, 3x10 blister pack.', 2.60, 100],
['L-Carnitine 500 mg Tablets', 'Weight Loss', 'Nutriva Labs', 'Metabolism-support tablets, 10x10 pack.', 1.20, 300],
['Garcinia Cambogia 60% HCA Capsules', 'Weight Loss', 'Nutriva Labs', 'Herbal weight-management capsules, 10x10 pack.', 1.35, 300],
['Phentermine 37.5 mg Capsules', 'Weight Loss', 'Wellcura Pharma', 'Appetite suppressant — export under licence, 10x10 pack.', 2.10, 100],
['Liraglutide 3 mg Pen', 'Weight Loss', 'GlucoCare Pharma', 'GLP-1 weight-management pen, cold-chain shipped.', 42.00, 50],
['Green Coffee Extract 400 mg Capsules', 'Weight Loss', 'Nutriva Labs', 'Herbal extract capsules, 10x10 export pack.', 1.10, 300],
// --- Veterinary (top-up) ---
['Ivermectin 1% Injection (Veterinary)', 'Veterinary', 'AniCure Labs', 'Endectocide injection, 50 ml vials, 24 per carton.', 3.60, 100],
['Oxytetracycline 20% Injection (Veterinary)', 'Veterinary', 'AniCure Labs', 'Long-acting antibiotic injection, 100 ml vials.', 4.20, 100],
['Enrofloxacin 10% Oral Solution (Veterinary)', 'Veterinary', 'AniCure Labs', 'Antibiotic oral solution, 100 ml bottles.', 2.90, 100],
['Levamisole 7.5% Bolus (Veterinary)', 'Veterinary', 'AniCure Labs', 'Anthelmintic bolus, jar of 100.', 3.10, 100],
['Meloxicam 15 mg Tablets (Veterinary)', 'Veterinary', 'AniCure Labs', 'NSAID for dogs, 10x10 export pack.', 1.40, 200],
['Cypermethrin 10% Pour-On (Veterinary)', 'Veterinary', 'AniCure Labs', 'Tick-control pour-on, 1 L bottles.', 5.80, 60],
['Vitamin AD3E Injection (Veterinary)', 'Veterinary', 'AniCure Labs', 'Vitamin supplement injection, 100 ml vials.', 2.60, 100],
// --- Wakefulness (top-up) ---
['Modafinil 200 mg Tablets', 'Wakefulness', 'NeuroCure Pharma', 'Wakefulness-promoting tablets — export under licence, 10x10 pack.', 1.90, 200],
['Modafinil 100 mg Tablets', 'Wakefulness', 'NeuroCure Pharma', 'Wakefulness-promoting tablets, 10x10 export pack.', 1.35, 200],
['Armodafinil 150 mg Tablets', 'Wakefulness', 'NeuroCure Pharma', 'R-enantiomer wakefulness tablets, 10x10 pack.', 2.20, 100],
['Armodafinil 50 mg Tablets', 'Wakefulness', 'NeuroCure Pharma', 'Low-dose wakefulness tablets, 10x10 pack.', 1.40, 100],
['Methylphenidate 10 mg Tablets', 'Wakefulness', 'NeuroCure Pharma', 'CNS stimulant — export under licence, 10x10 pack.', 1.60, 100],
['Adrafinil 300 mg Capsules', 'Wakefulness', 'NeuroCure Pharma', 'Eugeroic capsules, 10x10 export pack.', 2.40, 100],
// --- Anti Cancer (new category) ---
['Imatinib 400 mg Tablets', 'Anti Cancer', 'OncoCure Pharma', 'Tyrosine-kinase inhibitor tablets, 3x10 export pack.', 18.50, 50],
['Gefitinib 250 mg Tablets', 'Anti Cancer', 'OncoCure Pharma', 'EGFR-inhibitor tablets, 3x10 blister pack.', 14.20, 50],
['Capecitabine 500 mg Tablets', 'Anti Cancer', 'OncoCure Pharma', 'Oral chemotherapy tablets, 10x10 export pack.', 6.80, 50],
['Anastrozole 1 mg Tablets', 'Anti Cancer', 'Wellcura Pharma', 'Aromatase-inhibitor tablets, 10x10 pack.', 1.45, 200],
['Tamoxifen 20 mg Tablets', 'Anti Cancer', 'Wellcura Pharma', 'SERM tablets, 10x10 export pack.', 1.35, 200],
['Methotrexate 2.5 mg Tablets', 'Anti Cancer', 'OncoCure Pharma', 'Antimetabolite tablets — export under licence, 10x10 pack.', 1.10, 100],
['Paclitaxel 300 mg Injection', 'Anti Cancer', 'OncoCure Pharma', 'Concentrate for infusion, single vial, cold-chain.', 38.00, 25],
['Cyclophosphamide 500 mg Injection', 'Anti Cancer', 'OncoCure Pharma', 'Alkylating-agent injection, vial of 1.', 4.90, 50],
// --- Ayurvedic (new category) ---
['Ashwagandha 500 mg Capsules', 'Ayurvedic', 'VedaLife Herbals', 'KSM-grade root extract capsules, 10x10 pack.', 1.60, 300],
['Triphala 500 mg Tablets', 'Ayurvedic', 'VedaLife Herbals', 'Classical three-fruit formulation, 10x10 pack.', 1.20, 500],
['Brahmi 300 mg Capsules', 'Ayurvedic', 'VedaLife Herbals', 'Cognitive-support herb capsules, 10x10 pack.', 1.45, 300],
['Chyawanprash 500 g Jar', 'Ayurvedic', 'VedaLife Herbals', 'Classical rasayana jam, 24 jars per carton.', 4.20, 100],
['Neem 500 mg Capsules', 'Ayurvedic', 'VedaLife Herbals', 'Purifying herb capsules, 10x10 export pack.', 1.25, 300],
['Turmeric Curcumin 500 mg Capsules', 'Ayurvedic', 'VedaLife Herbals', '95% curcuminoid capsules, 10x10 pack.', 1.55, 300],
['Giloy 500 mg Tablets', 'Ayurvedic', 'VedaLife Herbals', 'Immunity-support tablets, 10x10 blister pack.', 1.15, 300],
['Shatavari 500 mg Capsules', 'Ayurvedic', 'VedaLife Herbals', 'Womens-wellness herb capsules, 10x10 pack.', 1.50, 300],
// --- Contraceptives (new category) ---
['Combined Oral Contraceptive Tablets', 'Contraceptives', 'Wellcura Pharma', 'Levonorgestrel + ethinylestradiol, 28-tab cycle packs.', 0.95, 500],
['Desogestrel 75 mcg Tablets', 'Contraceptives', 'Wellcura Pharma', 'Progestogen-only pills, 28-tab cycle packs.', 1.10, 500],
['Norethisterone 5 mg Tablets', 'Contraceptives', 'MedRelief Labs', 'Progestogen tablets, 10x10 export pack.', 1.05, 300],
['Etonogestrel Implant 68 mg', 'Contraceptives', 'Wellcura Pharma', 'Subdermal rod, single sterile applicator.', 6.50, 100],
['Copper IUD 380A', 'Contraceptives', 'Wellcura Pharma', 'T-shaped IUD with inserter, sterile single pack.', 2.80, 200],
['Levonorgestrel Intrauterine System 52 mg', 'Contraceptives', 'Wellcura Pharma', 'Hormonal IUS, sterile single pack.', 9.20, 100],
// --- Drops & Syrups (new category) ---
['Paracetamol Syrup 125 mg/5 ml', 'Drops & Syrups', 'Wellcura Pharma', 'Paediatric analgesic syrup, 60 ml bottles, 48 per carton.', 0.75, 500],
['Cetirizine Syrup 5 mg/5 ml', 'Drops & Syrups', 'Wellcura Pharma', 'Antihistamine syrup, 60 ml bottles, 48 per carton.', 0.85, 500],
['Ibuprofen Suspension 100 mg/5 ml', 'Drops & Syrups', 'MedRelief Labs', 'Paediatric NSAID suspension, 60 ml bottles.', 0.95, 500],
['Multivitamin Syrup 200 ml', 'Drops & Syrups', 'Nutriva Labs', 'Daily multivitamin syrup, 48 bottles per carton.', 1.35, 300],
['Dextromethorphan Cough Syrup 100 ml', 'Drops & Syrups', 'MedRelief Labs', 'Antitussive syrup, 48 bottles per carton.', 1.15, 300],
['ORS Sachets (WHO Formula)', 'Drops & Syrups', 'Wellcura Pharma', 'Oral rehydration salts, 20.5 g sachets, 100 per box.', 0.30, 2000],
['Iron + Folic Acid Drops', 'Drops & Syrups', 'Nutriva Labs', 'Paediatric haematinic drops, 30 ml bottles.', 0.90, 500],
['Moxifloxacin 0.5% Eye Drops', 'Drops & Syrups', 'DermaCare India', 'Sterile ophthalmic solution, 5 ml bottles.', 1.25, 300],
// --- HCG & HGH (new category) ---
['HCG 5000 IU Injection', 'HCG & HGH', 'AndroTech Labs', 'Human chorionic gonadotropin, vial + solvent, pack of 1.', 5.40, 100],
['HCG 10000 IU Injection', 'HCG & HGH', 'AndroTech Labs', 'Human chorionic gonadotropin, vial + solvent, pack of 1.', 8.20, 100],
['HMG 75 IU Injection', 'HCG & HGH', 'AndroTech Labs', 'Menotropin injection, vial + solvent.', 7.60, 100],
['Somatropin 4 IU Injection', 'HCG & HGH', 'GlucoCare Pharma', 'Recombinant growth hormone, vial, cold-chain shipped.', 12.50, 50],
['Somatropin 10 IU Injection', 'HCG & HGH', 'GlucoCare Pharma', 'Recombinant growth hormone, vial, cold-chain shipped.', 26.00, 50],
// --- Health Supplements (new category) ---
['Vitamin C 1000 mg Effervescent Tablets', 'Health Supplements', 'Nutriva Labs', 'Effervescent tablets, 4x15 tube packs.', 1.30, 500],
['Omega-3 Fish Oil 1000 mg Softgels', 'Health Supplements', 'Nutriva Labs', 'EPA/DHA softgels, 10x10 export pack.', 1.65, 300],
['Zinc 50 mg Tablets', 'Health Supplements', 'Nutriva Labs', 'Immunity-support tablets, 10x10 pack.', 0.75, 1000],
['Coenzyme Q10 100 mg Capsules', 'Health Supplements', 'Nutriva Labs', 'Cellular-energy capsules, 10x10 pack.', 2.20, 200],
['Calcium + Vitamin D3 Tablets', 'Health Supplements', 'Nutriva Labs', 'Bone-health tablets, 10x15 export pack.', 1.25, 300],
['Probiotic 10 Billion CFU Capsules', 'Health Supplements', 'Nutriva Labs', 'Multi-strain probiotic capsules, 10x10 pack.', 2.10, 200],
['Whey Protein 1 kg Jar', 'Health Supplements', 'Nutriva Labs', 'Chocolate-flavoured protein powder, 12 jars per carton.', 14.50, 60],
['Collagen Peptides 200 g Jar', 'Health Supplements', 'Nutriva Labs', 'Hydrolysed type-I collagen, 12 jars per carton.', 9.80, 60],
// --- Mens Health (new category) ---
['Finasteride 5 mg Tablets', 'Mens Health', 'Wellcura Pharma', 'BPH-management tablets, 10x10 export pack.', 1.45, 300],
['Tamsulosin 0.4 mg Capsules', 'Mens Health', 'Wellcura Pharma', 'Alpha-blocker capsules, 10x10 blister pack.', 1.30, 300],
['Dutasteride 0.5 mg Capsules', 'Mens Health', 'Wellcura Pharma', '5-alpha-reductase inhibitor, 10x10 pack.', 1.70, 200],
['Testosterone Undecanoate 40 mg Capsules', 'Mens Health', 'AndroTech Labs', 'Oral TRT capsules — export under licence, 3x10 pack.', 2.90, 100],
['Alfuzosin 10 mg Tablets', 'Mens Health', 'MedRelief Labs', 'Alpha-blocker tablets, 10x10 export pack.', 1.35, 200],
['Sildenafil + Tadalafil Combo Kit', 'Mens Health', 'VitaCore Pharma', 'Physician-directed combo kit, 4+4 tablet wallet.', 2.40, 200],
// --- Pharmaceutical Tablets (new category) ---
['Paracetamol 650 mg Tablets', 'Pharmaceutical Tablets', 'Wellcura Pharma', 'Analgesic/antipyretic tablets, 20x10 export pack.', 0.55, 1000],
['Ibuprofen 400 mg Tablets', 'Pharmaceutical Tablets', 'MedRelief Labs', 'NSAID tablets, 20x10 export pack.', 0.70, 1000],
['Pantoprazole 40 mg Tablets', 'Pharmaceutical Tablets', 'Wellcura Pharma', 'PPI tablets, 10x10 alu-alu pack.', 1.05, 500],
['Omeprazole 20 mg Capsules', 'Pharmaceutical Tablets', 'Wellcura Pharma', 'PPI capsules, 10x10 export pack.', 0.85, 500],
['Famotidine 40 mg Tablets', 'Pharmaceutical Tablets', 'MedRelief Labs', 'H2-blocker tablets, 10x10 pack.', 0.75, 500],
['Montelukast 10 mg Tablets', 'Pharmaceutical Tablets', 'BioCure Labs', 'Leukotriene-antagonist tablets, 10x10 pack.', 1.20, 300],
['Amlodipine 5 mg Tablets', 'Pharmaceutical Tablets', 'CardioCure Pharma', 'Calcium-channel blocker tablets, 10x10 pack.', 0.65, 1000],
['Atorvastatin 10 mg Tablets', 'Pharmaceutical Tablets', 'CardioCure Pharma', 'Statin tablets, 10x10 export pack.', 0.95, 500],
// --- PrEP (new category) ---
['Tenofovir DF + Emtricitabine Tablets', 'PrEP', 'ImmunoCure Pharma', 'Fixed-dose PrEP combination, 3x10 export pack.', 6.40, 100],
['Tenofovir Alafenamide + Emtricitabine Tablets', 'PrEP', 'ImmunoCure Pharma', 'Second-generation PrEP combination, 30-tab bottle.', 9.80, 100],
['Dolutegravir 50 mg Tablets', 'PrEP', 'ImmunoCure Pharma', 'Integrase-inhibitor tablets, 10x10 pack.', 3.90, 100],
['Efavirenz 600 mg Tablets', 'PrEP', 'ImmunoCure Pharma', 'NNRTI tablets, 30-tab bottle.', 3.20, 100],
// --- Heart & BP (new category) ---
['Telmisartan 40 mg Tablets', 'Heart & BP', 'CardioCure Pharma', 'ARB tablets, 10x10 export pack.', 1.05, 500],
['Losartan 50 mg Tablets', 'Heart & BP', 'CardioCure Pharma', 'ARB tablets, 10x10 blister pack.', 0.85, 500],
['Hydrochlorothiazide 25 mg Tablets', 'Heart & BP', 'CardioCure Pharma', 'Thiazide diuretic tablets, 10x10 pack.', 0.60, 1000],
['Metoprolol 50 mg Tablets', 'Heart & BP', 'CardioCure Pharma', 'Beta-blocker tablets, 10x10 export pack.', 0.85, 500],
['Rosuvastatin 10 mg Tablets', 'Heart & BP', 'CardioCure Pharma', 'Statin tablets, 10x10 blister pack.', 1.15, 500],
['Clopidogrel 75 mg Tablets', 'Heart & BP', 'CardioCure Pharma', 'Antiplatelet tablets, 10x10 export pack.', 1.10, 500],
['Furosemide 40 mg Tablets', 'Heart & BP', 'CardioCure Pharma', 'Loop-diuretic tablets, 10x10 pack.', 0.60, 1000],
['Enalapril 10 mg Tablets', 'Heart & BP', 'CardioCure Pharma', 'ACE-inhibitor tablets, 10x10 pack.', 0.70, 500],
];

async function main() {
  console.log('[seed] fetching existing catalogue ...');
  const existing = await rest('GET', 'products?select=id,name,category');
  console.log(`[seed] found ${existing.length} existing products`);

  // 1. Normalize category names (single pass — idempotent on re-run).
  let renamed = 0;
  for (const row of existing) {
    const target = RENAMES[row.category];
    if (target) {
      await rest('PATCH', `products?id=eq.${row.id}`, { category: target });
      renamed++;
      row.category = target;
    }
  }
  console.log(`[seed] renamed ${renamed} rows to canonical category names`);

  // 2. Insert new products whose names are not already present.
  const have = new Set(existing.map((p) => p.name.trim().toLowerCase()));
  const fresh = PRODUCTS.filter(([name]) => !have.has(name.trim().toLowerCase()));
  console.log(`[seed] ${fresh.length} of ${PRODUCTS.length} staged products are new`);

  for (let i = 0; i < fresh.length; i += 50) {
    const chunk = fresh.slice(i, i + 50).map(([name, category, manufacturer, description, price, moq]) => ({
      name,
      category,
      manufacturer,
      description,
      price,
      currency: 'USD',
      min_order_qty: moq,
      is_active: true,
    }));
    await rest('POST', 'products', chunk);
    console.log(`[seed] inserted rows ${i + 1}..${Math.min(i + 50, fresh.length)}`);
  }

  // 3. Final per-category summary.
  const after = await rest('GET', 'products?select=category&is_active=eq.true');
  const counts = {};
  for (const row of after) counts[row.category] = (counts[row.category] || 0) + 1;
  console.log('[seed] active catalogue by category:');
  for (const [cat, n] of Object.entries(counts).sort((a, b) => b[1] - a[1])) {
    console.log(`   ${cat.padEnd(26)} ${n}`);
  }
  console.log(`[seed] DONE — ${after.length} active products across ${Object.keys(counts).length} categories`);
}

main().catch((err) => {
  console.error('[seed] FAILED:', err.message);
  process.exit(1);
});
