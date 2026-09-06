import { Router } from 'express';
import { z } from 'zod';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { admin } from '../config.js';
import { requireAuth } from '../middleware/auth.js';
import { requireRole } from '../middleware/role.js';
import { validate } from '../middleware/validate.js';
import { errors } from '../errors.js';

const router = Router();
router.use(requireAuth);

const here = path.dirname(fileURLToPath(import.meta.url));
const DEFAULTS = JSON.parse(
  readFileSync(path.join(here, '..', 'data', 'payments.default.json'), 'utf8'),
);

const BUCKET = 'app-config';
const OBJECT = 'payments.json';

/**
 * Global settlement configuration — payment channels that can remit money
 * from anywhere in the world to our Indian accounts, plus the FX table used
 * for regional display pricing and INR settlement previews.
 *
 * Stored as a single JSON document in Supabase Storage (bucket `app-config`),
 * editable by admins without a redeploy. Lazily seeded from defaults.
 */

async function ensureBucket() {
  const { error } = await admin.storage.createBucket(BUCKET, { public: false });
  if (error && !`${error.message}`.toLowerCase().includes('exist')) throw error;
}

async function readConfig() {
  const { data, error } = await admin.storage.from(BUCKET).download(OBJECT);
  if (error || !data) {
    await ensureBucket();
    const seeded = DEFAULTS;
    const { error: upErr } = await admin.storage
      .from(BUCKET)
      .upload(OBJECT, JSON.stringify(seeded), { contentType: 'application/json', upsert: true });
    if (upErr && !`${upErr.message}`.toLowerCase().includes('exist')) throw upErr;
    return seeded;
  }
  const text = await data.text();
  return JSON.parse(text);
}

const configSchema = z.object({
  whatsappNumber: z.string().trim().min(6).max(24),
  fx: z.record(z.string().length(3).regex(/^[A-Z]{3}$/), z.number().positive()),
  methods: z
    .array(
      z.object({
        key: z.string().trim().min(2).max(40),
        label: z.string().trim().min(2).max(120),
        tagline: z.string().trim().max(200).optional().default(''),
        sortOrder: z.number().int().optional().default(0),
        active: z.boolean().optional().default(true),
        details: z.record(z.string(), z.string().max(300)).optional().default({}),
        instructions: z.string().trim().max(1200).optional().default(''),
      }),
    )
    .min(1),
});

/** GET /api/v1/payments — settlement config for clients (active + full FX). */
router.get('/', async (req, res, next) => {
  try {
    const cfg = await readConfig();
    const methods = cfg.methods
      .filter((m) => m.active !== false)
      .sort((a, b) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0));
    res.json({ data: { whatsappNumber: cfg.whatsappNumber, fx: cfg.fx, methods } });
  } catch (err) {
    next(err);
  }
});

/** PUT /api/v1/payments — replace the settlement config (admin). */
router.put('/', requireRole('admin'), validate({ body: configSchema }), async (req, res, next) => {
  try {
    await ensureBucket();
    const { error } = await admin.storage
      .from(BUCKET)
      .upload(OBJECT, JSON.stringify(req.body), { contentType: 'application/json', upsert: true });
    if (error) throw error;
    res.json({ data: req.body });
  } catch (err) {
    next(err);
  }
});

export default router;