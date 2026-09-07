#!/usr/bin/env node
/**
 * apply-catalogue-v2.mjs — replaces the ACTIVE catalogue with the owner's
 * product list. Everything not in the list is soft-deactivated
 * (is_active=false — reversible from the admin console); listed products are
 * inserted if missing or updated/reactivated if present.
 *
 *   node scripts/apply-catalogue-v2.mjs
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

/** The owner's export list — the ONLY products shown in the catalogue. */
const LIST = [
  ['Cenforce 100', 'Erectile Dysfunction', 'Sildenafil Citrate 100 mg film-coated tablets, 10x10 export pack.', 1.20, 100],
  ['Cenforce 200', 'Erectile Dysfunction', 'Sildenafil Citrate 200 mg film-coated tablets, 10x10 export pack.', 1.80, 100],
  ['Vidalista 20', 'Erectile Dysfunction', 'Tadalafil 20 mg film-coated tablets, 10x10 export pack.', 1.40, 100],
  ['Vidalista 80', 'Erectile Dysfunction', 'Tadalafil 80 mg film-coated tablets, 10x10 export pack.', 2.60, 100],
  ['Abortion Kit', 'Womens Health', 'Mifepristone 200 mg + Misoprostol 200 mcg medical termination kit.', 28.00, 50],
  ['Tapaday 100', 'Pain Killers', 'Tapentadol 100 mg extended-release tablets, 10x10 export pack.', 1.90, 100],
  ['Tapaday 200', 'Pain Killers', 'Tapentadol 200 mg extended-release tablets, 10x10 export pack.', 2.50, 100],
  ['Modvigil 200', 'Wakefulness', 'Modafinil 200 mg tablets, 10x10 export pack.', 1.95, 100],
];

async function main() {
  console.log('[catalogue] fetching products ...');
  const all = await rest('GET', 'products?select=id,name,is_active');
  console.log(`[catalogue] ${all.length} rows in table`);

  const byName = new Map(all.map((p) => [p.name.trim().toLowerCase(), p]));
  const allowed = new Set(LIST.map(([n]) => n.trim().toLowerCase()));

  // 1. Deactivate everything NOT on the list.
  const toHide = all.filter((p) => p.is_active && !allowed.has(p.name.trim().toLowerCase()));
  for (let i = 0; i < toHide.length; i += 100) {
    const ids = toHide.slice(i, i + 100).map((p) => p.id);
    await rest('PATCH', `products?id=in.(${ids.join(',')})`, { is_active: false });
    console.log(`[catalogue] deactivated rows ${i + 1}..${Math.min(i + 100, toHide.length)}`);
  }
  console.log(`[catalogue] deactivated ${toHide.length} products outside the list`);

  // 2. Upsert the listed products (insert or reactivate + refresh fields).
  let inserted = 0;
  let updated = 0;
  for (const [name, category, description, price, moq] of LIST) {
    const existing = byName.get(name.trim().toLowerCase());
    if (existing) {
      await rest('PATCH', `products?id=eq.${existing.id}`, {
        category,
        description,
        price,
        currency: 'USD',
        min_order_qty: moq,
        is_active: true,
      });
      updated++;
    } else {
      await rest('POST', 'products', {
        name,
        category,
        description,
        price,
        currency: 'USD',
        min_order_qty: moq,
        is_active: true,
      });
      inserted++;
    }
  }
  console.log(`[catalogue] inserted ${inserted}, refreshed ${updated} listed products`);

  // 3. Final state.
  const active = await rest('GET', 'products?select=name,category,price,min_order_qty&is_active=eq.true&order=name');
  console.log(`[catalogue] ACTIVE CATALOGUE (${active.length}):`);
  for (const p of active) {
    console.log(`   ${p.name.padEnd(24)} ${p.category.padEnd(24)} $${p.price}  MOQ ${p.min_order_qty}`);
  }
}

main().catch((err) => {
  console.error('[catalogue] FAILED:', err.message);
  process.exit(1);
});