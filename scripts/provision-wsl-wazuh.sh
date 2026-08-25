#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo '=== WSL host ==='
uname -a
grep '^PRETTY_NAME=' /etc/os-release
systemctl is-system-running || true

apt-get update
apt-get install -y curl ca-certificates

if ! dpkg-query -W -f='${Status}' wazuh-manager 2>/dev/null | grep -q 'install ok installed'; then
  cd /root
  curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh
  bash ./wazuh-install.sh -a
fi

if [[ -f /etc/apt/sources.list.d/wazuh.list ]]; then
  sed -i 's/^deb /#deb /' /etc/apt/sources.list.d/wazuh.list
  apt-get update
fi

dashboard_config='/etc/wazuh-dashboard/opensearch_dashboards.yml'
if grep -q '^server.port:' "$dashboard_config"; then
  sed -i 's/^server.port:.*/server.port: 8443/' "$dashboard_config"
else
  printf '\nserver.port: 8443\n' >> "$dashboard_config"
fi

systemctl restart wazuh-indexer wazuh-manager filebeat wazuh-dashboard

echo '=== Service validation ==='
systemctl is-active wazuh-indexer wazuh-manager filebeat wazuh-dashboard
ss -lnt | grep -E ':(8443|1514|1515|55000) '

echo '=== Dashboard credentials ==='
tar -O -xf /root/wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt | sed -n "/'admin'/,+1p"
