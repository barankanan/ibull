param(
    [string]$AppVersion = "1.0.0",
    [switch]$SkipHostingStage
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$distBridgeDir = Join-Path $scriptRoot "dist\bridge"
$distInstallerDir = Join-Path $scriptRoot "dist\installer"
$innoScript = Join-Path $scriptRoot "installer\IbulPrintBridgeSetup.iss"
$bridgeExeBuildScript = Join-Path $scriptRoot "build_bridge_exe.ps1"

Push-Location $scriptRoot
try {
    Write-Host "[1/4] Building bridge executable..."
    & $bridgeExeBuildScript -AppVersion $AppVersion

    if (!(Test-Path $distInstallerDir)) { New-Item -ItemType Directory -Path $distInstallerDir -Force | Out-Null }

    Write-Host "[2/4] Building standalone bridge installer (backup/internal)..."
    $innoCompiler = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
    if (!(Test-Path $innoCompiler)) {
        $innoCompiler = "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
    }
    if (!(Test-Path $innoCompiler)) {
        throw "Inno Setup compiler not found. Install Inno Setup 6 first."
    }

    & $innoCompiler "/DAppVersion=$AppVersion" $innoScript

    $installerExe = Join-Path $distInstallerDir "IbulPrintBridgeSetup.exe"
    if (!(Test-Path $installerExe)) {
        throw "Installer build failed: $installerExe"
    }

    if (!$SkipHostingStage) {
        Write-Host "[3/4] Staging bridge-only installer as internal backup..."
        $repoRoot = Split-Path -Parent (Split-Path -Parent $scriptRoot)
        $downloadsDir = Join-Path $repoRoot "build\web\downloads"
        if (!(Test-Path $downloadsDir)) {
            New-Item -ItemType Directory -Path $downloadsDir -Force | Out-Null
        }
        Copy-Item $installerExe (Join-Path $downloadsDir "IbulPrintBridgeSetup.exe") -Force
    } else {
        Write-Host "[3/4] Skipping Firebase staging (use unified IbulSellerSetup.exe for hosting)."
    }

    Write-Host "[4/4] Done."
    Write-Host "Bridge EXE:      $distBridgeDir\IbulPrintBridge.exe"
    Write-Host "Installer EXE:   $installerExe"
    Write-Host "Primary hosting: build/web/downloads/IbulSellerSetup.exe (scripts/build_seller_desktop_windows.ps1)"
} finally {
    Pop-Location
}
