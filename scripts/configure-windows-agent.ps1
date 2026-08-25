[CmdletBinding()]
param(
    [string]$MonitoredPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $MonitoredPath) {
    $MonitoredPath = Join-Path $projectRoot 'monitored-files'
}
$configPath = 'C:\Program Files (x86)\ossec-agent\ossec.conf'
$backupPath = "$configPath.pre-fim-backup"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script as Administrator.'
}

New-Item -ItemType Directory -Path $MonitoredPath -Force | Out-Null
Stop-Service -Name WazuhSvc -ErrorAction SilentlyContinue

if (-not (Test-Path -LiteralPath $backupPath)) {
    Copy-Item -LiteralPath $configPath -Destination $backupPath
}

$content = [System.IO.File]::ReadAllText($configPath)
if (-not $content.Contains($MonitoredPath)) {
    $closingTag = '</syscheck>'
    $position = $content.IndexOf($closingTag, [StringComparison]::OrdinalIgnoreCase)
    if ($position -lt 0) {
        throw 'The Wazuh syscheck closing tag was not found.'
    }

    $entry = "  <directories realtime=`"yes`" check_all=`"yes`" report_changes=`"yes`">$MonitoredPath</directories>`r`n  "
    $content = $content.Insert($position, $entry)
    [System.IO.File]::WriteAllText($configPath, $content, (New-Object System.Text.UTF8Encoding($false)))
}

Set-Content -LiteralPath (Join-Path $MonitoredPath 'baseline.txt') -Value 'Wazuh FIM baseline - monitored file' -Encoding utf8
Set-Service -Name WazuhSvc -StartupType Automatic
Start-Service -Name WazuhSvc

$service = Get-Service -Name WazuhSvc
Write-Output "Agent service: $($service.Status)"
Write-Output "Monitored path: $MonitoredPath"
Write-Output "Configuration backup: $backupPath"
