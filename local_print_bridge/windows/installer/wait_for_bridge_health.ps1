param(
    [int]$TimeoutSeconds = 45,
    [string]$HealthUrl = "http://127.0.0.1:3001/health"
)

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
while ((Get-Date) -lt $deadline) {
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri $HealthUrl -TimeoutSec 2
        if ($response.StatusCode -eq 200) {
            exit 0
        }
    } catch {
        # Bridge may still be starting; keep polling.
    }
    Start-Sleep -Seconds 1
}

exit 1
