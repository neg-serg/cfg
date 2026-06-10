#!/bin/bash
# Guix VM — Podman rootless container setup
# Run once after system reconfigure to enable podman
set -e

echo "=== Configuring podman for rootless operation ==="

# Fix newuidmap PATH (Guix shadow has newuidmap but without setuid;
# /run/privileged/bin has the setuid version)
if ! grep -q "/run/privileged/bin" ~/.bashrc 2>/dev/null; then
    echo 'export PATH="/run/privileged/bin:$PATH"' >> ~/.bashrc
fi
export PATH="/run/privileged/bin:$PATH"

# Create podman policy.json (required by podman)
sudo mkdir -p /etc/containers
sudo bash -c 'echo "{\"default\":[{\"type\":\"insecureAcceptAnything\"}]}" > /etc/containers/policy.json'
sudo bash -c 'cat > /etc/containers/registries.conf << EOF
[registries.search]
registries = ["docker.io"]
EOF'

# User namespace for rootless podman
if ! grep -q "^neg:" /etc/subuid 2>/dev/null; then
    sudo bash -c 'echo "neg:100000:65536" >> /etc/subuid'
    sudo bash -c 'echo "neg:100000:65536" >> /etc/subgid'
fi

# Reset podman storage to apply new subuid/subgid
podman system reset --force 2>/dev/null || true

echo ""
echo "=== Podman ready ==="
echo "Test: podman run --rm alpine:latest echo OK"
echo ""
echo "=== Container services from service_catalog.yaml ==="
echo ""
echo "GPU-dependent (not for VM):"
echo "  ollama, llama_embed, t5_summarization, jellyfin"
echo ""
echo "Workable in VM (system scope):"
echo "  adguardhome     - DNS filter (port 3000)"
echo "  loki            - Log aggregation (port 3100)"
echo "  promtail        - Log collector (port 9080)"
echo "  grafana         - Dashboards (port 3030)"
echo "  alertmanager    - Alerting (port 9093)"
echo "  vaultwarden     - Password manager (port 8222)"
echo "  bitcoind        - Bitcoin node"
echo "  transmission    - Torrent client (port 9091)"
echo "  duckdns         - Dynamic DNS updater"
echo ""
echo "User scope:"
echo "  proxypilot      - Proxy management (port 8317)"
echo "  telethon_bridge - Telegram bridge"
echo ""
echo "Example:"
echo "  podman run -d --name adguardhome \\"
echo "    -v /var/lib/adguardhome/conf:/opt/adguardhome/conf:Z \\"
echo "    -v /var/lib/adguardhome/work:/opt/adguardhome/work:Z \\"
echo "    -p 3000:3000 docker.io/adguard/adguardhome:latest"
