import { Router } from 'express';
import { z } from 'zod';
import { admin } from '../config.js';
import { errors, mapDbError } from '../errors.js';
import { requireAuth } from '../middleware/auth.js';
import { requireRole } from '../middleware/role.js';
import { validate } from '../middleware/validate.js';

const router = Router();
router.use(requireAuth, requireRole('super_admin'));

const promoteSchema = z.object({ email: z.string().trim().email() });
const demoteSchema = z.object({ userId: z.string().uuid() });

/** GET /api/v1/admins — the admin handler database + role counts. */
router.get('/', async (_req, res, next) => {
  try {
    const [{ data: handlers, error: hErr }, { data: profiles, error: pErr }] = await Promise.all([
      admin.from('admin_handlers').select('*').order('created_at', { ascending: false }),
      admin.from('profiles').select('role'),
    ]);
    if (hErr) return next(mapDbError(hErr));
    if (pErr) return next(mapDbError(pErr));

    const counts = { client: 0, admin: 0, super_admin: 0 };
    for (const row of profiles ?? []) counts[row.role] = (counts[row.role] ?? 0) + 1;

    res.json({ data: { handlers, roleCounts: counts } });
  } catch (err) {
    next(err);
  }
});

/**
 * P5 · PROMOTION PIPELINE — POST /api/v1/admins/promote
 * Email → profile → DB-guarded RPC promote_to_admin (also upserts the
 * admin_handlers row inside the function).
 */
router.post('/promote', validate({ body: promoteSchema }), async (req, res, next) => {
  try {
    const { data: profile, error: findErr } = await admin
      .from('profiles')
      .select('*')
      .ilike('email', req.body.email)
      .maybeSingle();
    if (findErr) return next(mapDbError(findErr));
    if (!profile) return next(errors.notFound('Account with that email'));

    const { error: rpcErr } = await admin.rpc('promote_to_admin', {
      target_user_id: profile.id,
    });
    if (rpcErr) return next(mapDbError(rpcErr));

    const { data: updated } = await admin.from('profiles').select('*').eq('id', profile.id).single();
    res.json({ data: { user: updated } });
  } catch (err) {
    next(err);
  }
});

/** P5 · DEMOTION PIPELINE — POST /api/v1/admins/demote */
router.post('/demote', validate({ body: demoteSchema }), async (req, res, next) => {
  try {
    const { error } = await admin.rpc('demote_to_client', { target_user_id: req.body.userId });
    if (error) return next(mapDbError(error));

    const { data: updated } = await admin
      .from('profiles')
      .select('*')
      .eq('id', req.body.userId)
      .single();
    res.json({ data: { user: updated } });
  } catch (err) {
    next(err);
  }
});

/** PATCH /api/v1/admins/:id/toggle — activate / deactivate a handler row. */
router.patch('/:id/toggle', async (req, res, next) => {
  try {
    const { data: row } = await admin
      .from('admin_handlers')
      .select('id, is_active')
      .eq('id', req.params.id)
      .maybeSingle();
    if (!row) return next(errors.notFound('Admin handler'));

    const { data, error } = await admin
      .from('admin_handlers')
      .update({ is_active: !row.is_active })
      .eq('id', req.params.id)
      .select()
      .single();
    if (error) return next(mapDbError(error));
    res.json({ data });
  } catch (err) {
    next(err);
  }
});

export default router;
