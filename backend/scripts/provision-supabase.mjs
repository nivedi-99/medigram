#!/usr/bin/env node
/**
 * provision-supabase.mjs — creates the MediGram Supabase project from scratch
 * and rewrites all local credential files. Requires a personal access token.
 *
 *   node scripts/provision-supabase.mjs <sbp_token> [--region ap-south-1]
 *
 * Steps:
 *   1. Lists your organizations (uses the first, or --org <id>)
 *   2. Lists existing projects (shows any old/paused ones)
 *   3. Generates a strong database password
 *   4. Creates project 'medigram' via the Management API
 *   5. Polls until the project status is ACTIVE
 *   6. Fetches the anon + service_role keys
 *   7. Rewrites supabase/server.env and backend/.env (incl. DATABASE_URL)
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
const getOpt = (name) => {
  const i = args.indexOf(`--${name}`);
  if (i === -1) return null;
  const inline = args[i].split('=')[1];
  return inline ?? args[i + 1] ?? null;
};
const region = getOpt('region') ?? 'ap-south-1';
const orgId = getOpt('org');

if (!token) {
  console.error('Usage: node scripts/provision-supabase.mjs <sbp_token> [--region ap-south-1] [--org <org_id>]');
  process.exit(2);
}

const headers = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
const call = async (method, url, body) => {
  const res = await fetch(url, { method, headers, body: body ? JSON.stringify(body) : undefined });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch { /* non-json */ }
  if (!res.ok) throw new Error(`${method} ${url} -> HTTP ${res.status}: ${text.slice(0, 400)}`);
  return json;
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// --- 1. organizations -------------------------------------------------------
const orgs = await call('GET', `${API}/organizations`);
if (!orgs?.length) throw new Error('No organizations on this account — create one at supabase.com/dashboard first.');
console.log('[provision] organizations:');
for (const o of orgs) console.log(`  - ${o.name} (${o.id})`);
const org = orgId ? orgs.find((o) => o.id === orgId) : orgs[0];
if (!org) throw new Error(`Organization ${orgId} not found.`);
console.log(`[provision] using organization: ${org.name}`);

// --- 2. existing projects ----------------------------------------------------
const projects = await call('GET', `${API}/projects`);
console.log(`[provision] existing projects: ${projects.length}`);
for (const p of projects) console.log(`  - ${p.name} (${p.id}) status=${p.status}`);

// --- 3. database password ----------------------------------------------------
const dbPass = crypto.randomBytes(18).toString('base64url');
console.log('[provision] generated database password (stored into env files)');

// --- 4. create project -------------------------------------------------------
console.log(`[provision] creating project 'medigram' in region ${region} (free plan)...`);
let project;
try {
  project = await call('POST', `${API}/projects`, {
    name: 'medigram',
    organization_id: org.id,
    db_pass: dbPass,
    region,
    plan: 'free',
  });
} catch (err) {
  console.error(`[provision] FAILED: ${err.message}`);
  console.error('Hint: free tier allows max 2 projects — delete an unused one,');
  console.error('or pass --region (us-east-1, eu-central-1, ap-south-1, ap-southeast-1...).');
  process.exit(1);
}
const ref = project.id;
console.log(`[provision] project created: ref=${ref} (status=${project.status})`);
// __PROVISION_PART2__

// --- 5. wait until ACTIVE ------------------------------------------------------
const isActive = (s) => typeof s === 'string' && s.startsWith('ACTIVE');
let status = project.status;
for (let i = 0; i < 60 && !isActive(status); i += 1) {
  await sleep(10_000);
  const p = await call('GET', `${API}/projects/${ref}`);
  status = p.status;
  process.stdout.write(`\r[provision] waiting for ACTIVE (status=${status}, ${(i + 1) * 10}s)   `);
}
console.log('');
if (!isActive(status)) throw new Error(`Project still ${status} after 10 minutes — check the dashboard.`);

const supabaseUrl = `https://${ref}.supabase.co`;

// --- 6. API keys ---------------------------------------------------------------
let keys;
try {
  keys = await call('GET', `${API}/projects/${ref}/api-keys?reveal=true`);
} catch {
  keys = await call('GET', `${API}/projects/${ref}/api-keys`);
}
const anonKey = keys.find((k) => k.name === 'anon')?.api_key;
const serviceKey = keys.find((k) => k.name === 'service_role')?.api_key;
if (!anonKey || !serviceKey) {
  console.error('[provision] could not fetch API keys automatically.');
  console.error(`Copy them from: supabase.com/dashboard/project/${ref}/settings/api`);
  process.exit(1);
}
console.log('[provision] fetched anon + service_role keys');

// --- 7. rewrite credential files -------------------------------------------------
const serverEnv = `# SERVER-ONLY CREDENTIALS (git-ignored)\nSUPABASE_URL=${supabaseUrl}\nSUPABASE_ANON_KEY=${anonKey}\nSUPABASE_SERVICE_ROLE_KEY=${serviceKey}\n`;
writeFileSync(path.join(root, 'supabase', 'server.env'), serverEnv);

const directDb = `postgresql://postgres:${encodeURIComponent(dbPass)}@db.${ref}.supabase.co:5432/postgres`;
const envPath = path.join(backend, '.env');
let envBody = existsSync(envPath) ? readFileSync(envPath, 'utf8') : '';
envBody = envBody
  .replace(/^SUPABASE_URL=.*$/m, `SUPABASE_URL=${supabaseUrl}`)
  .replace(/^SUPABASE_ANON_KEY=.*$/m, `SUPABASE_ANON_KEY=${anonKey}`)
  .replace(/^SUPABASE_SERVICE_ROLE_KEY=.*$/m, `SUPABASE_SERVICE_ROLE_KEY=${serviceKey}`);
if (/^DATABASE_URL=/m.test(envBody)) {
  envBody = envBody.replace(/^DATABASE_URL=.*$/m, `DATABASE_URL=${directDb}`);
} else {
  envBody += `\nDATABASE_URL=${directDb}\n`;
}
if (!envBody.endsWith('\n')) envBody += '\n';
writeFileSync(envPath, envBody);

console.log('');
console.log('================ PROVISIONED ================');
console.log(`Project ref : ${ref}`);
console.log(`Project URL : ${supabaseUrl}`);
console.log(`Region      : ${region}`);
console.log('Files updated: supabase/server.env, backend/.env');
console.log('Next        : npm run gates');
console.log('=============================================');
