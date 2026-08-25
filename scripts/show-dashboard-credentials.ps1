$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$logPath = Join-Path $projectRoot 'evidence\private\wsl-wazuh-provision.log'

if (-not (Test-Path -LiteralPath $logPath)) {
    throw "The private installation log was not found at $logPath"
}

$passwordLine = Select-String -LiteralPath $logPath -Pattern '^\s*Password:\s+' | Select-Object -Last 1
if (-not $passwordLine) {
    throw 'The dashboard password was not found in the private installation log.'
}

Write-Host 'Dashboard: https://localhost:8443'
Write-Host 'Username:  admin'
Write-Host ($passwordLine.Line.Trim())
Write-Warning 'Keep this password private. The evidence/private directory is excluded from Git.'
