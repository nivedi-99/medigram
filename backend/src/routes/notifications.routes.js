import { Router } from 'express';
import { admin, PAGINATION } from '../config.js';
import { mapDbError } from '../errors.js';
import { requireAuth } from '../middleware/auth.js';
import { pagination } from '../middleware/validate.js';

const router = Router();
router.use(requireAuth);

/** GET /api/v1/notifications?unread=true — the caller's inbox. */
router.get('/', async (req, res, next) => {
  try {
    const { page, limit, offset } = pagination(req, PAGINATION.defaultLimit, PAGINATION.maxLimit);
    let query = admin
      .from('notifications')
      .select('*', { count: 'exact' })
      .eq('user_id', req.user.id);
    if (req.query.unread === 'true') query = query.eq('is_read', false);

    const { data, error, count } = await query.order('created_at', { ascending: false }).range(offset, offset + limit - 1);
    if (error) return next(mapDbError(error));
    res.json({ data, page: { page, limit, total: count ?? data.length } });
  } catch (err) {
    next(err);
  }
});

/** PATCH /api/v1/notifications/:id/read — mark one notification read. */
router.patch('/:id/read', async (req, res, next) => {
  try {
    const { data, error } = await admin
      .from('notifications')
      .update({ is_read: true })
      .eq('id', req.params.id)
      .eq('user_id', req.user.id) // ownership enforced
      .select()
      .single();
    if (error) return next(mapDbError(error));
    res.json({ data });
  } catch (err) {
    next(err);
  }
});

/** PATCH /api/v1/notifications/read-all — mark every unread item read. */
router.patch('/read-all', async (req, res, next) => {
  try {
    const { error } = await admin
      .from('notifications')
      .update({ is_read: true })
      .eq('user_id', req.user.id)
      .eq('is_read', false);
    if (error) return next(mapDbError(error));
    res.json({ data: { ok: true } });
  } catch (err) {
    next(err);
  }
});

export default router;
