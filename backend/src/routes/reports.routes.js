import { Router } from 'express';
import { z } from 'zod';
import { admin } from '../config.js';
import { errors, mapDbError } from '../errors.js';
import { requireAuth } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';

const router = Router();
router.use(requireAuth);

const createSchema = z.object({
  orderId: z.string().uuid(),
  productName: z.string().trim().min(1).max(160),
  issueType: z.string().trim().min(1).max(80),
  details: z.string().trim().max(1000).optional().default(''),
});

/** POST /api/v1/reports — a client reports an issue with one of their orders. */
router.post('/', validate({ body: createSchema }), async (req, res, next) => {
  try {
    // The report must reference an order owned by the caller.
    const { data: order, error: orderErr } = await admin
      .from('orders')
      .select('id, order_number')
      .eq('id', req.body.orderId)
      .eq('client_user_id', req.user.id)
      .maybeSingle();
    if (orderErr) return next(mapDbError(orderErr));
    if (!order) return next(errors.notFound('Order'));

    const { data, error } = await admin
      .from('product_reports')
      .insert({
        user_id: req.user.id,
        order_id: req.body.orderId,
        product_name: req.body.productName,
        issue_type: req.body.issueType,
        details: req.body.details,
      })
      .select()
      .single();
    if (error) return next(mapDbError(error));
    res.status(201).json({ data });
  } catch (err) {
    next(err);
  }
});

/** GET /api/v1/reports — clients see their own; admins see all. */
router.get('/', async (req, res, next) => {
  try {
    const isAdmin = ['admin', 'super_admin'].includes(req.user.role);
    let query = admin.from('product_reports').select('*').order('created_at', { ascending: false });
    if (!isAdmin) query = query.eq('user_id', req.user.id);
    const { data, error } = await query.limit(100);
    if (error) return next(mapDbError(error));
    res.json({ data });
  } catch (err) {
    next(err);
  }
});

export default router;
