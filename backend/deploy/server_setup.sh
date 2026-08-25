#!/usr/bin/env bash
# One-time bootstrap for the Oracle Cloud Always Free VM (Ubuntu).
# Run as:  bash server_setup.sh
set -euo pipefail

echo "== Installing Docker =="
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"

echo "== Opening firewall ports (80 = API, 22 = SSH) =="
# Ubuntu's ufw (usually inactive on Oracle images, but harmless to set):
sudo ufw allow 22/tcp || true
sudo ufw allow 80/tcp || true
sudo ufw --force enable || true

# Oracle's Ubuntu images ship static iptables rules that REJECT every port
# except 22 — the classic "port unreachable even with the Security List
# open" gotcha. Insert an accept rule for port 80 and persist it.
sudo iptables -I INPUT 5 -p tcp --dport 80 -m state --state NEW -j ACCEPT
sudo netfilter-persistent save

sudo mkdir -p /opt/ibajay-eats
sudo chown "$USER":"$USER" /opt/ibajay-eats

echo "== Done. Re-login (or run 'newgrp docker') so the docker group applies =="
echo "== Next: push the code with push_to_server.ps1 from your PC =="
