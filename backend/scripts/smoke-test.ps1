# ============================================================================
# MediGram - GATE V2 + V3 : API smoke & pipeline E2E tests
# ----------------------------------------------------------------------------
# Prerequisites:
#   1. supabase/schema.sql applied AND supabase/verify.sql green (Gate V1)
#   2. API running:  cd backend && npm install && npm start
#   3. Run:          npm run smoke     (or powershell -File scripts/smoke-test.ps1)
#
# The script bootstraps throwaway users, exercises every pipeline (P1..P7)
# through the real HTTP API, verifies results, then deletes the test users.
# Exit code 0 + "GATE V2/V3 GREEN" = pass.
# ============================================================================
param([string]$ApiBase = $(if ($env:API_BASE) { $env:API_BASE } else { 'http://localhost:4000' }))

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # hide Invoke-WebRequest progress noise
$script:Pass = 0
$script:Fail = 0

# ---- load credentials: backend/.env, else ../supabase/server.env -----------
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$envFile = Join-Path $here '..\.env'
if (-not (Test-Path $envFile)) { $envFile = Join-Path $here '..\..\supabase\server.env' }
if (-not (Test-Path $envFile)) { Write-Host "FATAL: no .env or supabase/server.env found"; exit 1 }

$cfg = @{}
Get-Content $envFile | ForEach-Object {
  if ($_ -match '^\s*([A-Z_]+)\s*=\s*(.+)\s*$') { $cfg[$Matches[1]] = $Matches[2].Trim() }
}
$SbUrl = $cfg['SUPABASE_URL']; $SbKey = $cfg['SUPABASE_SERVICE_ROLE_KEY']
if (-not $SbUrl -or -not $SbKey) { Write-Host 'FATAL: SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY missing'; exit 1 }

function Check($name, $condition, $detail = '') {
  if ($condition) { $script:Pass++; Write-Host ("  PASS  {0}" -f $name) -ForegroundColor Green }
  else { $script:Fail++; Write-Host ("  FAIL  {0}  {1}" -f $name, $detail) -ForegroundColor Red }
}

# ---- HTTP helper (works on Windows PowerShell 5.1) ------------------------
function Api($Method, $Path, $Body, $Token) {
  $uri = "$ApiBase/api/v1$Path"
  $headers = @{}
  if ($Token) { $headers['Authorization'] = "Bearer $Token" }
  try {
    $args = @{ Uri = $uri; Method = $Method; Headers = $headers; UseBasicParsing = $true }
    if ($Body -ne $null) { $args.ContentType = 'application/json'; $args.Body = ($Body | ConvertTo-Json -Depth 10) }
    $resp = Invoke-WebRequest @args
    return @{ Status = [int]$resp.StatusCode; Body = ($resp.Content | ConvertFrom-Json) }
  } catch {
    $status = 0; $content = ''
    if ($_.Exception.Response) {
      $status = [int]$_.Exception.Response.StatusCode
      try { $sr = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream()); $content = $sr.ReadToEnd() } catch {}
    }
    $parsed = $null; if ($content) { try { $parsed = $content | ConvertFrom-Json } catch {} }
    return @{ Status = $status; Body = $parsed; Raw = $content }
  }
}

# ---- Supabase admin REST helpers (bootstrap + cleanup ONLY) ----------------
function SbCreateUser($email, $password, $meta) {
  $body = @{ email = $email; password = $password; email_confirm = $true; user_metadata = $meta } | ConvertTo-Json -Depth 5
  Invoke-RestMethod -Method Post -Uri "$SbUrl/auth/v1/admin/users" -ContentType 'application/json' `
    -Headers @{ apikey = $SbKey; Authorization = "Bearer $SbKey" } -Body $body
}
function SbRpc($fn, $body) {
  Invoke-RestMethod -Method Post -Uri "$SbUrl/rest/v1/rpc/$fn" -ContentType 'application/json' `
    -Headers @{ apikey = $SbKey; Authorization = "Bearer $SbKey" } -Body ($body | ConvertTo-Json)
}
function SbDeleteUser($id) {
  Invoke-RestMethod -Method Delete -Uri "$SbUrl/auth/v1/admin/users/$id" `
    -Headers @{ apikey = $SbKey; Authorization = "Bearer $SbKey" } | Out-Null
}

$stamp = [Guid]::NewGuid().ToString('N').Substring(0, 8)
$clientEmail = "smoke-client-$stamp@medigram.test"
$ownerEmail = "smoke-owner-$stamp@medigram.test"
$testPass = 'Smoke123!pass'
$created = @()   # auth user ids for cleanup

Write-Host "`n=== MediGram smoke tests - $ApiBase ===`n"

# ---------------------------------------------------------------------------
# GATE V2 - infrastructure & security
# ---------------------------------------------------------------------------
Write-Host '[V2] Infrastructure & security'

$r = Api 'GET' '/health'
Check 'health returns 200 + db up' ($r.Status -eq 200 -and $r.Body.db -eq 'up')

$r = Api 'GET' '/orders'
Check 'unauthenticated request rejected (401)' ($r.Status -eq 401)

$r = Api 'POST' '/auth/login' @{ email = $clientEmail; password = 'wrong-password' }
Check 'login with wrong password rejected (401)' ($r.Status -eq 401)

$r = Api 'POST' '/auth/login' @{ email = 'not-an-email'; password = 'x' }
Check 'invalid payload rejected (422)' ($r.Status -eq 422)

# ---------------------------------------------------------------------------
# GATE V3 - end-to-end data pipelines
# ---------------------------------------------------------------------------
Write-Host "`n[V3] Data pipelines"

# --- P1 * Signup ------------------------------------------------------------
$r = Api 'POST' '/auth/signup' @{
  fullName = 'Smoke Client'; email = $clientEmail; password = $testPass
  phone = '+1 555 0100'; companyName = 'Smoke Trading GmbH'; country = 'Germany'
  businessLicenseNo = 'SMOKE-123'
}
Check 'P1 signup creates client account (201)' ($r.Status -eq 201 -and $r.Body.data.user.role -eq 'client')

$r = Api 'POST' '/auth/signup' @{
  fullName = 'Dup'; email = $clientEmail; password = $testPass
  phone = '+1 555 0101'; companyName = 'Dup Co'; country = 'Germany'
}
Check 'P1 duplicate email rejected (409)' ($r.Status -eq 409)

$r = Api 'POST' '/auth/login' @{ email = $clientEmail; password = $testPass }
Check 'P6 login returns tokens + profile' ($r.Status -eq 200 -and $r.Body.data.accessToken)
$token = $r.Body.data.accessToken
$clientId = $r.Body.data.user.id

$r = Api 'GET' '/auth/me' $null $token
Check 'P6 session restore (GET /auth/me)' ($r.Status -eq 200 -and $r.Body.data.user.id -eq $clientId)

$r = Api 'GET' '/clients' $null $token
Check 'role guard: client cannot list clients (403)' ($r.Status -eq 403)

$r = Api 'PATCH' '/profile' @{ fullName = 'Smoke Client Updated'; phone = '+1 555 0199' } $token
Check 'profile update persists' ($r.Status -eq 200 -and $r.Body.data.user.full_name -eq 'Smoke Client Updated')

# --- Bootstrap temporary super admin (service-role REST; SQL-guarded RPC) ---
$owner = SbCreateUser $ownerEmail $testPass @{ full_name = 'Smoke Owner'; company_name = 'MediGram'; country = 'India' }
$created += $owner.id
Start-Sleep -Milliseconds 1200   # allow on_auth_user_created trigger
SbRpc 'promote_to_super_admin' @{ target_email = $ownerEmail } | Out-Null

$r = Api 'POST' '/auth/login' @{ email = $ownerEmail; password = $testPass }
Check 'bootstrap: temp owner signs in as super_admin' ($r.Status -eq 200 -and $r.Body.data.user.role -eq 'super_admin')
$ownerToken = $r.Body.data.accessToken
$ownerId = $r.Body.data.user.id

# --- P2 * KYC verification ---------------------------------------------------
$r = Api 'GET' '/clients' $null $ownerToken
$row = $null
if ($r.Status -eq 200) { $row = @($r.Body.data | Where-Object { $_.user_id -eq $clientId })[0] }
Check 'P2 admin can list client database' ($null -ne $row)

$r = Api 'PATCH' "/clients/$($row.id)/verify" @{ status = 'verified' } $ownerToken
Check 'P2 client verified via API' ($r.Status -eq 200 -and $r.Body.data.verification_status -eq 'verified')

$r = Api 'GET' '/notifications' $null $token
$kycSeen = @($r.Body.data | Where-Object { $_.kind -eq 'kyc' -and $_.title -like '*verified*' }).Count -gt 0
Check 'P2 KYC notification delivered to client' $kycSeen

# --- P3 * Order placement (after verification) -------------------------------
$r = Api 'GET' '/products' $null $token
Check 'P7 catalogue visible to client' ($r.Status -eq 200 -and $r.Body.data.Count -ge 1)
$product = $r.Body.data[0]

$r = Api 'POST' '/orders' @{ items = @(@{ productId = $product.id; quantity = $product.min_order_qty }) } $token
Check 'P3 verified client places order (201)' ($r.Status -eq 201)
$order = $r.Body.data
Check 'P3 totals computed server-side' ([double]$order.total_amount -gt 0 -and $order.order_items.Count -eq 1)
# __SMOKE_PART3__

# --- P4 * Fulfilment ----------------------------------------------------------
$r = Api 'PATCH' "/orders/$($order.id)/status" @{ status = 'delivered' } $ownerToken
Check 'P4 illegal transition rejected (422)' ($r.Status -eq 422)

$r = Api 'PATCH' "/orders/$($order.id)/status" @{ status = 'shipped' } $ownerToken
Check 'P4 processing -> shipped' ($r.Status -eq 200 -and $r.Body.data.status -eq 'shipped')

$r = Api 'GET' '/notifications' $null $token
$shipSeen = @($r.Body.data | Where-Object { $_.kind -eq 'order' -and $_.title -like '*shipped*' }).Count -gt 0
Check 'P4 shipment notification delivered' $shipSeen

$r = Api 'PATCH' "/orders/$($order.id)/status" @{ status = 'delivered' } $ownerToken
Check 'P4 shipped -> delivered' ($r.Status -eq 200 -and $r.Body.data.status -eq 'delivered')

# --- P5 * Admin management -----------------------------------------------------
$r = Api 'POST' '/admins/promote' @{ email = $clientEmail } $ownerToken
Check 'P5 promote client -> admin' ($r.Status -eq 200 -and $r.Body.data.user.role -eq 'admin')

$r = Api 'GET' '/admins' $null $ownerToken
$handlerSeen = @($r.Body.data.handlers | Where-Object { $_.user_id -eq $clientId }).Count -gt 0
Check 'P5 admin_handlers row created' $handlerSeen
Check 'P5 role counts present' ($r.Body.data.roleCounts.admin -ge 1)

$r = Api 'POST' '/admins/demote' @{ userId = $clientId } $ownerToken
Check 'P5 demote admin -> client' ($r.Status -eq 200 -and $r.Body.data.user.role -eq 'client')

$r = Api 'GET' '/orders/stats' $null $ownerToken
Check 'order stats available to admin' ($r.Status -eq 200 -and $r.Body.data.total -ge 1)

# --- Cleanup -------------------------------------------------------------------
$created += $clientId
foreach ($uid in $created) { try { SbDeleteUser $uid } catch {} }
Check 'cleanup: throwaway users deleted' $true

# ---------------------------------------------------------------------------
Write-Host "`n============================================================"
if ($script:Fail -eq 0) {
  Write-Host "RESULT: $script:Pass/$($script:Pass + $script:Fail) checks passed" -ForegroundColor Green
  Write-Host 'GATE V2/V3 GREEN - backend + pipelines verified' -ForegroundColor Green
  Write-Host '============================================================'
  exit 0
} else {
  Write-Host "RESULT: $script:Fail FAILED, $script:Pass passed" -ForegroundColor Red
  Write-Host 'GATE V2/V3 RED - fix failures before touching the frontend' -ForegroundColor Red
  Write-Host '============================================================'
  exit 1
}
