import { Router } from 'express';
import { z } from 'zod';
import { admin } from '../config.js';
import { mapDbError } from '../errors.js';
import { requireAuth } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';

const router = Router();

const patchSchema = z.object({
  fullName: z.string().trim().min(2).max(120),
  phone: z.string().trim().max(30).optional().default(''),
  companyName: z.string().trim().max(160).optional(),
  country: z.string().trim().max(80).optional(),
});

/** PATCH /api/v1/profile — updates the caller's OWN profile (role excluded). */
router.patch('/', requireAuth, validate({ body: patchSchema }), async (req, res, next) => {
  try {
    const { fullName, phone, companyName, country } = req.body;
    const { data, error } = await admin
      .from('profiles')
      .update({
        full_name: fullName,
        phone,
        ...(companyName !== undefined ? { company_name: companyName } : {}),
        ...(country !== undefined ? { country } : {}),
        updated_at: new Date().toISOString(),
      })
      .eq('id', req.user.id)
      .select()
      .single();

    if (error) return next(mapDbError(error));
    res.json({ data: { user: data } });
  } catch (err) {
    next(err);
  }
});

export default router;
