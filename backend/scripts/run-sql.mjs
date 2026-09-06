#!/usr/bin/env node
/**
 * run-sql.mjs — self-service SQL executor for the MediGram database gates.
 *
 *   node scripts/run-sql.mjs ../../supabase/schema.sql
 *   node scripts/run-sql.mjs ../../supabase/verify.sql
 *
 * Connection string resolution order:
 *   1. --db-url postgresql://... CLI argument
 *   2. DATABASE_URL in backend/.env
 *
 * Notes:
 *  - The whole file is sent as ONE simple-query batch, so `DO $$ ... $$`
 *    blocks and semicolons inside function bodies are handled by Postgres
 *    itself — no naive splitting.
 *  - RAISE NOTICE output (the gate's PASSED lines) is streamed to stdout.
 *  - Exit code 0 only when the server reports success.
 */
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import pg from 'pg';

const here = path.dirname(fileURLToPath(import.meta.url));

function resolveDbUrl() {
  const argIndex = process.argv.indexOf('--db-url');
  if (argIndex !== -1 && process.argv[argIndex + 1]) return process.argv[argIndex + 1];

  const envPath = path.join(here, '..', '.env');
  if (existsSync(envPath)) {
    for (const line of readFileSync(envPath, 'utf8').split(/\r?\n/)) {
      const m = line.match(/^\s*DATABASE_URL\s*=\s*(.+?)\s*$/);
      if (m) return m[1];
    }
  }
  return null;
}

const file = process.argv.find((a) => !a.startsWith('--') && a.endsWith('.sql'));
if (!file || !existsSync(file)) {
  console.error('Usage: node scripts/run-sql.mjs <file.sql> [--db-url postgresql://...]');
  process.exit(2);
}
const dbUrl = resolveDbUrl();
if (!dbUrl) {
  console.error('No DATABASE_URL found — pass --db-url or set DATABASE_URL in backend/.env');
  process.exit(2);
}

const sql = readFileSync(file, 'utf8');
const client = new pg.Client({ connectionString: dbUrl, ssl: { rejectUnauthorized: false } });
client.on('notice', (n) => console.log(`NOTICE: ${n.message}`));

try {
  await client.connect();
  console.log(`[run-sql] connected — executing ${path.basename(file)}`);
  await client.query(sql);
  console.log('[run-sql] SUCCESS — script executed completely');
  await client.end();
  process.exit(0);
} catch (err) {
  console.error('[run-sql] FAILED:', err.message);
  if (err.where) console.error('[run-sql] at:', err.where);
  try { await client.end(); } catch { /* already closed */ }
  process.exit(1);
}
