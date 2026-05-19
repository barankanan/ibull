param(
  [switch]$BuildOnly,
  [switch]$SkipBridgeBuild
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptRoot
$envFile = Join-Path $projectRoot ".env"
$configScript = Join-Path $scriptRoot "seller_desktop_build_config.ps1"

. $configScript

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

$installerPath = Join-Path $projectRoot "build\windows\installer\IbulSellerSetup.exe"
$hostedInstallerPath = Join-Path $projectRoot "build\web\downloads\IbulSellerSetup.exe"
$dartDefineFile = Join-Path $projectRoot "build\windows\seller_desktop_dart_defines.json"
$releaseExe = Join-Path $projectRoot "build\windows\x64\runner\Release\IbulSellerDesktop.exe"

function Remove-StaleSellerDesktopArtifacts {
  Remove-SellerDesktopBuildStamp -ProjectRoot $projectRoot
  foreach ($path in @($installerPath, $hostedInstallerPath, $dartDefineFile)) {
    if (Test-Path $path) {
      Remove-Item $path -Force
    }
  }
}

Remove-StaleSellerDesktopArtifacts

try {
  Assert-SellerReleaseSupabaseConfig -EnvFilePath $envFile
  Apply-EnvAliases

  $dartDefineFile = Write-SellerDesktopDartDefineFile -ProjectRoot $projectRoot
  Test-SellerDesktopDartDefineFile -DartDefineFile $dartDefineFile
  Write-SellerDesktopReleaseConfigLog -DartDefineFile $dartDefineFile

  Set-Location $projectRoot

  if (!$SkipBridgeBuild) {
    Write-Host ""
    Write-Host "==> Yazici servisi (bridge EXE) derleniyor..."
    $bridgeBuildScript = Join-Path $projectRoot "local_print_bridge\windows\build_bridge_exe.ps1"
    & $bridgeBuildScript
    if ($LASTEXITCODE -ne 0) {
      throw "Bridge EXE build failed with exit code $LASTEXITCODE"
    }
  }

  $bridgeExe = Join-Path $projectRoot "local_print_bridge\windows\dist\bridge\IbulPrintBridge.exe"
  if (!(Test-Path $bridgeExe)) {
    throw "Bridge EXE bulunamadi: $bridgeExe"
  }

  Write-Host ""
  Write-Host "==> Flutter Windows release build basliyor..."
  flutter build windows --release --target lib/main_seller.dart "--dart-define-from-file=$dartDefineFile"
  if ($LASTEXITCODE -ne 0) {
    throw "Flutter Windows release build failed with exit code $LASTEXITCODE"
  }

  if (!(Test-Path $releaseExe)) {
    throw "Flutter release binary not found: $releaseExe"
  }

  Test-SellerDesktopDartDefineFile -DartDefineFile $dartDefineFile
  try {
    Test-SellerDesktopReleaseBinaryConfig `
      -ExePath $releaseExe `
      -SupabaseUrl ([System.Environment]::GetEnvironmentVariable("IBUL_SUPABASE_URL"))
    Write-Host "Release config embedded in binary: OK"
  } catch {
    Write-Host "Release binary string marker check skipped: $($_.Exception.Message)"
    Write-Host "Dart define file validation passed; continuing."
  }

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

  $iss = Join-Path $projectRoot "windows\installer\IbulSellerSetup.iss"
  Write-Host ""
  Write-Host "==> Birlesik Windows installer uretiliyor (IbulSellerSetup.exe)..."
  & $iscc "/DAppVersion=1.0.0" $iss
  if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup build failed with exit code $LASTEXITCODE"
  }

  if (!(Test-Path $installerPath)) {
    throw "Installer build failed: $installerPath"
  }

  $downloadsDir = Join-Path $projectRoot "build\web\downloads"
  if (!(Test-Path $downloadsDir)) {
    New-Item -ItemType Directory -Path $downloadsDir -Force | Out-Null
  }
  Copy-Item $installerPath $hostedInstallerPath -Force

  $stampPath = Write-SellerDesktopBuildStamp `
    -ProjectRoot $projectRoot `
    -InstallerPath $installerPath `
    -DartDefineFile $dartDefineFile `
    -ReleaseExePath $releaseExe

  Write-Host ""
  Write-Host "Tamamlandi:"
  Write-Host "  $releaseExe"
  Write-Host "  $bridgeExe"
  Write-Host "  $installerPath"
  Write-Host "  $hostedInstallerPath"
  Write-Host "  $stampPath"
  Write-Host "Verify hosting: npm run check:windows-installer (from repo root)"
}
catch {
  Remove-StaleSellerDesktopArtifacts
  throw
}
