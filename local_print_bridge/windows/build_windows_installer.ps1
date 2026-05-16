$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

param(
    [string]$AppVersion = "1.0.0"
)

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
        --specpath $workDir `
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

    Write-Host "[6/6] Done."
    Write-Host "Bridge EXE:      $distBridgeDir\IbulPrintBridge.exe"
    Write-Host "Installer EXE:   $distInstallerDir\IbulPrintBridgeSetup.exe"
    Write-Host "Next step: upload the installer to your external release host."
} finally {
    Pop-Location
}
