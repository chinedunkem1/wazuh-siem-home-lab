$ErrorActionPreference = 'Stop'
& wsl.exe --terminate Wazuh-SIEM-WSL
if ($LASTEXITCODE -ne 0) {
    throw "Unable to stop Wazuh-SIEM-WSL (exit code $LASTEXITCODE)."
}
Write-Output 'Wazuh-SIEM-WSL stopped.'
