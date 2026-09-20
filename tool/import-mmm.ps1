# Imports tool/mmm-products.json into the Supabase `products` table.
# Skips products whose name already exists (safe to re-run).
# Usage:  powershell -ExecutionPolicy Bypass -File tool\import-mmm.ps1
$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..'
$items = Get-Content (Join-Path $PSScriptRoot 'mmm-products.json') -Raw | ConvertFrom-Json

$envFile = Get-Content (Join-Path $root 'backend\.env')
$url  = ($envFile | Select-String '^SUPABASE_URL=(.+)$').Matches[0].Groups[1].Value.Trim()
$skey = ($envFile | Select-String '^SUPABASE_SERVICE_ROLE_KEY=(.+)$').Matches[0].Groups[1].Value.Trim()
$ip   = (Resolve-DnsName 'hcoperadzsrcpkftetug.supabase.co' -Server 1.1.1.1 -Type A -ErrorAction SilentlyContinue |
         Select-Object -First 1).IPAddress
if (-not $ip) { throw 'could not resolve Supabase host' }

$ProgressPreference = 'SilentlyContinue'
$existing = (curl.exe -s --resolve "hcoperadzsrcpkftetug.supabase.co:443:$ip" `
  "$url/rest/v1/products?select=name" -H "apikey: $skey" -H "Authorization: Bearer $skey") |
  ConvertFrom-Json
$existingNames = @($existing | ForEach-Object { $_.name })
Write-Output "existing products in DB: $($existingNames.Count)"

$rows = @()
foreach ($m in $items) {
  if ($existingNames -contains $m.name) {
    Write-Output "skip (exists): $($m.name)"
    continue
  }
  $desc = (($m.generic, $m.description) | Where-Object { $_ -and $_.Trim() }) -join ' | '
  $rows += @{
    name          = $m.name
    category      = 'Pharmaceutical tablets'
    manufacturer  = $m.manufacturer
    description   = $desc
    price         = [math]::Round($m.price, 2)
    currency      = 'USD'
    min_order_qty = 10
    is_active     = $true
  }
}

if ($rows.Count -eq 0) { Write-Output 'nothing new to import.'; exit 0 }

$jsonFile = Join-Path $PSScriptRoot 'insert-rows.json'
ConvertTo-Json @($rows) -Depth 5 | Set-Content $jsonFile -Encoding UTF8

$code = curl.exe -s -o NUL -w "%{http_code}" --resolve "hcoperadzsrcpkftetug.supabase.co:443:$ip" `
  -X POST "$url/rest/v1/products" `
  -H "apikey: $skey" -H "Authorization: Bearer $skey" `
  -H 'Content-Type: application/json' -H 'Prefer: return=minimal' `
  -d "@$jsonFile"
Write-Output "insert: $code ($($rows.Count) rows)"

# verify
$after = (curl.exe -s --resolve "hcoperadzsrcpkftetug.supabase.co:443:$ip" `
  "$url/rest/v1/products?select=name" -H "apikey: $skey" -H "Authorization: Bearer $skey") |
  ConvertFrom-Json
Write-Output "products in DB now: $(@($after).Count)"
