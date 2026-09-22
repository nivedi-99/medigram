import { Router } from 'express';
import { admin } from '../config.js';
import { errors, mapDbError } from '../errors.js';
import { requireAuth } from '../middleware/auth.js';
import { requireRole } from '../middleware/role.js';

const router = Router();
router.use(requireAuth);

/** Minimal RFC-4180 CSV: quotes fields containing commas, quotes or newlines. */
function csvCell(value) {
  const s = value === null || value === undefined ? '' : String(value);
  return /[",\r\n]/.test(s) ? '"' + s.replaceAll('"', '""') + '"' : s;
}

function toCsv(headers, rows) {
  const lines = [headers.join(',')];
  for (const row of rows) lines.push(row.map(csvCell).join(','));
  return lines.join('\r\n') + '\r\n';
}

function sendCsv(res, filename, csv) {
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
  res.status(200).send(csv);
}

/** GET /api/v1/exports/products.csv - full catalogue incl. hidden (admin). */
router.get('/products.csv', requireRole('admin'), async (_req, res, next) => {
  try {
    const { data, error } = await admin.from('products').select('*').order('name');
    if (error) return next(mapDbError(error));
    const csv = toCsv(
      ['id', 'name', 'category', 'manufacturer', 'strength', 'description', 'price', 'currency', 'min_order_qty', 'is_active', 'created_at'],
      data.map((p) => [p.id, p.name, p.category, p.manufacturer, p.strength ?? '', p.description, p.price, p.currency, p.min_order_qty, p.is_active, p.created_at]),
    );
    sendCsv(res, 'medigram-products.csv', csv);
  } catch (err) {
    next(err);
  }
});

/** GET /api/v1/exports/users.csv - every registered user (super admin). */
router.get('/users.csv', requireRole('super_admin'), async (_req, res, next) => {
  try {
    const { data, error } = await admin
      .from('profiles')
      .select('id, email, full_name, role, company_name, country, phone, created_at, client_profiles(verification_status)')
      .order('email');
    if (error) return next(mapDbError(error));
    const csv = toCsv(
      ['id', 'email', 'full_name', 'role', 'company', 'country', 'phone', 'kyc_status', 'created_at'],
      data.map((u) => [
        u.id,
        u.email,
        u.full_name,
        u.role,
        u.company_name,
        u.country,
        u.phone,
        u.client_profiles && u.client_profiles[0] ? u.client_profiles[0].verification_status : '',
        u.created_at,
      ]),
    );
    sendCsv(res, 'medigram-users.csv', csv);
  } catch (err) {
    next(err);
  }
});

/** GET /api/v1/exports/orders.csv - orders + payment info (admins). */
router.get('/orders.csv', requireRole('admin'), async (_req, res, next) => {
  try {
    const { data, error } = await admin
      .from('orders')
      .select('*, profiles!orders_client_user_id_fkey(email, full_name)')
      .order('created_at', { ascending: false });
    if (error) return next(mapDbError(error));
    const csv = toCsv(
      ['order_number', 'date', 'client_email', 'client_name', 'status', 'payment_status', 'payment_method', 'incoterms', 'total_amount', 'currency', 'shipping_address', 'notes'],
      data.map((o) => [
        o.order_number,
        o.created_at,
        o.profiles ? o.profiles.email : '',
        o.profiles ? o.profiles.full_name : '',
        o.status,
        o.payment_status ?? 'pending',
        o.payment_method,
        o.incoterms,
        o.total_amount,
        o.currency,
        o.shipping_address,
        o.notes,
      ]),
    );
    sendCsv(res, 'medigram-orders-payments.csv', csv);
  } catch (err) {
    next(err);
  }
});

/** GET /api/v1/exports/invoice/:orderId.csv - invoice for one order (admin). */
router.get('/invoice/:orderId.csv', requireRole('admin'), async (req, res, next) => {
  try {
    const orderId = req.params.orderId.replace(/\.csv$/i, '');
    const { data: order, error } = await admin
      .from('orders')
      .select('*, order_items(*), profiles!orders_client_user_id_fkey(email, full_name)')
      .eq('id', orderId)
      .maybeSingle();
    if (error) return next(mapDbError(error));
    if (!order) return next(errors.notFound('Order'));

    const lines = [];
    lines.push('MediGram - Global Pharmaceutical Exports');
    lines.push('INVOICE');
    lines.push(`Invoice / order no,${order.order_number}`);
    lines.push(`Invoice date,${new Date(order.created_at).toISOString().slice(0, 10)}`);
    lines.push(`Billed to,"${order.profiles ? order.profiles.full_name : ''} <${order.profiles ? order.profiles.email : ''}>"`);
    lines.push(`Incoterms,${order.incoterms}`);
    lines.push(`Payment method,${order.payment_method}`);
    lines.push(`Payment status,${order.payment_status ?? 'pending'}`);
    lines.push('');
    lines.push('Item,Quantity,Unit price,Line total');
    let computed = 0;
    for (const item of order.order_items ?? []) {
      const lineTotal = Number(item.quantity) * Number(item.unit_price);
      computed += lineTotal;
      lines.push(`"${item.product_name}",${item.quantity},${item.unit_price},${lineTotal.toFixed(2)}`);
    }
    const total = order.total_amount !== null ? Number(order.total_amount) : computed;
    lines.push(`TOTAL,,,${total.toFixed(2)} ${order.currency}`);
    sendCsv(res, `invoice-${order.order_number}.csv`, lines.join('\r\n') + '\r\n');
  } catch (err) {
    next(err);
  }
});

export default router;
