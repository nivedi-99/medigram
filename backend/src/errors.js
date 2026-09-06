/**
 * ApiError — every failure leaves the API in the same envelope:
 *   { "error": { "code": "FORBIDDEN", "message": "…" } }
 */
export class ApiError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

export const errors = {
  unauthorized: (msg = 'Missing, invalid or expired token') =>
    new ApiError(401, 'UNAUTHORIZED', msg),
  forbidden: (msg = 'You do not have permission to do this') =>
    new ApiError(403, 'FORBIDDEN', msg),
  notFound: (what = 'Resource') => new ApiError(404, 'NOT_FOUND', `${what} not found`),
  conflict: (code, msg) => new ApiError(409, code, msg),
  unprocessable: (code, msg) => new ApiError(422, code, msg),
  badRequest: (msg = 'Malformed request') => new ApiError(400, 'BAD_REQUEST', msg),
};

/** Maps Supabase/Postgres error text onto safe API errors. */
export function mapDbError(err, fallbackMsg = 'Database operation failed') {
  const msg = String(err?.message || '');
  if (msg.includes('ORDER_REQUIRES_VERIFIED_CLIENT')) {
    return errors.unprocessable(
      'CLIENT_NOT_VERIFIED',
      'Your business account must be verified before placing orders.',
    );
  }
  if (msg.includes('ONLY_SUPER_ADMIN') || msg.includes('NOT_ALLOWED')) {
    return errors.forbidden('Super admin permission required.');
  }
  if (msg.includes('CANNOT_MODIFY_SUPER_ADMIN')) {
    return errors.conflict('CANNOT_MODIFY_SUPER_ADMIN', 'Super admin accounts cannot be modified.');
  }
  if (msg.includes('PROFILE_NOT_FOUND')) {
    return errors.notFound('Profile');
  }
  if (err?.code === '23505' || msg.includes('duplicate key')) {
    return errors.conflict('DUPLICATE', 'A record with these details already exists.');
  }
  if (err?.code === '23503' || msg.includes('violates foreign key')) {
    return errors.unprocessable('INVALID_REFERENCE', 'Referenced record does not exist.');
  }
  console.error('[db]', err?.message || err);
  return new ApiError(500, 'INTERNAL', fallbackMsg);
}

/** Express error handler — must be registered last. */
export function errorHandler(err, _req, res, _next) {
  if (err instanceof ApiError) {
    return res.status(err.status).json({ error: { code: err.code, message: err.message } });
  }
  if (err?.type === 'entity.parse.failed') {
    return res.status(400).json({ error: { code: 'BAD_JSON', message: 'Request body is not valid JSON' } });
  }
  console.error('[unhandled]', err);
  res.status(500).json({ error: { code: 'INTERNAL', message: 'Unexpected server error' } });
}
