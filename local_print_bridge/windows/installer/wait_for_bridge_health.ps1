param(
    [int]$TimeoutSeconds = 45,
    [string]$HealthUrl = "http://127.0.0.1:3001/health",
    [string]$BridgeExe = ""
)

function Test-BridgeHealth {
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri $HealthUrl -TimeoutSec 2
        return ($response.StatusCode -eq 200)
    } catch {
        return $false
    }
}

function Start-BridgeIfNeeded {
    if ([string]::IsNullOrWhiteSpace($BridgeExe)) {
        return
    }
    if (!(Test-Path $BridgeExe)) {
        return
    }

    $existing = Get-Process -Name "IbulPrintBridge" -ErrorAction SilentlyContinue
    if ($existing) {
        return
    }

    $bridgeDir = Split-Path -Parent $BridgeExe
    Start-Process `
        -FilePath $BridgeExe `
        -WorkingDirectory $bridgeDir `
        -WindowStyle Hidden `
        -ErrorAction SilentlyContinue `
        | Out-Null
}

if (Test-BridgeHealth) {
    exit 0
}

Start-BridgeIfNeeded

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
while ((Get-Date) -lt $deadline) {
    if (Test-BridgeHealth) {
        exit 0
    }
    Start-Sleep -Seconds 1
}

exit 1
