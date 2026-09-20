# Extracts products from mymedicinemart.com (public product pages + REST API)
# into tool/mmm-products.json and downloads each product picture into
# web/assets/products/labels/<slug>.png (the exact path the app's cards load).
#
# Usage:  powershell -ExecutionPolicy Bypass -File tool\extract-mmm.ps1 [-Count 24]
param([int]$Count = 24)

$ErrorActionPreference = 'Continue'
$ua   = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36'
$base = 'https://mymedicinemart.com'
$imgDir = Join-Path $PSScriptRoot '..\web\assets\products\labels'
New-Item -ItemType Directory -Force $imgDir | Out-Null

$j = curl.exe -s -A $ua "$base/wp-json/wp/v2/product?per_page=100&page=1"
$batch = ($j | ConvertFrom-Json) | Select-Object -First $Count
Write-Output "fetched $($batch.Count) products from REST API (batch cap $Count)"

$results = @()
$i = 0
foreach ($p in $batch) {
  $i++
  $name = ($p.title.rendered -replace '&amp;', '&').Trim()
  $slug = ($name.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')

  $html = (curl.exe -s -A $ua $p.link) -join ''
  $text = $html -replace '(?s)<script.*?</script>', ' ' `
                -replace '(?s)<style.*?</style>', ' ' `
                -replace '<[^>]+>', "`n" `
                -replace '&amp;', '&' -replace '&#038;', '&' -replace '&#8211;', '-' `
                -replace '\s+', ' '

  $price  = [regex]::Match($text, 'Add to Cart[^$]*?\$([0-9][0-9,]*(?:\.[0-9]+)?)').Groups[1].Value
  $generic = [regex]::Match($text, '([A-Z][A-Za-z-]+(?:\s+\d+(?:\.\d+)?\s*mg)?)\s+Strengths').Groups[1].Value.Trim()
  if (-not $generic) {
    $generic = [regex]::Match($text, 'contains\s+(?:two active ingredients,\s*)?([^.]+\bmg\b[^.]*?)\.').Groups[1].Value.Trim()
  }
  $packing = [regex]::Match($text, 'Packaging Size\s+([A-Za-z0-9 ./x-]+?)\s+Packaging Type').Groups[1].Value.Trim()
  $mfrRaw  = [regex]::Match($text, 'Manufacturer\s+([^\n]+)').Groups[1].Value
  $mfr     = (($mfrRaw -split ' Add to Cart')[0]).Trim()
  $desc    = [regex]::Match($text, [regex]::Escape("About $name") + '\s+([^\n]+)').Groups[1].Value.Trim()
  if ($desc.Length -gt 300) { $desc = $desc.Substring(0, 297) + '...' }

  # first real product photo on the detail page (skip logos/icons/svg)
  $img = ''
  foreach ($m in [regex]::Matches($html, 'https://[^\s"''<>]+?/wp-content/uploads/[^"''<> ]+?\.(?:jpg|jpeg|png|webp)')) {
    if ($m.Value -notmatch 'logo|icon|sprite|flag') { $img = $m.Value; break }
  }

  if ($img) {
    curl.exe -s -A $ua -o (Join-Path $imgDir "$slug.png") $img | Out-Null
  }

  $results += [pscustomobject]@{
    name         = $name
    slug         = $slug
    price        = [double]($price -replace ',', '')
    generic      = $generic
    packing      = $packing
    manufacturer = $mfr
    description  = $desc
    image        = $img
    link         = $p.link
  }
  Write-Output ("{0,3}. {1}  |`$ {2} | img: {3}" -f $i, $name, $price, ($(if ($img) { 'yes' } else { 'NO' })))
}

$out = Join-Path $PSScriptRoot 'mmm-products.json'
$results | ConvertTo-Json -Depth 4 | Set-Content $out -Encoding UTF8
Write-Output "saved $($results.Count) products -> $out"
