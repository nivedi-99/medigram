#!/usr/bin/env node
/**
 * finalize-project.mjs — completes provisioning of an ALREADY-CREATED project.
 *
 *   node scripts/finalize-project.mjs <sbp_token> <project_ref> [--region ap-south-1]
 *
 * 1. Resets the database password to a fresh known value (Management API)
 * 2. Fetches anon + service_role keys
 * 3. Rewrites supabase/server.env and backend/.env (URL, keys, DATABASE_URL
 *    via the IPv4 session pooler for Windows compatibility)
 */
import { writeFileSync, readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import crypto from 'node:crypto';

const API = 'https://api.supabase.com/v1';
const here = path.dirname(fileURLToPath(import.meta.url));
const backend = path.join(here, '..');
const root = path.join(backend, '..');

const args = process.argv.slice(2);
const token = args.find((a) => a.startsWith('sbp_'));
const ref = args.find((a) => /^[a-z]{20}$/.test(a));
const region = args.includes('--region') ? args[args.indexOf('--region') + 1] : 'ap-south-1';
if (!token || !ref) {
  console.error('Usage: node scripts/finalize-project.mjs <sbp_token> <project_ref> [--region ap-south-1]');
  process.exit(2);
}

const headers = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
const call = async (method, url, body) => {
  const res = await fetch(url, { method, headers, body: body ? JSON.stringify(body) : undefined });
  const text = await res.text();
  if (!res.ok) throw new Error(`${method} ${url} -> HTTP ${res.status}: ${text.slice(0, 300)}`);
  try { return JSON.parse(text); } catch { return text; }
};

// --- 1. reset database password (best-effort — optional) -------------------
const dbPass = crypto.randomBytes(18).toString('base64url');
let resetOk = false;
let poolerDb = null;
const attempts = [
  ['PUT', `${API}/projects/${ref}/database/password`],
  ['POST', `${API}/projects/${ref}/database/password`],
];
let lastErr = null;
for (const [method, url] of attempts) {
  try {
    await call(method, url, { password: dbPass });
    console.log(`[finalize] database password reset via ${method} ${url.split('/v1')[1]}`);
    resetOk = true;
    poolerDb = `postgresql://postgres.${ref}:${encodeURIComponent(dbPass)}@aws-0-${region}.pooler.supabase.com:5432/postgres`;
    break;
  } catch (e) { lastErr = e; }
}
if (!resetOk) {
  console.log('[finalize] DB password reset unavailable via API — skipping DATABASE_URL');
  console.log(`[finalize] (${lastErr?.message?.slice(0, 120)})`);
}

// --- 2. fetch API keys --------------------------------------------------------
let keys;
try {
  keys = await call('GET', `${API}/projects/${ref}/api-keys?reveal=true`);
} catch {
  keys = await call('GET', `${API}/projects/${ref}/api-keys`);
}
const anonKey = keys.find((k) => k.name === 'anon')?.api_key;
const serviceKey = keys.find((k) => k.name === 'service_role')?.api_key;
if (!anonKey || !serviceKey) {
  console.error('[finalize] failed to fetch API keys');
  process.exit(1);
}
console.log('[finalize] fetched anon + service_role keys');

// --- 3. write credential files -------------------------------------------------
const supabaseUrl = `https://${ref}.supabase.co`;
const serverEnv = `# SERVER-ONLY CREDENTIALS (git-ignored)\nSUPABASE_URL=${supabaseUrl}\nSUPABASE_ANON_KEY=${anonKey}\nSUPABASE_SERVICE_ROLE_KEY=${serviceKey}\n`;
writeFileSync(path.join(root, 'supabase', 'server.env'), serverEnv);

// Session pooler (only when password reset worked) — IPv4 reachable.
const envPath = path.join(backend, '.env');
let envBody = existsSync(envPath) ? readFileSync(envPath, 'utf8') : `PORT=4000\nNODE_ENV=development\nCORS_ORIGINS=http://localhost:3000\n`;
envBody = envBody
  .replace(/^SUPABASE_URL=.*$/m, `SUPABASE_URL=${supabaseUrl}`)
  .replace(/^SUPABASE_ANON_KEY=.*$/m, `SUPABASE_ANON_KEY=${anonKey}`)
  .replace(/^SUPABASE_SERVICE_ROLE_KEY=.*$/m, `SUPABASE_SERVICE_ROLE_KEY=${serviceKey}`);
if (poolerDb) {
  if (/^DATABASE_URL=/m.test(envBody)) {
    envBody = envBody.replace(/^DATABASE_URL=.*$/m, `DATABASE_URL=${poolerDb}`);
  } else {
    envBody += `DATABASE_URL=${poolerDb}\n`;
  }
} else if (/^DATABASE_URL=/m.test(envBody)) {
  envBody = envBody.replace(/^DATABASE_URL=.*$/m, '# DATABASE_URL not set (password reset unavailable)');
}
if (!envBody.endsWith('\n')) envBody += '\n';
writeFileSync(envPath, envBody);

console.log('');
console.log('================ FINALIZED ================');
console.log(`Project ref : ${ref}`);
console.log(`Project URL : ${supabaseUrl}`);
console.log('Files updated: supabase/server.env, backend/.env');
console.log('Next        : npm run gates');
console.log('===========================================');
