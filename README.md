# MediGram — Global Pharmaceutical Export Platform (B2B)

A Flutter web frontend + Express API + Supabase database, built **bottom-up**
with hard verification gates:

```
Flutter web (Vercel) ──HTTPS/JWT──► Express API (Railway) ──service-role──► Supabase
```

| Layer | Milestone | Gate | How to verify |
|---|---|---|---|
| Database | M1 | V1 | Run [`supabase/schema.sql`](supabase/schema.sql), then [`supabase/verify.sql`](supabase/verify.sql) in the Supabase SQL Editor — must print `ALL CHECKS PASSED — GATE V1 GREEN` |
| Backend | M2 | V2 | `cd backend && npm install && npm start` then `npm run smoke` — security section green |
| Pipelines | M3 | V3 | Same smoke run — E2E section green, exit code 0 |
| Frontend | M4 | V4 | Only started after V1–V3 are green |

## Roles

| Role | Lands on | Capabilities |
|---|---|---|
| **Client** | Client portal | Browse catalogue, place export orders (once KYC-verified), manage profile |
| **Admin** | Admin Console | Verify/reject B2B clients, fulfil orders, curate catalogue |
| **Super Admin** | Super Admin Console | Everything + promote/demote admins, role stats |

## Data pipelines (all DB-triggered, verified by Gate V3)

- **P1 Signup** — auth user → `profiles` row (role=client) → `client_profiles` (pending KYC) → welcome notification
- **P2 KYC** — admin verifies → status + `verified_at` → client notified
- **P3 Orders** — verified-client guard (API **and** DB trigger) → server-side pricing/MOQ → totals auto-computed
- **P4 Fulfilment** — legal status transitions only (processing→shipped→delivered) → client notified
- **P5 Admin mgmt** — guarded RPCs; role column is never directly writable
- **P6 Sessions** — JWT access/refresh; 401 → refresh → single retry
- **P7 Catalogue** — admins write, clients see active-only, soft delete only

## Setup

1. **Database** — apply `supabase/schema.sql` in the SQL Editor → run `supabase/verify.sql` (Gate V1)
2. **Backend** — see [`backend/README.md`](backend/README.md): `npm install && npm start`, then `npm run smoke` (Gates V2+V3)
3. **First super admin** — register via `POST /api/v1/auth/signup`, then in the SQL Editor:
   `select public.promote_to_super_admin('owner@yourdomain.com');`
4. **Frontend (M4)** — starts only after all gates are green

## Security model

- The Flutter app holds **no** Supabase keys; the service-role key lives only
  in Railway env vars (locally: `supabase/server.env`, git-ignored).
- Role checks: API middleware (primary) + RLS & guarded RPCs (defense-in-depth).
- The `profiles.role` column is not writable by users (column-level grants).

## Project layout

```
supabase/   schema.sql · verify.sql (Gate V1) · reset.sql · server.env (git-ignored)
backend/    Express API (Railway) — server.js, src/routes, scripts/smoke-test.ps1 (Gates V2/V3)
lib/        Flutter app (rewiring deferred until M1-M3 verified)
deploy/     vercel.env (git-ignored) · README.md
web/        index.html (branded loading screen, SEO meta)
```
