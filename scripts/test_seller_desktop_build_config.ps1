$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot "seller_desktop_build_config.ps1")

$env:IBUL_SUPABASE_URL = ""
$env:IBUL_SUPABASE_ANON_KEY = ""

$failed = $false
try {
  Assert-SellerReleaseSupabaseConfig -EnvFilePath (Join-Path $scriptRoot "nonexistent.env")
} catch {
  if ($_.Exception.Message -notmatch "Supabase config missing for seller desktop release build") {
    throw
  }
  $failed = $true
}

if (-not $failed) {
  throw "Expected Supabase config missing failure."
}

$tempRoot = Join-Path $env:TEMP "ibul-seller-build-config-test"
if (Test-Path $tempRoot) {
  Remove-Item $tempRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
$env:IBUL_SUPABASE_URL = "https://example.supabase.co"
$env:IBUL_SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test"
$dartFile = Write-SellerDesktopDartDefineFile -ProjectRoot $tempRoot
Test-SellerDesktopDartDefineFile -DartDefineFile $dartFile
$bytes = [System.IO.File]::ReadAllBytes($dartFile)
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
  throw "Dart define file must be UTF-8 without BOM."
}

Write-Host "PASS: seller desktop build config guard"
