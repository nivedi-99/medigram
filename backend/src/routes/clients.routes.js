import { Router } from 'express';
import { z } from 'zod';
import { admin, PAGINATION } from '../config.js';
import { errors, mapDbError } from '../errors.js';
import { requireAuth } from '../middleware/auth.js';
import { requireRole } from '../middleware/role.js';
import { validate, pagination } from '../middleware/validate.js';

const router = Router();
router.use(requireAuth, requireRole('admin'));

const verifySchema = z.object({
  status: z.enum(['verified', 'rejected', 'pending']),
});
const assignSchema = z.object({ adminUserId: z.string().uuid() });

/**
 * GET /api/v1/clients?status=&page=&limit=
 * The B2B client database (admin view).
 */
router.get('/', async (req, res, next) => {
  try {
    const { page, limit, offset } = pagination(req, PAGINATION.defaultLimit, PAGINATION.maxLimit);
    let query = admin.from('client_profiles').select('*', { count: 'exact' });
    if (req.query.status) query = query.eq('verification_status', req.query.status);

    const { data, error, count } = await query
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) return next(mapDbError(error));
    res.json({ data, page: { page, limit, total: count ?? data.length } });
  } catch (err) {
    next(err);
  }
});

/**
 * P2 · KYC PIPELINE — PATCH /api/v1/clients/:id/verify
 * Sets verification_status; the client_kyc_notify DB trigger pushes a
 * notification to the client automatically.
 */
router.patch('/:id/verify', validate({ body: verifySchema }), async (req, res, next) => {
  try {
    const { data, error } = await admin
      .from('client_profiles')
      .update({
        verification_status: req.body.status,
        verified_at: req.body.status === 'verified' ? new Date().toISOString() : null,
      })
      .eq('id', req.params.id)
      .select()
      .single();

    if (error) return next(mapDbError(error));
    if (!data) return next(errors.notFound('Client'));
    res.json({ data });
  } catch (err) {
    next(err);
  }
});

/** PATCH /api/v1/clients/:id/assign — assign an admin handler to a client. */
router.patch('/:id/assign', validate({ body: assignSchema }), async (req, res, next) => {
  try {
    const { data: target } = await admin
      .from('profiles')
      .select('id, role')
      .eq('id', req.body.adminUserId)
      .maybeSingle();
    if (!target || !['admin', 'super_admin'].includes(target.role)) {
      return next(errors.unprocessable('INVALID_REFERENCE', 'Assigned user must be an admin.'));
    }

    const { data, error } = await admin
      .from('client_profiles')
      .update({ assigned_admin_id: req.body.adminUserId })
      .eq('id', req.params.id)
      .select()
      .single();

    if (error) return next(mapDbError(error));
    if (!data) return next(errors.notFound('Client'));
    res.json({ data });
  } catch (err) {
    next(err);
  }
});

export default router;
