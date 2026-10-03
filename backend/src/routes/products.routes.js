import express from 'express';
import { z } from 'zod';
import { admin, env, PAGINATION } from '../config.js';
import { errors, mapDbError } from '../errors.js';
import { requireAuth } from '../middleware/auth.js';
import { requireRole } from '../middleware/role.js';
import { validate, pagination } from '../middleware/validate.js';

const router = express.Router();

// NOTE: GET / is PUBLIC — signed-out visitors can browse the active export
// catalogue from the landing page. Every write stays admin-only, and the
// service-role client used here bypasses RLS, so no policy change is needed
// (direct anon access to the table itself is still blocked by RLS).

/** Public bucket photos live in (see supabase/add_product_images.sql). */
const PHOTO_BUCKET = 'product-images';

/**
 * Cached index (60s) of product ids that actually have a photo object in
 * storage, regardless of whether the image_url column has been applied.
 * One storage list call per minute serves the whole catalogue.
 */
let photoIndexAt = 0;
let photoIndexIds = new Set();

async function productIdsWithPhotos() {
  if (Date.now() - photoIndexAt < 60_000) return photoIndexIds;
  photoIndexAt = Date.now();
  try {
    const { data, error } = await admin.storage
      .from(PHOTO_BUCKET)
      .list('products', { limit: 1000 });
    if (!error && Array.isArray(data)) {
      // Canonical names are `products/<productId>` (no extension); strip any
      // extension so legacy uploads still match.
      photoIndexIds = new Set(
        data.map((o) => String(o.name).replace(/\.[a-z0-9]+$/i, '')),
      );
    }
  } catch {
    // Keep the previous index on transient failures.
  }
  return photoIndexIds;
}

/**
 * Photo resolution for a product row: the URL stored in the database when
 * present, otherwise the canonical storage path `products/<id>` — which
 * exists as soon as an admin uploaded a photo, even while the image_url
 * column is not applied yet. `has_photo` tells the app whether the photo
 * actually exists so it can fall back to the category product shot instead
 * of requesting a missing file.
 */
const withPhotoUrl = (row, hasObject) => ({
  ...row,
  image_url:
    row.image_url ||
    `${env.SUPABASE_URL}/storage/v1/object/public/${PHOTO_BUCKET}/products/${row.id}`,
  has_stored_photo: Boolean(row.image_url),
  has_photo: Boolean(row.image_url) || hasObject,
});

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
 * Photo column detection (cached 60s): the API cannot run DDL, so until
 * supabase/add_product_images.sql is applied we must not send `image_url`
 * to the database at all — the write then never fails on the missing
 * column and photos keep working through the canonical storage path.
 */
let photoColumnProbedAt = 0;
let photoColumnExists = true;

async function hasPhotoColumn() {
  if (Date.now() - photoColumnProbedAt < 60_000) return photoColumnExists;
  photoColumnProbedAt = Date.now();
  const { error } = await admin.from('products').select('image_url').limit(1);
  if (!error) {
    photoColumnExists = true;
  } else if (isMissingImageUrlColumn(error)) {
    photoColumnExists = false;
  }
  // On any other (transient) error keep the optimistic default.
  return photoColumnExists;
}

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
    // Attach photo URLs (stored link, or the canonical storage path) and an
    // accurate has_photo flag from the storage index.
    const photoIds = await productIdsWithPhotos();
    const rows = (data ?? []).map((r) => withPhotoUrl(r, photoIds.has(String(r.id))));
    res.json({ data: rows, page: { page, limit, total: count ?? rows.length } });
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
      // omitted rather than stored as ''). Skipped while the image_url
      // column is not applied — the canonical storage path serves the
      // photo regardless.
      ...(b.imageUrl && (await hasPhotoColumn())
        ? { image_url: b.imageUrl }
        : {}),
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
    if (data) {
      const photoIds = await productIdsWithPhotos();
      data = withPhotoUrl(data, photoIds.has(String(data.id)));
    }
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
      const id = String(req.params.id ?? '').trim();
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
        // Sent on every image edit — including '' which clears the photo —
        // but only when the live database can actually store it (the
        // canonical storage path keeps photos working without the column).
        ...(b.imageUrl !== undefined && (await hasPhotoColumn())
          ? { image_url: b.imageUrl }
          : {}),
      };
      // Write and read in two steps: interpreting the update's own return
      // proved fragile (missing columns / odd row shapes could surface as a
      // false "not found"), so the update is fired and the row is then
      // fetched fresh by its primary key.
      const { error } = await admin.from('products').update(row).eq('id', id);
      if (error) return next(mapDbError(error));

      const { data, error: fetchError } = await admin
        .from('products')
        .select('*')
        .eq('id', id)
        .maybeSingle();
      if (fetchError) return next(mapDbError(fetchError));
      if (!data) return next(errors.notFound('Product'));
      const photoIds = await productIdsWithPhotos();
      res.json({ data: withPhotoUrl(data, photoIds.has(String(data.id))) });
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
    // Two-step write-then-fetch, as in PATCH: the update's own return is
    // not interpreted, the row is read fresh afterwards.
    const { error } = await admin
      .from('products')
      .update({ is_active: false })
      .eq('id', req.params.id);
    if (error) return next(mapDbError(error));
    const { data, error: fetchError } = await admin
      .from('products')
      .select('*')
      .eq('id', req.params.id)
      .maybeSingle();
    if (fetchError) return next(mapDbError(fetchError));
    if (!data) return next(errors.notFound('Product'));
    const photoIds = await productIdsWithPhotos();
    res.json({ data: withPhotoUrl(data, photoIds.has(String(data.id))) });
  } catch (err) {
    next(err);
  }
});

export default router;
