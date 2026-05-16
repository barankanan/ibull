$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

param(
    [string]$InstallerPath = "$PSScriptRoot\dist\installer\IbulPrintBridgeSetup.exe",
    [string]$BridgeHost = "127.0.0.1",
    [int]$BridgePort = 3001
)

$bridgeLogsDir = Join-Path $env:LOCALAPPDATA "IbulPrintBridge\logs"
$bridgeLogPath = Join-Path $bridgeLogsDir "bridge.log"

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "[FAIL] $Message"
    }
}

function Test-BridgeHealth {
    param([string]$Host, [int]$Port)
    $uri = "http://$Host`:$Port/health"
    try {
        $resp = Invoke-RestMethod -Uri $uri -Method GET -TimeoutSec 5
        return ($resp -and $resp.ok -eq $true)
    } catch {
        return $false
    }
}

function Wait-BridgeHealth {
    param([string]$Host, [int]$Port, [int]$Seconds = 20)
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-BridgeHealth -Host $Host -Port $Port) {
            return $true
        }
        Start-Sleep -Seconds 1
    }
    return $false
}

Write-Host "[1/9] Installer dosyasi kontrolu..."
Assert-True (Test-Path $InstallerPath) "Installer bulunamadi: $InstallerPath"

Write-Host "[2/9] Sessiz kurulum testi..."
$installArgs = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART"
$proc = Start-Process -FilePath $InstallerPath -ArgumentList $installArgs -PassThru -Wait
Assert-True ($proc.ExitCode -eq 0) "Kurulum basarisiz. ExitCode=$($proc.ExitCode)"

Write-Host "[3/9] Bridge saglik kontrolu..."
$healthy = Wait-BridgeHealth -Host $BridgeHost -Port $BridgePort -Seconds 25
Assert-True $healthy "Kurulum sonrasi /health yanit vermedi"

Write-Host "[4/9] Bridge log dosyasi kontrolu..."
Assert-True (Test-Path $bridgeLogPath) "Bridge log dosyasi bulunamadi: $bridgeLogPath"

Write-Host "[5/9] Otomatik baslatma kaydi kontrolu..."
$runPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$runValue = (Get-ItemProperty -Path $runPath -Name "IbulLocalPrintBridge" -ErrorAction SilentlyContinue).IbulLocalPrintBridge
Assert-True (![string]::IsNullOrWhiteSpace($runValue)) "Autostart kaydi bulunamadi"

Write-Host "[6/9] Prensip kontrolu: /printers endpoint"
$printersUri = "http://$BridgeHost`:$BridgePort/printers"
try {
    $printersResp = Invoke-RestMethod -Uri $printersUri -Method GET -TimeoutSec 8
    Assert-True ($printersResp.ok -eq $true) "/printers yaniti ok!=true"
} catch {
    throw "[FAIL] /printers endpoint cagirilamadi: $($_.Exception.Message)"
}

Write-Host "[7/9] Uninstall komutu bulunuyor mu?"
$uninstallRoots = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)
$uninstallEntry = $null
foreach ($root in $uninstallRoots) {
    if (!(Test-Path $root)) { continue }
    $entry = Get-ChildItem $root | ForEach-Object {
        Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue
    } | Where-Object {
        $_.DisplayName -like "Ibul Print Bridge*"
    } | Select-Object -First 1

    if ($entry) {
        $uninstallEntry = $entry
        break
    }
}
Assert-True ($null -ne $uninstallEntry) "Uninstall kaydi bulunamadi"

Write-Host "[8/9] Sessiz uninstall testi..."
$uninstallCmd = [string]$uninstallEntry.UninstallString
Assert-True (![string]::IsNullOrWhiteSpace($uninstallCmd)) "Uninstall komutu bos"

$exe = $null
$args = $null
if ($uninstallCmd.StartsWith('"')) {
    $end = $uninstallCmd.IndexOf('"', 1)
    $exe = $uninstallCmd.Substring(1, $end - 1)
    $args = $uninstallCmd.Substring($end + 1).Trim()
} else {
    $parts = $uninstallCmd.Split(" ", 2)
    $exe = $parts[0]
    $args = if ($parts.Count -gt 1) { $parts[1] } else { "" }
}

if ($exe -match "(?i)unins.*\.exe") {
    $args = "$args /VERYSILENT /SUPPRESSMSGBOXES /NORESTART"
}

$unProc = Start-Process -FilePath $exe -ArgumentList $args -PassThru -Wait
Assert-True ($unProc.ExitCode -eq 0) "Uninstall basarisiz. ExitCode=$($unProc.ExitCode)"

Write-Host "[9/9] Uninstall sonrasi servis erisimi kontrolu..."
$stillHealthy = Test-BridgeHealth -Host $BridgeHost -Port $BridgePort
Assert-True (-not $stillHealthy) "Uninstall sonrasi bridge halen erisilebilir"

Write-Host "OK: Temel install/health/autostart/uninstall dogrulamalari gecti."
Write-Host "MANUAL: Reboot sonrasi autostart + Seller Panel 'Tekrar Kontrol Et' + test fisi + rol atama + gercek siparis print adimlarini tamamlayin."
