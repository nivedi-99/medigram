# Deploying MediGram to Vercel

## LIVE STATUS (deployed)

| Layer | URL |
|---|---|
| **Frontend (Flutter web)** | https://medigram-seven.vercel.app |

> NOTE: https://medigram-export.vercel.app belongs to a DIFFERENT Vercel
> account (team `unicorn23` has no access) and is NOT updated by this
> workflow. Production for this project is always medigram-seven.vercel.app.
| **Backend (Railway)** | https://medigram-api-production.up.railway.app |
| **Database (Supabase)** | project ref `hcoperadzsrcpkftetug` (ap-south-1) |

Production verification: **27/27 smoke checks GREEN against the live
Railway URL**, CORS preflight from the Vercel origin returns 204 + the
`access-control-allow-origin` header, and disallowed origins get 403.

## Redeploying the frontend

The Vercel project is named **`medigram-export`** (the plain `medigram`
name is globally taken by another Vercel user).

```powershell
flutter build web --release
cd build\web
$tok = (Select-String -Path '..\..\..\deploy\vercel.env' -Pattern '^VERCEL_TOKEN=(.+)$').Matches[0].Groups[1].Value
vercel link --yes --project medigram-export --token $tok   # once per checkout
vercel deploy --prod --yes --token $tok
```

## Redeploying the backend (Railway)

Deploy from the clean path `C:\Users\nived\medigram-deploy` (the CLI fails
on paths containing spaces/parentheses):

```powershell
# refresh the deploy copy from the repo
Remove-Item C:\Users\nived\medigram-deploy -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory C:\Users\nived\medigram-deploy | Out-Null
Copy-Item 'c:\Users\nived\Downloads\medigram_app (1)\medigram_app\backend\*' C:\Users\nived\medigram-deploy\ -Recurse -Exclude node_modules

cd C:\Users\nived\medigram-deploy
railway up --detach --yes
railway status        # wait for ● Online
```

## Full production verification

```powershell
cd backend
powershell -ExecutionPolicy Bypass -File scripts\smoke-test.ps1 `
  -ApiBase https://medigram-api-production.up.railway.app
```

## Security notes

- `deploy/vercel.env` and `supabase/server.env` are excluded from git.
- If a token/secret is ever exposed, revoke it immediately:
  - Vercel: Dashboard → Settings → Tokens → Delete
  - Railway: railway.com/account/tokens → delete
  - Supabase: Dashboard → Settings → API → Reset service role key
