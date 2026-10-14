# backfill-image-urls.ps1 - record uploaded product photos in the
# products.image_url column (PostgREST DML - no DDL).
#
#   powershell -File backend/scripts/backfill-image-urls.ps1
#
# Steps:
#   1. Reads SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY from backend/.env
#      (keys are never printed).
#   2. Probes whether products.image_url exists. If missing, prints the
#      exact SQL Editor steps and exits (the column needs DDL, which the
#      service key cannot run by design).
#   3. Lists product-images/products/* storage objects and PATCHes each
#      product's image_url to its canonical public URL.
#   4. Verifies the rows and spot-checks one image URL end-to-end.
#
# All Supabase calls go through curl --resolve because local DNS often
# cannot resolve *.supabase.co; the IP comes from DNS-over-HTTPS.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$envPath = Join-Path $repoRoot 'backend\.env'
if (-not (Test-Path $envPath)) { throw "missing $envPath" }

$envMap = @{}
Get-Content $envPath | ForEach-Object {
  if ($_ -match '^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$') {
    $envMap[$Matches[1]] = $Matches[2].Trim('"', "'")
  }
}
$rawUrl = $envMap['SUPABASE_URL']
$url = if ($rawUrl) { $rawUrl.TrimEnd('/') } else { '' }
$key = $envMap['SUPABASE_SERVICE_ROLE_KEY']
if (-not $url -or -not $key) { throw 'SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY missing in backend/.env' }
$ref = ([Uri]$url).Host

$do = Invoke-RestMethod "https://dns.google/resolve?name=$ref&type=A" -TimeoutSec 30
$ip = ($do.Answer | Where-Object type -eq 1 | Select-Object -First 1).data
if (-not $ip) { throw "DoH could not resolve $ref" }
Write-Output "target: $ref ($ip)"

# --- 2. does products.image_url exist? --------------------------------------
$tmp = New-TemporaryFile
$code = & curl.exe -s -o $tmp -w "%{http_code}" --resolve "$ref`:443:$ip" `
  -H "apikey: $key" -H "Authorization: Bearer $key" `
  "$url/rest/v1/products?select=id,image_url&limit=1"
$probe = Get-Content $tmp -Raw
Remove-Item $tmp
if ($code -ne '200') {
  Write-Output "products.image_url is NOT applied yet (HTTP $code): $($probe.Trim())"
  Write-Output ''
  Write-Output 'Apply the migration first (60 seconds):'
  Write-Output '  1. Supabase dashboard -> project hcoperadzsrcpkftetug -> SQL Editor'
  Write-Output '  2. Paste supabase/add_product_images.sql (or just the ALTER TABLE below)'
  Write-Output '  3. Run, then re-run this script.'
  Write-Output ''
  Write-Output 'ALTER TABLE public.products ADD COLUMN IF NOT EXISTS image_url text NOT NULL DEFAULT '''';'
  exit 2
}
Write-Output 'products.image_url column: present'

# --- 3. storage objects -> image_url ----------------------------------------
$listRaw = & curl.exe -s --resolve "$ref`:443:$ip" `
  -H "apikey: $key" -H "Authorization: Bearer $key" `
  -H "Content-Type: application/json" `
  --data '{"prefix":"products/","limit":1000}' `
  "$url/storage/v1/object/list/product-images"
$objects = @($listRaw | ConvertFrom-Json)
$ids = @($objects | ForEach-Object {
  if ($_.name -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$') { $Matches[1] }
} | Select-Object -Unique)
Write-Output "storage objects under products/: $($objects.Count) (product ids: $($ids.Count))"

$rowsRaw = & curl.exe -s --resolve "$ref`:443:$ip" `
  -H "apikey: $key" -H "Authorization: Bearer $key" `
  "$url/rest/v1/products?select=id,image_url"
$rows = @($rowsRaw | ConvertFrom-Json)
$rowById = @{}
foreach ($r in $rows) { $rowById[$r.id] = $r.image_url }

$canonicalBase = "$url/storage/v1/object/public/product-images/products"
$patched = 0; $already = 0; $missingRow = 0
foreach ($id in $ids) {
  if (-not $rowById.ContainsKey($id)) { $missingRow++; continue }
  $canonical = "$canonicalBase/$id"
  $current = $rowById[$id]
  if ($current -eq $canonical) { $already++; continue }
  $body = '{"image_url":' + ($canonical | ConvertTo-Json) + '}'
  $pc = & curl.exe -s -o NUL -w "%{http_code}" -X PATCH `
    --resolve "$ref`:443:$ip" `
    -H "apikey: $key" -H "Authorization: Bearer $key" `
    -H "Content-Type: application/json" -H "Prefer: return=minimal" `
    --data $body "$url/rest/v1/products?id=eq.$id"
  if ($pc -eq '200' -or $pc -eq '204') { $patched++ }
  else { Write-Output "PATCH $id -> HTTP $pc" }
}
Write-Output "backfill: patched=$patched already-ok=$already no-product-row=$missingRow"

# --- 4. verify ---------------------------------------------------------------
$vRaw = & curl.exe -s --resolve "$ref`:443:$ip" `
  -H "apikey: $key" -H "Authorization: Bearer $key" `
  "$url/rest/v1/products?select=id,image_url&image_url=not.eq."
$recorded = @($vRaw | ConvertFrom-Json)
Write-Output "products with image_url recorded: $($recorded.Count)"
if ($recorded.Count -gt 0) {
  $sample = $recorded[0].image_url
  $imgCode = & curl.exe -s -o NUL -w "%{http_code}" --resolve "$ref`:443:$ip" --max-time 45 $sample
  Write-Output "sample image fetch: HTTP $imgCode <- $sample"
}
Write-Output 'done.'
