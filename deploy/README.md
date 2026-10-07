# Deploying MediGram

## LIVE STATUS (deployed)

| Layer | URL |
|---|---|
| **Frontend (Flutter web)** | https://medigram-seven.vercel.app |
| **Backend (Render)** | https://medigram-api.onrender.com |
| **Database (Supabase)** | project ref `hcoperadzsrcpkftetug` (ap-south-1) |

> NOTE: https://medigram-export.vercel.app belongs to a DIFFERENT Vercel
> account and is NOT updated by this workflow. Production for this project
> is always medigram-seven.vercel.app.
>
> The backend moved from Railway (trial expired, service removed) to Render
> (web service `medigram-api`, service id srv-db32l9gm7kps73cqeqkg). The old
> Railway URL medigram-api-production.up.railway.app is retired.

## Redeploying the frontend

The Vercel project is named **`medigram-export`** (the plain `medigram`
name is globally taken by another Vercel user).

```powershell
flutter build web --release
cd build\web
$env:CI = 'true'   # keeps the Vercel CLI non-interactive (skips its upgrade prompt)
$tok = (Select-String -Path '..\..\deploy\vercel.env' -Pattern '^VERCEL_TOKEN=(.+)$').Matches[0].Groups[1].Value
vercel link --yes --project medigram-export --token $tok   # once per checkout
vercel deploy --prod --yes --token $tok
```

## Redeploying the backend (Render)

The Render web service **auto-deploys from GitHub**: every push to
`master` on nivedi-99/medigram triggers a new deploy (backend lives in
`rootDir: backend`). Verify with:

```powershell
curl https://medigram-api.onrender.com/api/v1/health
curl "https://medigram-api.onrender.com/api/v1/products?limit=1"
```

Manual deploy trigger via the Render API (if ever needed):

```powershell
$tok = 'rnd_...'   # Render API key (dashboard -> Account Settings -> API Keys)
curl.exe -s -X POST "https://api.render.com/v1/services/srv-db32l9gm7kps73cqeqkg/deploys" `
  -H "Authorization: Bearer $tok" -H "Accept: application/json"
```

Backend environment variables live in the Render dashboard
(medigram-api -> Environment): NODE_ENV=production, SUPABASE_URL,
SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY, CORS_ORIGINS (must include
https://medigram-seven.vercel.app). The server binds to Render's injected
PORT automatically; health check path is /api/v1/health.

## Free-tier caveat

The Render free instance spins down after ~15 minutes idle. The first
request after idle takes ~50 seconds (cold start) — sign-in may feel slow
once in a while. The Starter plan ($7/mo) keeps the service always on.

## Security notes

- `deploy/vercel.env` and `supabase/server.env` are excluded from git.
- If a token/secret is ever exposed, revoke it immediately:
  - Vercel: Dashboard → Settings → Tokens → Delete
  - Render: Account Settings → API Keys → Delete (rotate the key shared
    during the migration)
  - Supabase: Dashboard → Settings → API → Reset service role key
