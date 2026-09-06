# MediGram API (Railway backend)

Express API that owns **all** Supabase access for the MediGram platform.
The Flutter client talks only to this API — it holds no Supabase keys.

## Run locally

```powershell
# 1. credentials — either copy ../supabase/server.env values into .env ...
Copy-Item .env.example .env   # then fill in the real keys

# 2. install + start
npm install
npm start                     # listens on :4000

# 3. verify (Gates V2 + V3) — needs supabase/schema.sql applied first
npm run smoke
```

## Deploy to Railway

1. Push this repo to GitHub (backend/.env is git-ignored automatically).
2. Railway → **New Project** → *Deploy from GitHub repo* → select the repo.
3. **Settings → Root Directory**: `backend`.
4. **Variables** — add:
   - `SUPABASE_URL` = `https://gaeuarvzqmgdmfkqjhg.supabase.co`
   - `SUPABASE_SERVICE_ROLE_KEY` = value from `supabase/server.env`
   - `SUPABASE_ANON_KEY` = value from `supabase/server.env`
   - `CORS_ORIGINS` = `https://<your-app>.vercel.app,http://localhost:3000`
5. **Settings → Networking → Generate Domain** → note the public URL
   (e.g. `https://medigram-api.up.railway.app`).
6. Re-run the smoke tests against production:
   `powershell -File scripts/smoke-test.ps1 -ApiBase https://medigram-api.up.railway.app`

## Security model

- Service-role key never leaves this server; the browser only ever sees JWTs.
- Every route is guarded: `requireAuth` (JWT + profile) → `requireRole`.
- zod validates every body/query/params; errors use the
  `{ "error": { "code", "message" } }` envelope.
- Rate limits: 100 req / 15 min on `/auth`, 300 req / 15 min elsewhere.
- Database RLS + guarded RPCs remain as defense-in-depth behind the API.
