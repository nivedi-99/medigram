import { createClient } from '@supabase/supabase-js';
import { z } from 'zod';

/**
 * Environment schema — the process refuses to boot with missing secrets,
 * which prevents ever accidentally running with the wrong credentials.
 */
const envSchema = z.object({
  PORT: z.coerce.number().default(4000),
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  SUPABASE_URL: z.string().url(),
  SUPABASE_ANON_KEY: z.string().min(20),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(20),
  CORS_ORIGINS: z.string().default(''),
});

const parsed = envSchema.safeParse(process.env);
if (!parsed.success) {
  const issues = parsed.error.issues
    .map((i) => `${i.path.join('.')}: ${i.message}`)
    .join('; ');
  console.error(`[config] Invalid environment — ${issues}`);
  process.exit(1);
}

export const env = parsed.data;

/** Allowed browser origins for CORS (comma-separated list). */
export const corsOrigins = env.CORS_ORIGINS.split(',')
  .map((o) => o.trim())
  .filter(Boolean);

/**
 * Service-role client — full database access, bypasses RLS.
 * Used for every data operation; role checks happen in the API middleware.
 */
export const admin = createClient(
  env.SUPABASE_URL,
  env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { autoRefreshToken: false, persistSession: false } },
);

/**
 * Anonymous client — used only for the password grant (login) and refresh,
 * exactly like a browser would. No service privileges.
 */
export const authClient = createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

/** Pagination defaults shared by all list endpoints. */
export const PAGINATION = { defaultLimit: 20, maxLimit: 100 };
