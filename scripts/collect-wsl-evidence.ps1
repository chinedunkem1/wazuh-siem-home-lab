$ErrorActionPreference = 'Continue'
$distroName = 'Wazuh-SIEM-WSL'
$projectRoot = Split-Path -Parent $PSScriptRoot
$evidencePath = Join-Path $projectRoot 'evidence\manager-status.txt'

$lines = @()
$lines += 'WAZUH HOME LAB - MANAGER STATUS'
$lines += "Collected: $(Get-Date -Format o)"
$lines += ''
$lines += '=== Services ==='
$lines += (& wsl.exe -d $distroName -u root -- systemctl is-active wazuh-indexer wazuh-manager filebeat wazuh-dashboard 2>&1 | Out-String)
$lines += '=== Agents ==='
$lines += (& wsl.exe -d $distroName -u root -- /var/ossec/bin/agent_control -l 2>&1 | Out-String)
$lines += '=== Listening ports ==='
$lines += (& wsl.exe -d $distroName -u root -- bash -lc "ss -lnt | grep -E ':(8443|1514|1515|55000) '" 2>&1 | Out-String)
$lines += '=== FIM demo alerts ==='
$fimJson = & wsl.exe -d $distroName -u root -- grep -i 'fim-demo.txt' /var/ossec/logs/alerts/alerts.json 2>$null
foreach ($eventJson in $fimJson) {
    try {
        $event = $eventJson | ConvertFrom-Json
        $mitre = if ($event.rule.mitre.id) { $event.rule.mitre.id -join ', ' } else { 'N/A' }
        $lines += ('{0} | Level {1} | Rule {2} | {3} | Event: {4} | MITRE: {5}' -f `
            $event.timestamp,
            $event.rule.level,
            $event.rule.id,
            $event.rule.description,
            $event.syscheck.event,
            $mitre)
    }
    catch {
        $lines += 'A FIM event was present but could not be converted to the public summary.'
    }
}

$cleanLines = (($lines -join [Environment]::NewLine) -split "\r?\n") | ForEach-Object { $_.TrimEnd() }
$cleanLines | Set-Content -LiteralPath $evidencePath -Encoding utf8
Get-Content -LiteralPath $evidencePath
