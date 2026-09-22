import { Router } from 'express';
import { z } from 'zod';
import { admin, PAGINATION } from '../config.js';
import { errors, mapDbError } from '../errors.js';
import { requireAuth } from '../middleware/auth.js';
import { requireRole } from '../middleware/role.js';
import { validate, pagination } from '../middleware/validate.js';

const router = Router();
router.use(requireAuth);

/**
 * Legal fulfilment transitions (P4). Terminal states cannot be left.
 * delivered → (terminal), cancelled → (terminal)
 */
const TRANSITIONS = {
  processing: ['shipped', 'cancelled'],
  shipped: ['delivered'],
  delivered: [],
  cancelled: [],
};

const createSchema = z.object({
  items: z
    .array(z.object({ productId: z.string().uuid(), quantity: z.number().int().positive() }))
    .min(1)
    .max(50),
  incoterms: z.enum(['FOB', 'CIF', 'EXW', 'DDP']).optional().default('FOB'),
  paymentMethod: z.string().trim().max(60).optional().default('Wire Transfer'),
  shippingAddress: z.string().trim().max(500).optional().default(''),
  notes: z.string().trim().max(1000).optional().default(''),
});

const statusSchema = z.object({
  status: z.enum(['processing', 'shipped', 'delivered', 'cancelled']),
});

/** GET /api/v1/orders — clients see their own orders; admins see all. */
router.get('/', async (req, res, next) => {
  try {
    const isAdmin = ['admin', 'super_admin'].includes(req.user.role);
    const { page, limit, offset } = pagination(req, PAGINATION.defaultLimit, PAGINATION.maxLimit);

    let query = admin.from('orders').select(
      '*, order_items(*)' + (isAdmin ? ', profiles!orders_client_user_id_fkey(email, full_name)' : ''),
    );
    if (!isAdmin) query = query.eq('client_user_id', req.user.id);

    const { data, error, count } = await query
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);
    if (error) return next(mapDbError(error));
    res.json({ data, page: { page, limit, total: count ?? data.length } });
  } catch (err) {
    next(err);
  }
});

/** GET /api/v1/orders/stats — dashboard counts (admin). */
router.get('/stats', requireRole('admin'), async (_req, res, next) => {
  try {
    const { data, error } = await admin.from('orders').select('status');
    if (error) return next(mapDbError(error));
    const counts = { total: data.length, processing: 0, shipped: 0, delivered: 0, cancelled: 0 };
    for (const row of data) counts[row.status] = (counts[row.status] ?? 0) + 1;
    res.json({ data: counts });
  } catch (err) {
    next(err);
  }
});

// __ORDERS_PART2__

/**
 * P3 · ORDER PLACEMENT PIPELINE — POST /api/v1/orders
 * 1. caller must be a VERIFIED client (also enforced by DB trigger)
 * 2. prices/MOQ come from the products table — never from the request
 * 3. order + items inserted; DB triggers compute totals + notify
 */
router.post('/', validate({ body: createSchema }), async (req, res, next) => {
  try {
    if (req.user.role !== 'client') {
      return next(errors.forbidden('Only client accounts can place orders.'));
    }

    const { data: clientProfile, error: cpErr } = await admin
      .from('client_profiles')
      .select('id, verification_status')
      .eq('user_id', req.user.id)
      .maybeSingle();
    if (cpErr) return next(mapDbError(cpErr));
    if (!clientProfile || clientProfile.verification_status !== 'verified') {
      return next(
        errors.unprocessable(
          'CLIENT_NOT_VERIFIED',
          'Your business account must be verified before placing orders.',
        ),
      );
    }

    const ids = [...new Set(req.body.items.map((i) => i.productId))];
    const { data: products, error: pErr } = await admin
      .from('products')
      .select('id, name, price, currency, min_order_qty, is_active')
      .in('id', ids);
    if (pErr) return next(mapDbError(pErr));

    const byId = new Map(products.map((p) => [p.id, p]));
    const lines = [];
    for (const item of req.body.items) {
      const product = byId.get(item.productId);
      if (!product || !product.is_active) {
        return next(errors.unprocessable('PRODUCT_UNAVAILABLE', `Product ${item.productId} is not available.`));
      }
      if (item.quantity < product.min_order_qty) {
        return next(
          errors.unprocessable('MOQ_NOT_MET', `Minimum order quantity for ${product.name} is ${product.min_order_qty}.`),
        );
      }
      lines.push({
        product_id: product.id,
        product_name: product.name,
        quantity: item.quantity,
        unit_price: product.price, // server-side price — client price ignored
      });
    }

    const currency = products[0]?.currency ?? 'USD';
    const { data: order, error: oErr } = await admin
      .from('orders')
      .insert({
        client_user_id: req.user.id,
        currency,
        incoterms: req.body.incoterms,
        payment_method: req.body.paymentMethod,
        shipping_address: req.body.shippingAddress,
        notes: req.body.notes,
      })
      .select()
      .single();
    if (oErr) return next(mapDbError(oErr));

    const { error: itemsErr } = await admin
      .from('order_items')
      .insert(lines.map((l) => ({ ...l, order_id: order.id })));
    if (itemsErr) return next(mapDbError(itemsErr));

    // Order-placed notification (status changes are handled by the DB trigger).
    await admin.from('notifications').insert({
      user_id: req.user.id,
      title: `Order ${order.order_number} placed`,
      body: 'We received your export order and it is being processed.',
      kind: 'order',
    });

    const { data: full } = await admin.from('orders').select('*, order_items(*)').eq('id', order.id).single();
    res.status(201).json({ data: full });
  } catch (err) {
    next(err);
  }
});

/**
 * P4 · FULFILMENT PIPELINE — PATCH /api/v1/orders/:id/status
 * Enforces the transition map; the DB trigger notifies the client.
 */
router.patch('/:id/status', requireRole('admin'), validate({ body: statusSchema }), async (req, res, next) => {
  try {
    const { data: order } = await admin.from('orders').select('id, status').eq('id', req.params.id).maybeSingle();
    if (!order) return next(errors.notFound('Order'));

    const allowed = TRANSITIONS[order.status] ?? [];
    if (!allowed.includes(req.body.status)) {
      return next(
        errors.unprocessable('INVALID_TRANSITION', `Cannot move an order from '${order.status}' to '${req.body.status}'.`),
      );
    }

    const { data, error } = await admin
      .from('orders')
      .update({ status: req.body.status, updated_at: new Date().toISOString() })
      .eq('id', req.params.id)
      .select('*, order_items(*)')
      .single();
    if (error) return next(mapDbError(error));
    res.json({ data });
  } catch (err) {
    next(err);
  }
});

/**
 * P4 - PAYMENT STATUS - PATCH /api/v1/orders/:id/payment
 * Admin marks an order paid / pending; invoices carry this status.
 */
const paymentSchema = z.object({ paymentStatus: z.enum(['pending', 'paid']) });

router.patch('/:id/payment', requireRole('admin'), validate({ body: paymentSchema }), async (req, res, next) => {
  try {
    const { data, error } = await admin
      .from('orders')
      .update({ payment_status: req.body.paymentStatus, updated_at: new Date().toISOString() })
      .eq('id', req.params.id)
      .select('*, order_items(*)')
      .single();
    if (error) return next(mapDbError(error));
    if (!data) return next(errors.notFound('Order'));
    res.json({ data });
  } catch (err) {
    next(err);
  }
});
export default router;
