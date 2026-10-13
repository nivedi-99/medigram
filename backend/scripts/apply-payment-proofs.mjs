#!/usr/bin/env node
/**
 * apply-payment-proofs.mjs — one-shot provisioning for buyer payment proofs.
 *
 *   cd backend && node scripts/apply-payment-proofs.mjs
 *
 * Creates the public `payment-proofs` storage bucket (idempotent) that
 * POST /api/v1/uploads/payment-proof uploads buyer screenshots to.
 * For the full policy set see supabase/add_payment_proofs.sql (the SQL
 * Editor or a Postgres DATABASE_URL is required for RLS policies — the
 * storage API cannot manage policies by design; service-role uploads and
 * public buckets work without them).
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
  console.error('[apply-payment-proofs] SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY missing — set them in backend/.env');
  process.exit(2);
}

const admin = createClient(url, serviceKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const BUCKET = 'payment-proofs';
const { data: bucket } = await admin.storage.getBucket(BUCKET);
if (bucket) {
  if (!bucket.public) {
    const { error } = await admin.storage.updateBucket(BUCKET, { public: true });
    if (error) {
      console.error(`[apply-payment-proofs] could not make ${BUCKET} public: ${error.message}`);
      process.exit(1);
    }
    console.log(`[apply-payment-proofs] bucket "${BUCKET}" switched to public`);
  } else {
    console.log(`[apply-payment-proofs] bucket "${BUCKET}" already exists (public)`);
  }
} else {
  const { error } = await admin.storage.createBucket(BUCKET, { public: true });
  if (error) {
    console.error(`[apply-payment-proofs] could not create ${BUCKET}: ${error.message}`);
    console.error('           Run supabase/add_payment_proofs.sql in the SQL Editor instead.');
    process.exit(1);
  }
  console.log(`[apply-payment-proofs] bucket "${BUCKET}" created (public)`);
}

// Smoke: upload + remove a probe object to confirm service-role writes work.
const probePath = `probe/${Date.now()}.txt`;
const { error: upErr } = await admin.storage
  .from(BUCKET)
  .upload(probePath, Buffer.from('medigram probe'), { contentType: 'text/plain' });
if (upErr) {
  console.error(`[apply-payment-proofs] probe upload failed: ${upErr.message}`);
  process.exit(1);
}
await admin.storage.from(BUCKET).remove([probePath]);
console.log('[apply-payment-proofs] probe upload/delete OK — bucket is writable');
console.log('[apply-payment-proofs] ready to use');
