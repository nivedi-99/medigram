import { errors } from '../errors.js';

/**
 * validate({ body?, params?, query? }) — zod schemas per request part.
 * Parsed (and coerced) values replace the originals.
 */
export const validate = (schemas) => (req, _res, next) => {
  try {
    for (const part of ['params', 'query', 'body']) {
      const schema = schemas[part];
      if (!schema) continue;
      const result = schema.safeParse(req[part]);
      if (!result.success) {
        const issue = result.error.issues[0];
        const where = issue.path.length ? `${part}.${issue.path.join('.')}` : part;
        return next(errors.unprocessable('VALIDATION_FAILED', `${where}: ${issue.message}`));
      }
      req[part] = result.data;
    }
    next();
  } catch (err) {
    next(err);
  }
};

/** Reads ?page & ?limit into a safe { page, limit, offset } tuple. */
export function pagination(req, defaultLimit = 20, maxLimit = 100) {
  const page = Math.max(1, Number.parseInt(req.query.page ?? '1', 10) || 1);
  const rawLimit = Number.parseInt(req.query.limit ?? String(defaultLimit), 10) || defaultLimit;
  const limit = Math.min(Math.max(1, rawLimit), maxLimit);
  return { page, limit, offset: (page - 1) * limit };
}
