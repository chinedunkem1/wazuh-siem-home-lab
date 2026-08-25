[CmdletBinding()]
param(
    [string]$ManagerAddress = '127.0.0.1',
    [string]$AgentName = 'Windows-Endpoint',
    [int]$EnrollmentDelaySeconds = 20
)

$ErrorActionPreference = 'Stop'
$agentRoot = 'C:\Program Files (x86)\ossec-agent'
$authTool = Join-Path $agentRoot 'agent-auth.exe'
$configPath = Join-Path $agentRoot 'ossec.conf'
$backupPath = "$configPath.pre-codex-backup"
$projectRoot = Split-Path -Parent $PSScriptRoot
$monitoredPath = Join-Path $projectRoot 'monitored-files'
$evidenceDir = Join-Path $projectRoot 'evidence\private'
$authLog = Join-Path $evidenceDir 'agent-enrollment.txt'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script as Administrator.'
}

New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null
Stop-Service -Name WazuhSvc -ErrorAction SilentlyContinue
Copy-Item -LiteralPath $configPath -Destination (Join-Path $evidenceDir 'ossec-rejected.conf') -Force
if (Test-Path -LiteralPath $backupPath) {
    Copy-Item -LiteralPath $backupPath -Destination (Join-Path $evidenceDir 'ossec-original.conf') -Force
    Copy-Item -LiteralPath $backupPath -Destination $configPath -Force
}
Start-Sleep -Seconds $EnrollmentDelaySeconds
$previousLocation = Get-Location
try {
    Set-Location -LiteralPath $agentRoot
    $previousErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & $authTool -m $ManagerAddress -A $AgentName 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorPreference
    $output | Set-Content -LiteralPath $authLog -Encoding utf8

    if ($exitCode -ne 0) {
        throw "Agent enrollment failed with exit code $exitCode. See $authLog"
    }

    $content = [System.IO.File]::ReadAllText($configPath)
    if (-not $content.Contains($monitoredPath)) {
        $closingTag = '</syscheck>'
        $position = $content.IndexOf($closingTag, [StringComparison]::OrdinalIgnoreCase)
        if ($position -lt 0) {
            throw 'The Wazuh syscheck closing tag was not found.'
        }
        $entry = "  <directories realtime=`"yes`" check_all=`"yes`" report_changes=`"yes`">$monitoredPath</directories>`r`n  "
        $content = $content.Insert($position, $entry)
        [System.IO.File]::WriteAllText($configPath, $content, (New-Object System.Text.UTF8Encoding($false)))
    }

    Write-Output ($output -join [Environment]::NewLine)
    Write-Output "Enrollment evidence: $authLog"
} catch {
    $_ | Out-String | Set-Content -LiteralPath (Join-Path $evidenceDir 'agent-enrollment-error.txt') -Encoding utf8
    throw
} finally {
    Set-Location -LiteralPath $previousLocation
    Start-Service -Name WazuhSvc -ErrorAction SilentlyContinue
}

Start-Sleep -Seconds 3
$service = Get-Service -Name WazuhSvc
Write-Output "Agent service: $($service.Status)"
