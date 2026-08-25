[CmdletBinding()]
param(
    [int]$WaitSeconds = 20
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$demoPath = Join-Path $projectRoot 'monitored-files\fim-demo.txt'

Set-Content -LiteralPath $demoPath -Value @(
    'Wazuh FIM demonstration file.'
    'Stage: created.'
) -Encoding utf8
Write-Host "Created $demoPath"
Start-Sleep -Seconds $WaitSeconds

Add-Content -LiteralPath $demoPath -Value @(
    'Stage: modified.'
    'Change: Simulated security-relevant configuration update.'
) -Encoding utf8
Write-Host 'Modified the demonstration file.'
Start-Sleep -Seconds $WaitSeconds

Remove-Item -LiteralPath $demoPath
Write-Host 'Deleted the demonstration file.'
Write-Host "Allow about $WaitSeconds seconds, then collect evidence or view the events in the dashboard."
