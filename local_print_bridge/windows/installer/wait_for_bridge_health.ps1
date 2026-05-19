param(
    [int]$TimeoutSeconds = 45,
    [string]$HealthUrl = "http://127.0.0.1:3001/health"
)

function Test-BridgeHealth {
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri $HealthUrl -TimeoutSec 2
        return ($response.StatusCode -eq 200)
    } catch {
        return $false
    }
}

if (Test-BridgeHealth) {
    exit 0
}

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
while ((Get-Date) -lt $deadline) {
    if (Test-BridgeHealth) {
        exit 0
    }
    Start-Sleep -Seconds 1
}

exit 1
