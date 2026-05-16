param(
  [switch]$BuildOnly
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptRoot
$envFile = Join-Path $projectRoot ".env"

function Load-DotEnv {
  param([string]$Path)
  if (!(Test-Path $Path)) {
    throw ".env dosyasi bulunamadi: $Path"
  }
  Get-Content $Path | ForEach-Object {
    $line = $_.Trim()
    if ($line.Length -eq 0 -or $line.StartsWith("#")) {
      return
    }
    $parts = $line.Split("=", 2)
    if ($parts.Length -ne 2) {
      return
    }
    [System.Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim())
  }
}

function Assert-Env {
  param([string[]]$Names)
  $missing = @()
  foreach ($name in $Names) {
    if ([string]::IsNullOrWhiteSpace([System.Environment]::GetEnvironmentVariable($name))) {
      $missing += $name
    }
  }
  if ($missing.Count -gt 0) {
    throw "Eksik ortam degiskenleri: $($missing -join ', ')"
  }
}

function Apply-EnvAliases {
  $windowsSellerUrl = [System.Environment]::GetEnvironmentVariable("IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL")
  $windowsLegacyUrl = [System.Environment]::GetEnvironmentVariable("IBUL_WINDOWS_INSTALLER_DOWNLOAD_URL")
  if ([string]::IsNullOrWhiteSpace($windowsSellerUrl) -and ![string]::IsNullOrWhiteSpace($windowsLegacyUrl)) {
    [System.Environment]::SetEnvironmentVariable("IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL", $windowsLegacyUrl)
  }

  $macSellerUrl = [System.Environment]::GetEnvironmentVariable("IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL")
  $macLegacyUrl = [System.Environment]::GetEnvironmentVariable("IBUL_MACOS_INSTALLER_DOWNLOAD_URL")
  if ([string]::IsNullOrWhiteSpace($macSellerUrl) -and ![string]::IsNullOrWhiteSpace($macLegacyUrl)) {
    [System.Environment]::SetEnvironmentVariable("IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL", $macLegacyUrl)
  }
}

function Add-DartDefineArgs {
  param([string[]]$Names)
  $args = @()
  foreach ($name in $Names) {
    $value = [System.Environment]::GetEnvironmentVariable($name)
    if (![string]::IsNullOrWhiteSpace($value)) {
      $args += "--dart-define=$name=$value"
    }
  }
  return $args
}

if (Test-Path $envFile) {
  Load-DotEnv -Path $envFile
} else {
  Write-Host ".env bulunamadi, mevcut ortam degiskenleri kullanilacak."
}
Apply-EnvAliases
Assert-Env -Names @("IBUL_SUPABASE_URL", "IBUL_SUPABASE_ANON_KEY")

$dartDefines = Add-DartDefineArgs -Names @(
  "IBUL_SUPABASE_URL",
  "IBUL_SUPABASE_ANON_KEY",
  "IBUL_GOOGLE_CLIENT_ID",
  "IBUL_GOOGLE_SERVER_CLIENT_ID",
  "IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL",
  "IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL"
)

Set-Location $projectRoot

Write-Host ""
Write-Host "==> Flutter Windows build basliyor..."
flutter build windows --release --target lib/main_seller.dart @dartDefines

if ($BuildOnly) {
  Write-Host "Build-only tamamlandi."
  exit 0
}

$isccCandidates = @(
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
  "ISCC.exe"
)

$iscc = $null
foreach ($candidate in $isccCandidates) {
  if (Test-Path $candidate) {
    $iscc = $candidate
    break
  }
}

if ($null -eq $iscc) {
  throw "Inno Setup bulunamadi. ISCC.exe kurulu olmali."
}

$iss = Join-Path $projectRoot "windows\installer\IbulSellerDesktopSetup.iss"
Write-Host ""
Write-Host "==> Windows installer uretiliyor..."
& $iscc "/DAppVersion=1.0.0" $iss

Write-Host ""
Write-Host "Tamamlandi:"
Write-Host "  build\windows\x64\runner\Release\IbulSellerDesktop.exe"
Write-Host "  build\windows\installer\IbulSellerDesktopSetup.exe"
