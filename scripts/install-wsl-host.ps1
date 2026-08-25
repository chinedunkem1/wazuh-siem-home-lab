[CmdletBinding()]
param(
    [string]$DistroName = 'Wazuh-SIEM-WSL',
    [string]$ImagePath = 'E:\Cybersecurity-Labs\Wazuh\iso\ubuntu-24.04.4-wsl-amd64.wsl',
    [string]$InstallPath = 'E:\Cybersecurity-Labs\Wazuh\wsl\Wazuh-SIEM-WSL'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$logPath = Join-Path $projectRoot 'evidence\private\wsl-install.txt'

New-Item -ItemType Directory -Force -Path $installPath,(Split-Path $logPath) | Out-Null

$existing = (& wsl.exe --list --quiet 2>$null | Out-String)
if ($existing -notmatch [regex]::Escape($DistroName)) {
    & wsl.exe --install --from-file $ImagePath --name $DistroName --location $InstallPath --version 2 --no-launch
    if ($LASTEXITCODE -ne 0) {
        throw "WSL installation failed with exit code $LASTEXITCODE"
    }
}

$status = & wsl.exe --list --verbose 2>&1 | Out-String
$status | Set-Content -LiteralPath $logPath -Encoding utf8
