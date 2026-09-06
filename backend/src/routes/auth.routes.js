import { Router } from 'express';
import { z } from 'zod';
import { admin, authClient } from '../config.js';
import { errors, mapDbError } from '../errors.js';
import { requireAuth } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';

const router = Router();

const signupSchema = z.object({
  fullName: z.string().trim().min(2).max(120),
  email: z.string().trim().email(),
  password: z.string().min(6).max(72),
  phone: z.string().trim().min(7).max(30),
  companyName: z.string().trim().min(2).max(160),
  country: z.string().trim().min(2).max(80),
  businessLicenseNo: z.string().trim().max(80).optional().default(''),
});

const loginSchema = z.object({
  email: z.string().trim().email(),
  password: z.string().min(1),
});

const refreshSchema = z.object({ refreshToken: z.string().min(20) });
const emailSchema = z.object({ email: z.string().trim().email() });

/** Loads (and lightly shapes) a profile row by user id. */
async function profileFor(userId) {
  const { data, error } = await admin.from('profiles').select('*').eq('id', userId).maybeSingle();
  if (error) throw mapDbError(error);
  return data;
}

/**
 * P1 · SIGNUP PIPELINE
 * zod validation → Supabase auth user (email pre-confirmed: B2B identity is
 * proven later via admin KYC, not via email) → DB trigger creates
 * profiles(role=client) → client_profiles(pending) → welcome notification.
 */
router.post('/signup', validate({ body: signupSchema }), async (req, res, next) => {
  try {
    const b = req.body;

    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email: b.email,
      password: b.password,
      email_confirm: true,
      user_metadata: {
        full_name: b.fullName,
        phone: b.phone,
        company_name: b.companyName,
        country: b.country,
      },
    });

    if (createError) {
      if (createError.message.toLowerCase().includes('already been registered')) {
        return next(errors.conflict('EMAIL_TAKEN', 'An account with this email already exists.'));
      }
      return next(mapDbError(createError, 'Could not create the account.'));
    }

    // Give the on_auth_user_created trigger a moment, then read the profile.
    let profile = await profileFor(created.user.id);
    for (let i = 0; i < 3 && !profile; i += 1) {
      await new Promise((r) => setTimeout(r, 350));
      profile = await profileFor(created.user.id);
    }
    if (!profile) return next(errors.conflict('PROFILE_CREATION_FAILED', 'Account created but profile is missing.'));

    const clientInsert = await admin.from('client_profiles').upsert(
      {
        user_id: created.user.id,
        company_name: b.companyName,
        country: b.country,
        business_license_no: b.businessLicenseNo,
        contact_email: b.email,
        contact_phone: b.phone,
        verification_status: 'pending',
      },
      { onConflict: 'user_id' },
    );
    if (clientInsert.error) return next(mapDbError(clientInsert.error));

    await admin.from('notifications').insert({
      user_id: created.user.id,
      title: 'Welcome to MediGram',
      body: 'Your B2B account is pending verification. Our team reviews new businesses within 24 hours.',
      kind: 'system',
    });

    res.status(201).json({ data: { user: profile } });
  } catch (err) {
    next(err);
  }
});

/** P6 · LOGIN — password grant through the anonymous client. */
router.post('/login', validate({ body: loginSchema }), async (req, res, next) => {
  try {
    const { data: session, error } = await authClient.auth.signInWithPassword({
      email: req.body.email,
      password: req.body.password,
    });
    if (error || !session?.user) {
      return next(errors.unauthorized('Invalid email or password.'));
    }
    const profile = await profileFor(session.user.id);
    if (!profile) return next(errors.forbidden('No profile exists for this account.'));
    if (!profile.is_active) return next(errors.forbidden('This account has been deactivated.'));

    res.json({
      data: {
        accessToken: session.session.access_token,
        refreshToken: session.session.refresh_token,
        expiresAt: session.session.expires_at,
        user: profile,
      },
    });
  } catch (err) {
    next(err);
  }
});

/** P6 · REFRESH — rotate the access token with a refresh token. */
router.post('/refresh', validate({ body: refreshSchema }), async (req, res, next) => {
  try {
    const { data, error } = await authClient.auth.setSession({ refresh_token: req.body.refreshToken });
    if (error || !data?.session) {
      return next(errors.unauthorized('Refresh token is invalid or expired.'));
    }
    res.json({
      data: {
        accessToken: data.session.access_token,
        refreshToken: data.session.refresh_token,
        expiresAt: data.session.expires_at,
      },
    });
  } catch (err) {
    next(err);
  }
});

/** Forgot password — always 200 so the endpoint cannot enumerate emails. */
router.post('/forgot-password', validate({ body: emailSchema }), async (req, res) => {
  await authClient.auth.resetPasswordForEmail(req.body.email);
  res.json({ data: { message: 'If that account exists, a reset link has been sent.' } });
});

/** Session restore — hydrates the profile from the bearer token. */
router.get('/me', requireAuth, (req, res) => {
  res.json({ data: { user: req.user } });
});

/** Logout — revokes the session server-side. */
router.post('/logout', requireAuth, async (req, res) => {
  try {
    await admin.auth.signOut(req.user.token);
  } catch {
    /* token already expired — treat as logged out */
  }
  res.json({ data: { ok: true } });
});

export default router;
