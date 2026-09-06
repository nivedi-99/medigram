#!/usr/bin/env node
/**
 * sql-via-api.mjs — executes a .sql file against a Supabase project through
 * the Management API query endpoint (no database password required).
 *
 *   node scripts/sql-via-api.mjs <sbp_token> <project_ref> <file.sql>
 *
 * The file is sent as ONE multi-statement batch; any SQL error (including a
 * RAISE EXCEPTION from a verification DO-block) fails the call with exit 1.
 */
import { readFileSync, existsSync } from 'node:fs';

const [token, ref, file] = process.argv.slice(2);
if (!token?.startsWith('sbp_') || !ref || !file?.endsWith('.sql') || !existsSync(file)) {
  console.error('Usage: node scripts/sql-via-api.mjs <sbp_token> <project_ref> <file.sql>');
  process.exit(2);
}

const sql = readFileSync(file, 'utf8');
console.log(`[sql-via-api] executing ${file} (${sql.length} chars) on ${ref} ...`);

const res = await fetch(`https://api.supabase.com/v1/projects/${ref}/database/query`, {
  method: 'POST',
  headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({ query: sql }),
});

const text = await res.text();
if (!res.ok) {
  console.error(`[sql-via-api] FAILED — HTTP ${res.status}`);
  console.error(text.slice(0, 2000));
  process.exit(1);
}

let rows = null;
try { rows = JSON.parse(text); } catch { /* non-json ok */ }
console.log('[sql-via-api] SUCCESS — script executed completely');
if (rows && Array.isArray(rows) && rows.length) {
  console.log('[sql-via-api] rows:', JSON.stringify(rows).slice(0, 500));
}
process.exit(0);
