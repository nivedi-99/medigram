import { Router } from 'express';
import { z } from 'zod';
import { admin, PAGINATION } from '../config.js';
import { errors, mapDbError } from '../errors.js';
import { requireAuth } from '../middleware/auth.js';
import { requireRole } from '../middleware/role.js';
import { validate, pagination } from '../middleware/validate.js';

const router = Router();
router.use(requireAuth);

const createSchema = z.object({
  name: z.string().trim().min(2).max(160),
  category: z.string().trim().max(80).optional().default('General'),
  manufacturer: z.string().trim().max(160).optional().default(''),
  description: z.string().trim().max(2000).optional().default(''),
  price: z.number().nonnegative(),
  currency: z.string().trim().length(3).optional().default('USD'),
  minOrderQty: z.number().int().positive().optional().default(1),
  isActive: z.boolean().optional().default(true),
});

const patchSchema = createSchema.partial();

/**
 * P7 · CATALOGUE PIPELINE — GET /api/v1/products
 * Clients see active products only; admins see everything (incl. hidden).
 */
router.get('/', async (req, res, next) => {
  try {
    const isAdmin = ['admin', 'super_admin'].includes(req.user.role);
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
router.post('/', requireRole('admin'), validate({ body: createSchema }), async (req, res, next) => {
  try {
    const { data, error } = await admin.from('products').insert(req.body).select().single();
    if (error) return next(mapDbError(error));
    res.status(201).json({ data });
  } catch (err) {
    next(err);
  }
});

/** PATCH /api/v1/products/:id — edit a catalogue entry (admin). */
router.patch(
  '/:id',
  requireRole('admin'),
  validate({ body: patchSchema }),
  async (req, res, next) => {
    try {
      const { data, error } = await admin
        .from('products')
        .update(req.body)
        .eq('id', req.params.id)
        .select()
        .single();
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
router.delete('/:id', requireRole('admin'), async (req, res, next) => {
  try {
    const { data, error } = await admin
      .from('products')
      .update({ is_active: false })
      .eq('id', req.params.id)
      .select()
      .single();
    if (error) return next(mapDbError(error));
    if (!data) return next(errors.notFound('Product'));
    res.json({ data });
  } catch (err) {
    next(err);
  }
});

export default router;
