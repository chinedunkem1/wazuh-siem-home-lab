$ErrorActionPreference = 'Stop'
$distroName = 'Wazuh-SIEM-WSL'
$projectRoot = Split-Path -Parent $PSScriptRoot
$windowsScript = Join-Path $PSScriptRoot 'provision-wsl-wazuh.sh'
$linuxScript = (& wsl.exe -d $distroName -u root -- wslpath -a $windowsScript).Trim()
$logPath = Join-Path $projectRoot 'evidence\private\wsl-wazuh-provision.log'

New-Item -ItemType Directory -Force -Path (Split-Path $logPath) | Out-Null

& wsl.exe -d $distroName -u root -- bash $linuxScript 2>&1 |
    Tee-Object -FilePath $logPath

if ($LASTEXITCODE -ne 0) {
    throw "Wazuh WSL provisioning failed with exit code $LASTEXITCODE. See $logPath"
}
