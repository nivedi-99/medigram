import { errors } from '../errors.js';

/**
 * requireRole('admin')       → admin OR super_admin
 * requireRole('super_admin') → super_admin only
 * requireRole('client')      → clients only (admins rejected)
 */
export function requireRole(role) {
  return (req, _res, next) => {
    if (!req.user) return next(errors.unauthorized());
    const current = req.user.role;
    const allowed =
      role === 'admin'
        ? current === 'admin' || current === 'super_admin'
        : current === role;
    if (!allowed) {
      return next(errors.forbidden(`This endpoint requires the '${role}' role.`));
    }
    next();
  };
}
