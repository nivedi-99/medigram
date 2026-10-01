#!/usr/bin/env node
/**
 * apply-product-images.mjs — one-shot provisioning for product photos.
 *
 *   cd backend && node scripts/apply-product-images.mjs
 *
 * 1. Creates the public `product-images` storage bucket (idempotent).
 * 2. Probes whether products.image_url exists and prints the exact SQL to
 *    run when it does not (the column itself needs the SQL Editor or a
 *    Postgres DATABASE_URL — the API cannot run DDL by design).
 */
import { createClient } from '@supabase/supabase-js';
import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));

function loadEnv() {
  const envPath = path.join(here, '..', '.env');
  if (!existsSync(envPath)) return {};
  const env = {};
  for (const line of readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
    if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
  return env;
}

const env = loadEnv();
const url = process.env.SUPABASE_URL ?? env.SUPABASE_URL;
const serviceKey =
  process.env.SUPABASE_SERVICE_ROLE_KEY ?? env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !serviceKey) {
  console.error('[apply-product-images] SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY missing — set them in backend/.env');
  process.exit(2);
}

const admin = createClient(url, serviceKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

// 1. Public storage bucket -------------------------------------------------
const BUCKET = 'product-images';
const { data: bucket } = await admin.storage.getBucket(BUCKET);
if (bucket) {
  if (!bucket.public) {
    const { error } = await admin.storage.updateBucket(BUCKET, { public: true });
    if (error) {
      console.error(`[apply-product-images] could not make ${BUCKET} public: ${error.message}`);
      process.exit(1);
    }
    console.log(`[apply-product-images] bucket "${BUCKET}" switched to public`);
  } else {
    console.log(`[apply-product-images] bucket "${BUCKET}" already exists (public)`);
  }
} else {
  const { error } = await admin.storage.createBucket(BUCKET, { public: true });
  if (error) {
    console.error(`[apply-product-images] could not create ${BUCKET}: ${error.message}`);
    console.error('           Run supabase/add_product_images.sql in the SQL Editor instead.');
    process.exit(1);
  }
  console.log(`[apply-product-images] bucket "${BUCKET}" created (public)`);
}

// 2. Probe products.image_url ---------------------------------------------
const { error: probeError } = await admin
  .from('products')
  .select('image_url')
  .limit(1);
if (!probeError) {
  console.log('[apply-product-images] products.image_url column exists — ready to use');
  process.exit(0);
}
if (!/image_url/i.test(probeError.message ?? '')) {
  console.error(`[apply-product-images] unexpected probe failure: ${probeError.message}`);
  process.exit(1);
}
console.log('[apply-product-images] products.image_url column is MISSING.');
console.log('  Apply the migration, either:');
console.log('   a) Supabase dashboard -> SQL Editor -> paste supabase/add_product_images.sql -> Run');
console.log('   b) backend/:  node scripts/run-sql.mjs ../supabase/add_product_images.sql');
console.log('  The API keeps accepting products without it (photos are dropped) until applied.');
