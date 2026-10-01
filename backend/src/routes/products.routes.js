import { Router } from 'express';
import { z } from 'zod';
import { admin, PAGINATION } from '../config.js';
import { errors, mapDbError } from '../errors.js';
import { requireAuth } from '../middleware/auth.js';
import { requireRole } from '../middleware/role.js';
import { validate, pagination } from '../middleware/validate.js';

const router = Router();

// NOTE: GET / is PUBLIC — signed-out visitors can browse the active export
// catalogue from the landing page. Every write stays admin-only, and the
// service-role client used here bypasses RLS, so no policy change is needed
// (direct anon access to the table itself is still blocked by RLS).

const createSchema = z.object({
  name: z.string().trim().min(2).max(160),
  category: z.string().trim().max(80).optional().default('General'),
  manufacturer: z.string().trim().max(160).optional().default(''),
  description: z.string().trim().max(2000).optional().default(''),
  strength: z.string().trim().max(120).optional().default(''),
  price: z.number().nonnegative(),
  currency: z.string().trim().length(3).optional().default('USD'),
  minOrderQty: z.number().int().positive().optional().default(1),
  isActive: z.boolean().optional().default(true),
  imageUrl: z
    .string()
    .trim()
    .max(2048)
    // '' clears the photo; otherwise it must be an http(s) public URL.
    .refine((v) => v === '' || /^https?:\/\//i.test(v), {
      message: 'imageUrl must be an http(s) URL',
    })
    .optional(),
});

const patchSchema = createSchema.partial();

/**
 * True when the live database still lacks the strength / image_url column
 * (supabase/upgrade_strength_payments.sql, add_product_images.sql not applied
 * yet). PostgREST reports PGRST204 / SQLSTATE 42703 for undefined columns.
 */
const isMissingStrengthColumn = (error) =>
  !!error &&
  (error.code === 'PGRST204' ||
    error.code === '42703' ||
    /strength/i.test(error.message ?? ''));

const isMissingImageUrlColumn = (error) =>
  !!error &&
  (error.code === 'PGRST204' || error.code === '42703') &&
  /image_url/i.test(error.message ?? '');

/** Returns a shallow copy of the row without the strength field. */
const omitStrength = (row) => {
  const { strength, ...rest } = row;
  return rest;
};

/** Returns a shallow copy of the row without the image_url field. */
const omitImageUrl = (row) => {
  const { image_url, ...rest } = row;
  return rest;
};

/**
 * Runs a PostgREST write against `row`, transparently dropping the optional
 * strength / image_url fields when the live database predates their
 * migrations (each failing query names one missing column, so the loop can
 * shed up to two). Once the SQL upgrades are applied the first attempt
 * always succeeds and nothing is dropped.
 */
async function writeWithColumnFallback(row, run) {
  let payload = row;
  let result = await run(payload);
  for (let i = 0; i < 2 && result.error; i += 1) {
    const { error } = result;
    if (payload.strength !== undefined && isMissingStrengthColumn(error)) {
      payload = omitStrength(payload);
    } else if (payload.image_url !== undefined && isMissingImageUrlColumn(error)) {
      payload = omitImageUrl(payload);
    } else {
      break;
    }
    result = await run(payload);
  }
  return result;
}

/**
 * P7 · CATALOGUE PIPELINE — GET /api/v1/products
 * Clients see active products only; admins see everything (incl. hidden).
 */
router.get('/', async (req, res, next) => {
  try {
    // Guests (no/invalid token) browse the same active catalogue clients see;
    // only authenticated admins additionally see hidden rows.
    const role = req.user?.role;
    const isAdmin = role === 'admin' || role === 'super_admin';
    const { page, limit, offset } = pagination(req, PAGINATION.defaultLimit, PAGINATION.maxLimit);

    let query = admin.from('products').select('*', { count: 'exact' });
    if (!isAdmin) query = query.eq('is_active', true);
    if (req.query.category) query = query.eq('category', req.query.category);
    if (req.query.q) query = query.ilike('name', `%${req.query.q}%`);

    const { data, error, count } = await query.order('name').range(offset, offset + limit - 1);
    if (error) return next(mapDbError(error));
    res.json({ data, page: { page, limit, total: count ?? data.length } });
  } catch (err) {
    next(err);
  }
});

/** POST /api/v1/products — create a catalogue entry (admin). */
router.post('/', requireAuth, requireRole('admin'), validate({ body: createSchema }), async (req, res, next) => {
  try {
    const b = req.body;
    // PostgREST speaks snake_case - map the camelCase API body.
    const row = {
      name: b.name,
      category: b.category,
      manufacturer: b.manufacturer,
      description: b.description,
      price: b.price,
      currency: b.currency,
      min_order_qty: b.minOrderQty,
      is_active: b.isActive,
      // Omitted when empty so inserts also work before the strength
      // migration has been applied to the live database.
      ...(b.strength ? { strength: b.strength } : {}),
      // Admin-uploaded product photo (empty = no photo, so the key is
      // omitted rather than stored as '').
      ...(b.imageUrl ? { image_url: b.imageUrl } : {}),
    };
    // NOTE: .select() on purpose, never .single() — .single() mangles write
    // errors (e.g. the missing-column PGRST204 below) into an opaque
    // "Cannot coerce the result to a single JSON object" failure. The insert
    // targets exactly one row, so take the first returned row.
    let { data, error } = await writeWithColumnFallback(row, (payload) =>
      admin.from('products').insert(payload).select(),
    );
    data = Array.isArray(data) ? (data[0] ?? null) : data;
    if (error) return next(mapDbError(error));
    res.status(201).json({ data });
  } catch (err) {
    next(err);
  }
});

/** PATCH /api/v1/products/:id — edit a catalogue entry (admin). */
router.patch(
  '/:id',
  requireAuth,
  requireRole('admin'),
  validate({ body: patchSchema }),
  async (req, res, next) => {
    try {
      const b = req.body;
      const row = {
        ...(b.name !== undefined && { name: b.name }),
        ...(b.category !== undefined && { category: b.category }),
        ...(b.manufacturer !== undefined && { manufacturer: b.manufacturer }),
        ...(b.description !== undefined && { description: b.description }),
        // Omitted when empty so edits also work before the strength
        // migration has been applied to the live database.
        ...(b.strength ? { strength: b.strength } : {}),
        ...(b.price !== undefined && { price: b.price }),
        ...(b.currency !== undefined && { currency: b.currency }),
        ...(b.minOrderQty !== undefined && { min_order_qty: b.minOrderQty }),
        ...(b.isActive !== undefined && { is_active: b.isActive }),
        // Sent on every image edit — including '' which clears the photo.
        ...(b.imageUrl !== undefined && { image_url: b.imageUrl }),
      };
      // Same .select() note as POST — keep write errors parseable so the
      // missing-column fallback below can actually see them.
      let { data, error } = await writeWithColumnFallback(row, (payload) =>
        admin
          .from('products')
          .update(payload)
          .eq('id', req.params.id)
          .select(),
      );
      data = Array.isArray(data) ? (data[0] ?? null) : data;
      if (error) return next(mapDbError(error));
      if (!data) return next(errors.notFound('Product'));
      res.json({ data });
    } catch (err) {
      next(err);
    }
  },
);

/**
 * DELETE /api/v1/products/:id — SOFT delete only (is_active=false).
 * Hard deletes would orphan historical order_items (P7 guarantee).
 */
router.delete('/:id', requireAuth, requireRole('admin'), async (req, res, next) => {
  try {
    // .select() without .single() — same reason as POST/PATCH: keep write
    // errors parseable and treat an empty result as "not found".
    const { data, error } = await admin
      .from('products')
      .update({ is_active: false })
      .eq('id', req.params.id)
      .select();
    const row = Array.isArray(data) ? (data[0] ?? null) : data;
    if (error) return next(mapDbError(error));
    if (!row) return next(errors.notFound('Product'));
    res.json({ data: row });
  } catch (err) {
    next(err);
  }
});

export default router;
