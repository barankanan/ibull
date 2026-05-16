$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptRoot)
$outDir = Join-Path $scriptRoot "release_bundle"

if (Test-Path $outDir) { Remove-Item $outDir -Recurse -Force }
New-Item -ItemType Directory -Path $outDir | Out-Null

$files = @(
    (Join-Path $scriptRoot "build_windows_installer.log"),
    (Join-Path $scriptRoot "validate_release_flow.log"),
    (Join-Path $scriptRoot "RELEASE_VALIDATION_CHECKLIST.md"),
    (Join-Path $repoRoot "release_gate.log"),
    (Join-Path $scriptRoot "dist\installer\IbulPrintBridgeSetup.exe")
)

foreach ($f in $files) {
    if (Test-Path $f) {
        Copy-Item $f $outDir -Force
    } else {
        Write-Warning "Missing expected artifact: $f"
    }
}

$zipPath = Join-Path $scriptRoot "release_bundle.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $outDir "*") -DestinationPath $zipPath

Write-Host "Release bundle: $zipPath"
