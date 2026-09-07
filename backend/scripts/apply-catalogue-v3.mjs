#!/usr/bin/env node
/**
 * apply-catalogue-v3.mjs — rebuilds the ACTIVE catalogue as 13 categories
 * flowing Generic -> brand names with strengths.
 *
 * Structure: category -> generic (stored in `manufacturer`) -> brand entries
 * (name = brand + strength). Everything outside this list is soft-deactivated
 * (is_active=false, reversible in admin). Idempotent by product name.
 *
 *   node scripts/apply-catalogue-v3.mjs
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
  console.error('[catalogue] missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY in backend/.env');
  process.exit(2);
}

const HEADERS = {
  apikey: KEY,
  Authorization: `Bearer ${KEY}`,
  'Content-Type': 'application/json',
  Prefer: 'return=minimal',
};

async function rest(method, urlPath, body) {
  const res = await fetch(`${BASE}/rest/v1/${urlPath}`, {
    method,
    headers: HEADERS,
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

/**
 * 13 categories. Within each: generic molecule -> brand entries
 * [name, priceUSD, moq]. The generic is stored in `manufacturer`.
 */
const CATALOGUE = {
  'Erectile Dysfunction': {
    'Sildenafil Citrate': [
      ['Cenforce 100', 1.20, 100],
      ['Cenforce 200', 1.80, 100],
      ['Fildena 100', 1.30, 100],
      ['Kamagra 100', 1.10, 200],
    ],
    'Tadalafil': [
      ['Vidalista 20', 1.40, 100],
      ['Vidalista 80', 2.60, 100],
      ['Tadalista 20', 1.35, 100],
      ['Tadacip 20', 1.30, 100],
    ],
    'Vardenafil': [
      ['Vilitra 20', 1.45, 100],
      ['Snovitra 20', 1.50, 100],
    ],
    'Avanafil': [
      ['Avana 100', 1.85, 100],
      ['Avana 50', 1.40, 100],
    ],
  },
  'Pain Killers': {
    'Tapentadol': [
      ['Tapaday 100', 1.90, 100],
      ['Tapaday 200', 2.50, 100],
      ['Aspadol 100', 1.85, 100],
      ['Aspadol 150', 2.20, 100],
    ],
    'Etoricoxib': [
      ['Etoshine 90', 1.10, 200],
      ['Nucoxia 90', 1.15, 200],
    ],
    'Aceclofenac': [
      ['Zerodol 100', 0.75, 300],
    ],
    'Diclofenac': [
      ['Voveran 50', 0.65, 300],
    ],
  },
  'Anti Parasitic': {
    'Ivermectin': [
      ['Iverjohn 12', 1.20, 100],
      ['Iverheal 12', 1.15, 100],
      ['Iverheal 6', 0.85, 100],
      ['Iverfast 12', 1.18, 100],
    ],
    'Albendazole': [
      ['Zentel 400', 0.75, 500],
      ['Bandy 400', 0.70, 500],
    ],
    'Hydroxychloroquine': [
      ['HCQS 200', 1.05, 200],
      ['HCQS 400', 1.35, 200],
    ],
    'Praziquantel': [
      ['Pyquil 600', 1.80, 200],
    ],
  },
  'Antibiotics': {
    'Azithromycin': [
      ['Azithral 500', 1.85, 200],
      ['Azee 500', 1.80, 200],
      ['Zithromax 500', 2.10, 100],
    ],
    'Amoxicillin': [
      ['Mox 500', 1.20, 500],
      ['Novamox 500', 1.25, 500],
    ],
    'Cefixime': [
      ['Taxim-O 200', 2.05, 200],
      ['Zifi 200', 2.00, 200],
    ],
    'Doxycycline': [
      ['Doxt-SL', 0.95, 500],
      ['Doxy-1 L-DR', 1.00, 500],
    ],
    'Levofloxacin': [
      ['Levoflox 500', 1.70, 200],
      ['Levofloxacin 500', 1.75, 200],
    ],
  },
  'Steroids': {
    'Testosterone Enanthate': [
      ['Testoviron Depot 250', 3.20, 100],
      ['Sustanon 250', 3.60, 100],
    ],
    'Nandrolone Decanoate': [
      ['Deca-Durabolin 250', 3.40, 100],
      ['Nandrobolin 250', 3.10, 100],
    ],
    'Stanozolol': [
      ['Winstrol 10', 1.55, 200],
      ['Rexogin 50', 2.40, 100],
    ],
    'Oxandrolone': [
      ['Anavar 10', 2.60, 100],
      ['Oxanabol 10', 2.50, 100],
    ],
    'Methandienone': [
      ['Dianabol 10', 1.20, 200],
      ['Anabol 5', 0.85, 200],
    ],
    'Boldenone Undecylenate': [
      ['Equipoise 250', 3.30, 100],
    ],
  },
  'Anti-Anxiety': {
    'Alprazolam': [
      ['Alprax 0.5', 0.90, 200],
      ['Restyl 0.5', 0.92, 200],
    ],
    'Escitalopram': [
      ['Nexito 10', 1.25, 200],
      ['Cipralex 10', 1.60, 100],
    ],
    'Sertraline': [
      ['Zoloft 50', 1.55, 100],
      ['Serta 50', 1.15, 200],
    ],
    'Clonazepam': [
      ['Rivotril 2', 1.05, 200],
      ['Klonopin 2', 1.20, 100],
    ],
    'Buspirone': [
      ['Buspin 10', 1.05, 200],
    ],
  },
  'Sleeping Pills': {
    'Zolpidem': [
      ['Zolfresh 10', 1.20, 200],
      ['Ambien 10', 1.45, 100],
    ],
    'Eszopiclone': [
      ['Lunesta 3', 1.70, 100],
    ],
    'Melatonin': [
      ['Meloset 10', 0.95, 500],
      ['Melatonin MT 10', 1.00, 500],
    ],
    'Suvorexant': [
      ['Belsomra 20', 2.95, 100],
    ],
    'Temazepam': [
      ['Restoril 15', 1.25, 100],
    ],
  },
  'Hair Care': {
    'Finasteride': [
      ['Finast 1', 1.35, 300],
      ['Finpecia 1', 1.28, 300],
    ],
    'Minoxidil': [
      ['Mintop 5%', 2.75, 200],
      ['Tugain 5%', 2.80, 200],
    ],
    'Biotin': [
      ['Biotin Forte', 1.00, 500],
    ],
    'Ketoconazole': [
      ['Nizral 2%', 1.85, 200],
      ['Ketomac Shampoo', 1.75, 200],
    ],
  },
  'Anti Diabetic': {
    'Metformin': [
      ['Glycomet 850', 0.95, 500],
      ['Glucophage 850', 1.05, 500],
    ],
    'Glimepiride': [
      ['Amaryl 2', 1.20, 300],
      ['Glimestar 2', 1.10, 300],
    ],
    'Sitagliptin': [
      ['Istavel 50', 2.65, 100],
      ['Januvia 50', 2.80, 100],
    ],
    'Dapagliflozin': [
      ['Forxiga 10', 3.05, 100],
      ['Farxiga 10', 3.15, 100],
    ],
    'Empagliflozin': [
      ['Jardiance 25', 3.30, 100],
    ],
    'Insulin Glargine': [
      ['Lantus SoloStar', 9.80, 50],
      ['Basalog One', 7.40, 50],
    ],
  },
  'Skin Care': {
    'Tretinoin': [
      ['Retin-A 0.025%', 1.90, 200],
      ['Retino-A 0.05%', 2.00, 200],
    ],
    'Hydroquinone': [
      ['Melalite Forte', 2.15, 200],
      ['Tri-Luma', 3.40, 100],
    ],
    'Isotretinoin': [
      ['Accutane 20', 2.45, 100],
      ['Sotret 20', 2.35, 100],
    ],
    'Azelaic Acid': [
      ['Azelex 15%', 2.00, 200],
      ['Aziderm 10%', 1.85, 200],
    ],
    'Clotrimazole': [
      ['Canesten 1%', 0.85, 500],
      ['Candid Cream', 0.82, 500],
    ],
  },
  'Womens Health': {
    'Clomiphene': [
      ['Clomid 50', 1.60, 200],
      ['Fertyl 50', 1.55, 200],
    ],
    'Letrozole': [
      ['Fempro 2.5', 1.70, 200],
      ['Letroz 2.5', 1.65, 200],
    ],
    'Mifepristone + Misoprostol': [
      ['Abortion Kit', 28.00, 50],
      ['Mifegest Kit', 26.50, 50],
    ],
    'Medroxyprogesterone': [
      ['Depo-Provera 150', 1.95, 200],
    ],
    'Estradiol Valerate': [
      ['Progynova 2', 1.30, 300],
    ],
  },
  'Weight Loss': {
    'Orlistat': [
      ['Orlijohn 120', 2.25, 200],
      ['Xenical 120', 2.85, 100],
    ],
    'Semaglutide': [
      ['Rybelsus 14', 38.00, 25],
    ],
    'Liraglutide': [
      ['Saxenda 3 mg', 42.00, 25],
    ],
    'Phentermine': [
      ['Adipex 37.5', 2.10, 100],
    ],
  },
  'Wakefulness': {
    'Modafinil': [
      ['Modvigil 200', 1.95, 100],
      ['Modalert 200', 2.05, 100],
      ['Vilafinil 200', 1.85, 100],
    ],
    'Armodafinil': [
      ['Waklert 150', 2.15, 100],
      ['Artvigil 150', 1.95, 100],
    ],
  },
};
async function main() {
  console.log('[catalogue] fetching products ...');
  const all = await rest('GET', 'products?select=id,name,manufacturer,is_active');
  console.log(`[catalogue] ${all.length} rows in table`);

  // Flatten the target structure.
  const targets = [];
  for (const [category, generics] of Object.entries(CATALOGUE)) {
    for (const [generic, brands] of Object.entries(generics)) {
      for (const [name, price, moq] of brands) {
        targets.push({
          name: name.trim(),
          category,
          manufacturer: generic,
          description:
            `${generic} — authentic export-grade pharmaceutical pack from `
              + 'Indian GMP manufacturing. Batch-verified before dispatch.',
          price,
          currency: 'USD',
          min_order_qty: moq,
          is_active: true,
        });
      }
    }
  }
  const categoryCount = Object.keys(CATALOGUE).length;
  const genericCount = Object.values(CATALOGUE)
      .reduce((n, g) => n + Object.keys(g).length, 0);
  console.log(
      `[catalogue] target: ${targets.length} products | `
        + `${categoryCount} categories | ${genericCount} generic molecules`);

  // 1. Deactivate everything not in the target list.
  const byName = new Map(all.map((p) => [p.name.trim().toLowerCase(), p]));
  const wanted = new Set(targets.map((t) => t.name.trim().toLowerCase()));
  const toHide = all.filter((p) => p.is_active && !wanted.has(p.name.trim().toLowerCase()));
  for (let i = 0; i < toHide.length; i += 100) {
    const ids = toHide.slice(i, i + 100).map((p) => p.id);
    await rest('PATCH', `products?id=in.(${ids.join(',')})`, { is_active: false });
  }
  console.log(`[catalogue] deactivated ${toHide.length} rows outside the new list`);

  // 2. Upsert targets by name.
  let inserted = 0;
  let updated = 0;
  for (const t of targets) {
    const existing = byName.get(t.name.toLowerCase());
    if (existing) {
      const { name, ...fields } = t;
      await rest('PATCH', `products?id=eq.${existing.id}`, fields);
      updated++;
    } else {
      await rest('POST', 'products', t);
      inserted++;
    }
  }
  console.log(`[catalogue] inserted ${inserted}, refreshed ${updated}`);

  // 3. Final per-category summary.
  const active = await rest(
      'GET', 'products?select=name,category,manufacturer,price&is_active=eq.true&order=name');
  const counts = {};
  for (const row of active) counts[row.category] = (counts[row.category] || 0) + 1;
  console.log(`[catalogue] ACTIVE (${active.length} products, ${Object.keys(counts).length} categories):`);
  for (const [cat, n] of Object.entries(counts).sort((a, b) => b[1] - a[1])) {
    console.log(`   ${cat.padEnd(24)} ${n}`);
  }
}

main().catch((err) => {
  console.error('[catalogue] FAILED:', err.message);
  process.exit(1);
});
