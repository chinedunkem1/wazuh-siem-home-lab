$ErrorActionPreference = 'Stop'
$distroName = 'Wazuh-SIEM-WSL'
$projectRoot = Split-Path -Parent $PSScriptRoot
$statusPath = Join-Path $projectRoot 'evidence\private\runtime-status.txt'

Start-Process wsl.exe -WindowStyle Hidden -ArgumentList '-d', $distroName, '-u', 'root', '--exec', 'sleep', 'infinity'
Start-Sleep -Seconds 10

$ipAddress = (& wsl.exe -d $distroName -u root -- hostname -I).Trim().Split(' ')[0]
$serviceStatus = & wsl.exe -d $distroName -u root -- systemctl is-active wazuh-indexer wazuh-manager filebeat wazuh-dashboard 2>&1

@(
    "Distro: $distroName"
    "IP: $ipAddress"
    'Services:'
    $serviceStatus
) | Set-Content -LiteralPath $statusPath -Encoding utf8

Get-Content -LiteralPath $statusPath
