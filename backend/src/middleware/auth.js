import { admin } from '../config.js';
import { errors } from '../errors.js';

/**
 * requireAuth — validates the Supabase JWT, loads the caller's profile and
 * attaches it as `req.user`. Rejects unknown accounts and deactivated users.
 */
export async function requireAuth(req, _res, next) {
  try {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7).trim() : null;
    if (!token) throw errors.unauthorized('Missing bearer token');

    const { data: userData, error: userError } = await admin.auth.getUser(token);
    if (userError || !userData?.user) {
      throw errors.unauthorized();
    }

    const { data: profile, error: profileError } = await admin
      .from('profiles')
      .select('*')
      .eq('id', userData.user.id)
      .maybeSingle();

    if (profileError) throw errors.unauthorized();
    if (!profile) throw errors.forbidden('No profile exists for this account.');
    if (!profile.is_active) throw errors.forbidden('This account has been deactivated.');

    req.user = {
      id: profile.id,
      email: profile.email,
      fullName: profile.full_name,
      phone: profile.phone,
      role: profile.role,
      companyName: profile.company_name,
      country: profile.country,
      token,
    };
    next();
  } catch (err) {
    next(err);
  }
}
