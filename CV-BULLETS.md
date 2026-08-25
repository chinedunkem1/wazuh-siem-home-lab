# CV-ready project entry

## Wazuh SIEM Home Lab | Windows 11, Ubuntu, WSL2

- Deployed a Wazuh 4.14.7 SIEM stack (manager, indexer, Filebeat, and dashboard) in an isolated Ubuntu 24.04 WSL2 environment and enrolled a Windows endpoint for centralized security monitoring.
- Implemented real-time File Integrity Monitoring and validated create, modify, and delete detections, including level-7 alerts mapped to MITRE ATT&CK T1565.001, T1070.004, and T1485.
- Automated lab start/stop, endpoint configuration, controlled testing, and evidence collection with PowerShell; protected credentials and raw security logs using source-control exclusions.

## Short version

Built and documented a Wazuh SIEM home lab with a Windows endpoint, real-time FIM, automated validation, and MITRE ATT&CK-mapped detections.

## Interview prompts

- Explain the event flow from the Windows agent through the manager and indexer to the dashboard.
- Describe why the test directory was isolated and how credentials were kept out of Git.
- Discuss the VirtualBox/hypervisor compatibility issue and why WSL2 was a suitable engineering alternative.
- Demonstrate how modifying the monitored file triggers a rule 550 level-7 alert.
