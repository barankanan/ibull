param(
    [string]$AppVersion = "1.0.0"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$bridgeRoot = Split-Path -Parent $scriptRoot

$venvDir = Join-Path $scriptRoot ".venv-build"
$distBridgeDir = Join-Path $scriptRoot "dist\bridge"
$distInstallerDir = Join-Path $scriptRoot "dist\installer"
$workDir = Join-Path $scriptRoot "build_pyinstaller"
$entryPoint = Join-Path $scriptRoot "bridge_entry.py"
$specFile = Join-Path $scriptRoot "IbulPrintBridge.spec"
$innoScript = Join-Path $scriptRoot "installer\IbulPrintBridgeSetup.iss"

if (!(Test-Path $entryPoint)) {
    throw "Entry point not found: $entryPoint"
}
if (!(Test-Path $specFile)) {
    throw "PyInstaller spec not found: $specFile"
}

Push-Location $scriptRoot
try {
    Write-Host "[1/6] Preparing build folders..."
    if (Test-Path $distBridgeDir) { Remove-Item $distBridgeDir -Recurse -Force }
    if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force }
    if (!(Test-Path $distInstallerDir)) { New-Item -ItemType Directory -Path $distInstallerDir -Force | Out-Null }

    Write-Host "[2/6] Preparing Python build environment..."
    if (!(Test-Path $venvDir)) {
        py -3 -m venv $venvDir
    }
    $python = Join-Path $venvDir "Scripts\python.exe"

    & $python -m pip install --upgrade pip
    & $python -m pip install -r (Join-Path $bridgeRoot "requirements.txt")
    & $python -m pip install pyinstaller

    Write-Host "[3/6] Building standalone bridge executable..."
    & $python -m PyInstaller `
        --noconfirm `
        --clean `
        --distpath $distBridgeDir `
        --workpath $workDir `
        $specFile

    Write-Host "[4/6] Copying runtime defaults..."
    Copy-Item (Join-Path $bridgeRoot ".env.example") (Join-Path $distBridgeDir ".env.example") -Force

    Write-Host "[5/6] Building installer..."
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

    Write-Host "[6/7] Staging installer for Firebase hosting..."
    $repoRoot = Split-Path -Parent (Split-Path -Parent $scriptRoot)
    $downloadsDir = Join-Path $repoRoot "build\web\downloads"
    if (!(Test-Path $downloadsDir)) {
        New-Item -ItemType Directory -Path $downloadsDir -Force | Out-Null
    }
    Copy-Item $installerExe (Join-Path $downloadsDir "IbulPrintBridgeSetup.exe") -Force

    Write-Host "[7/7] Done."
    Write-Host "Bridge EXE:      $distBridgeDir\IbulPrintBridge.exe"
    Write-Host "Installer EXE:   $installerExe"
    Write-Host "Hosted copy:     $downloadsDir\IbulPrintBridgeSetup.exe"
    Write-Host "Verify hosting:  npm run check:windows-installer (from repo root)"
} finally {
    Pop-Location
}
