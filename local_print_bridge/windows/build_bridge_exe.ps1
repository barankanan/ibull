param(
    [string]$AppVersion = "1.0.0"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$bridgeRoot = Split-Path -Parent $scriptRoot

$venvDir = Join-Path $scriptRoot ".venv-build"
$distBridgeDir = Join-Path $scriptRoot "dist\bridge"
$workDir = Join-Path $scriptRoot "build_pyinstaller"
$entryPoint = Join-Path $scriptRoot "bridge_entry.py"
$specFile = Join-Path $scriptRoot "IbulPrintBridge.spec"

if (!(Test-Path $entryPoint)) {
    throw "Entry point not found: $entryPoint"
}
if (!(Test-Path $specFile)) {
    throw "PyInstaller spec not found: $specFile"
}

Push-Location $scriptRoot
try {
    Write-Host "[1/3] Preparing build folders..."
    if (Test-Path $distBridgeDir) { Remove-Item $distBridgeDir -Recurse -Force }
    if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force }

    Write-Host "[2/3] Preparing Python build environment..."
    if (!(Test-Path $venvDir)) {
        py -3 -m venv $venvDir
    }
    $python = Join-Path $venvDir "Scripts\python.exe"

    & $python -m pip install --upgrade pip
    & $python -m pip install -r (Join-Path $bridgeRoot "requirements.txt")
    & $python -m pip install pyinstaller

    Write-Host "[3/3] Building standalone bridge executable..."
    & $python -m PyInstaller `
        --noconfirm `
        --clean `
        --distpath $distBridgeDir `
        --workpath $workDir `
        $specFile

    Copy-Item (Join-Path $bridgeRoot ".env.example") (Join-Path $distBridgeDir ".env.example") -Force

    $bridgeExe = Join-Path $distBridgeDir "IbulPrintBridge.exe"
    if (!(Test-Path $bridgeExe)) {
        throw "Bridge EXE build failed: $bridgeExe"
    }

    Write-Host "Bridge EXE: $bridgeExe"
} finally {
    Pop-Location
}
