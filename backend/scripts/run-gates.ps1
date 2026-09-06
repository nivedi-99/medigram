# ============================================================================
# MediGram - run ALL gates in one command (V1 + V2 + V3)
#   powershell -File scripts/run-gates.ps1
#   optional:  -DbUrl postgresql://postgres:PASS@db.<ref>.supabase.co:5432/postgres
#              -ApiBase http://localhost:4000
#
# Prerequisite: DATABASE_URL in backend/.env (or -DbUrl) with the Supabase
# database password. The Supabase project must be ACTIVE (not paused).
# ============================================================================
param(
  [string]$ApiBase = 'http://localhost:4000',
  [string]$DbUrl = $env:DATABASE_URL,
  [string]$Token = $env:SUPABASE_ACCESS_TOKEN,
  [string]$Ref = $env:SUPABASE_PROJECT_REF
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$backend = Join-Path $here '..'
$root = Join-Path $backend '..'

# --- resolve DATABASE_URL from backend/.env --------------------------------
if (-not $DbUrl) {
  $envFile = Join-Path $backend '.env'
  if (Test-Path $envFile) {
    foreach ($line in Get-Content $envFile) {
      if ($line -match '^\s*DATABASE_URL\s*=\s*(.+?)\s*$') { $DbUrl = $Matches[1] }
    }
  }
}

# --- resolve Supabase REST creds for the reachability pre-check ------------
$cfg = @{}
$envFile2 = Join-Path $backend '.env'
if (-not (Test-Path $envFile2)) { $envFile2 = Join-Path $root 'supabase\server.env' }
if (Test-Path $envFile2) {
  foreach ($line in Get-Content $envFile2) {
    if ($line -match '^\s*([A-Z_]+)\s*=\s*(.+?)\s*$') { $cfg[$Matches[1]] = $Matches[2] }
  }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ' MediGram - FULL GATE RUN (V1 database, V2 API, V3 pipelines)' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan

# --- Step 0: project reachability -------------------------------------------
Write-Host "`n[step 0] Supabase project reachability"
if (-not $cfg['SUPABASE_URL']) { Write-Host 'FATAL: SUPABASE_URL missing'; exit 1 }
try {
  Invoke-RestMethod -Uri ($cfg['SUPABASE_URL'] + '/auth/v1/health') -Headers @{ apikey = $cfg['SUPABASE_ANON_KEY'] } -TimeoutSec 15 | Out-Null
  Write-Host '  OK    project is reachable' -ForegroundColor Green
} catch {
  Write-Host ('  FATAL project unreachable: ' + $_.Exception.Message) -ForegroundColor Red
  Write-Host '  -> Restore the project in the Supabase dashboard (it is paused/deleted).' -ForegroundColor Yellow
  Write-Host '     If DNS still fails after restore, get the new URL from Settings > API.' -ForegroundColor Yellow
  exit 1
}

# --- Step 1 + 2: apply schema, then Gate V1 ---------------------------------
if ($Token -and $Ref) {
  # Preferred path: Management API query endpoint (no DB password needed)
  Write-Host "`n[step 1] applying supabase/schema.sql (via Management API)"
  Push-Location $backend
  node (Join-Path $here 'sql-via-api.mjs') $Token $Ref (Join-Path $root 'supabase\schema.sql')
  if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Host 'FATAL: schema failed'; exit 1 }
  Write-Host '  OK    schema applied' -ForegroundColor Green

  Write-Host "`n[step 2] Gate V1 - supabase/verify.sql"
  node (Join-Path $here 'sql-via-api.mjs') $Token $Ref (Join-Path $root 'supabase\verify.sql')
  $v1 = $LASTEXITCODE
  Pop-Location
  if ($v1 -ne 0) { Write-Host 'FATAL: Gate V1 RED - fix database before continuing'; exit 1 }
  Write-Host '  OK    GATE V1 GREEN' -ForegroundColor Green
} elseif ($DbUrl) {
  Write-Host "`n[step 1] applying supabase/schema.sql (via direct Postgres)"
  Push-Location $backend
  node (Join-Path $here 'run-sql.mjs') (Join-Path $root 'supabase\schema.sql') --db-url $DbUrl
  if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Host 'FATAL: schema failed'; exit 1 }
  Write-Host '  OK    schema applied' -ForegroundColor Green

  Write-Host "`n[step 2] Gate V1 - supabase/verify.sql"
  node (Join-Path $here 'run-sql.mjs') (Join-Path $root 'supabase\verify.sql') --db-url $DbUrl
  $v1 = $LASTEXITCODE
  Pop-Location
  if ($v1 -ne 0) { Write-Host 'FATAL: Gate V1 RED - fix database before continuing'; exit 1 }
  Write-Host '  OK    GATE V1 GREEN' -ForegroundColor Green
} else {
  Write-Host "`n[step 1] SKIPPED - no access token and no DATABASE_URL set." -ForegroundColor Yellow
  Write-Host '  Set SUPABASE_ACCESS_TOKEN + SUPABASE_PROJECT_REF (preferred),' -ForegroundColor Yellow
  Write-Host '  or DATABASE_URL in backend/.env, to let this script run the SQL.' -ForegroundColor Yellow
}

# --- Step 3: start API --------------------------------------------------------
Write-Host "`n[step 3] starting API server"
$existing = Get-NetTCPConnection -LocalPort ([Uri]$ApiBase).Port -State Listen -ErrorAction SilentlyContinue
$serverPid = $null
if ($existing) {
  Write-Host '  OK    server already listening'
} else {
  $proc = Start-Process node -ArgumentList 'server.js' -WorkingDirectory $backend -WindowStyle Hidden -PassThru
  $serverPid = $proc.Id
  $healthy = $false
  foreach ($i in 1..15) {
    Start-Sleep -Seconds 1
    try {
      $h = Invoke-RestMethod -Uri ($ApiBase + '/api/v1/health') -TimeoutSec 5
      if ($h.db -eq 'up') { $healthy = $true; break }
    } catch {}
  }
  if (-not $healthy) {
    if ($serverPid) { Stop-Process -Id $serverPid -Force -ErrorAction SilentlyContinue }
    Write-Host 'FATAL: API did not become healthy (schema applied? .env correct?)'; exit 1
  }
  Write-Host "  OK    API healthy (pid $serverPid)" -ForegroundColor Green
}

# --- Step 4: Gates V2 + V3 -----------------------------------------------------
Write-Host "`n[step 4] Gates V2 + V3 - smoke & pipeline tests"
try {
  & (Join-Path $here 'smoke-test.ps1') -ApiBase $ApiBase
  $smoke = $LASTEXITCODE
} finally {
  if ($serverPid) { Stop-Process -Id $serverPid -Force -ErrorAction SilentlyContinue }
}
if ($smoke -ne 0) { Write-Host 'RESULT: GATES RED'; exit 1 }
Write-Host "`nRESULT: ALL GATES GREEN - backend fully verified" -ForegroundColor Green
exit 0
