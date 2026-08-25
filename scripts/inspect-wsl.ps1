$ErrorActionPreference = 'Continue'
$projectRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $projectRoot 'evidence\private\wsl-status.txt'
New-Item -ItemType Directory -Path (Split-Path $outputPath) -Force | Out-Null

$lines = @()
$lines += '=== WSL status ==='
$lines += (& wsl.exe --status 2>&1 | Out-String)
$lines += '=== WSL distributions ==='
$lines += (& wsl.exe --list --verbose 2>&1 | Out-String)
$lines += '=== Windows version ==='
$lines += (& cmd.exe /c ver 2>&1 | Out-String)
$lines += '=== Wazuh WSL IPv4 ==='
$lines += (& wsl.exe -d Wazuh-SIEM-WSL -u root -- hostname -I 2>&1 | Out-String)
$lines | Set-Content -LiteralPath $outputPath -Encoding utf8
