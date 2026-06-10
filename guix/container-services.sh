#!/bin/bash
# Guix VM — Container Services Setup
# Deploys podman containers from service_catalog.yaml
set -o pipefail

# Ensure passt + slirp4netns are available (required for rootless podman networking)
export PATH="$HOME/.guix-profile/bin:$PATH"
guix install passt slirp4netns 2>/dev/null || true
export PATH="/run/current-system/profile/bin:$HOME/.guix-profile/bin:/run/privileged/bin:$PATH"

SUDO=/run/privileged/bin/sudo
DATA=/var/lib/containers
CONF=/etc/containers

echo "=== Container Services Setup ==="

# ── Common setup ──
$SUDO mkdir -p $DATA $CONF
$SUDO chown -R neg:users $DATA 2>/dev/null || true
mkdir -p ~/.config/containers

# ── AdGuard Home (DNS filter, port 3000) ──
echo ""
echo "── adguardhome ──"
$SUDO mkdir -p /var/lib/adguardhome-container/{conf,work}
$SUDO chown -R neg:users /var/lib/adguardhome-container
podman pull docker.io/adguard/adguardhome:latest 2>/dev/null || true
podman rm -f adguardhome 2>/dev/null || true
podman run -d --name adguardhome \
    --restart unless-stopped \
    -v /var/lib/adguardhome-container/conf:/opt/adguardhome/conf:Z \
    -v /var/lib/adguardhome-container/work:/opt/adguardhome/work:Z \
    -p 3000:3000 \
    docker.io/adguard/adguardhome:latest
echo "  adguardhome → http://127.0.0.1:3000"

# ── Loki (log aggregation, port 3100) ──
echo ""
echo "── loki ──"
$SUDO mkdir -p /etc/loki /var/lib/loki-container
$SUDO chown -R neg:users /etc/loki /var/lib/loki-container
[ -f /etc/loki/config.yaml ] || $SUDO tee /etc/loki/config.yaml << 'EOF' > /dev/null
auth_enabled: false
server:
  http_listen_port: 3100
ingester:
  lifecycler:
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
  chunk_idle_period: 5m
  chunk_retain_period: 30s
schema_config:
  configs:
  - from: 2024-01-01
    store: tsdb
    object_store: filesystem
    schema: v13
    index:
      prefix: index_
      period: 24h
storage_config:
  tsdb_shipper:
    active_index_directory: /var/lib/loki/tsdb-index
    cache_location: /var/lib/loki/tsdb-cache
  filesystem:
    directory: /var/lib/loki/chunks
limits_config:
  allow_deletes: true
  reject_old_samples: true
  reject_old_samples_max_age: 168h
EOF
podman pull docker.io/grafana/loki:latest 2>/dev/null || true
podman rm -f loki 2>/dev/null || true
podman run -d --name loki \
    --restart unless-stopped \
    -v /etc/loki/config.yaml:/etc/loki/config.yaml:Z \
    -v /var/lib/loki-container:/var/lib/loki:Z \
    -p 3100:3100 \
    docker.io/grafana/loki:latest -config.file=/etc/loki/config.yaml
echo "  loki → http://127.0.0.1:3100"

# ── Promtail (log collector, port 9080) ──
echo ""
echo "── promtail ──"
$SUDO mkdir -p /etc/promtail /var/cache/promtail
$SUDO mkdir -p /var/log/journal /run/log/journal 2>/dev/null || true
$SUDO chown -R neg:users /etc/promtail /var/cache/promtail
[ -f /etc/promtail/config.yaml ] || $SUDO tee /etc/promtail/config.yaml << 'EOF' > /dev/null
server:
  http_listen_port: 9080
  grpc_listen_port: 0
positions:
  filename: /var/cache/promtail/positions.yaml
clients:
  - url: http://127.0.0.1:3100/loki/api/v1/push
scrape_configs:
  - job_name: journal
    journal:
      max_age: 12h
      labels:
        job: systemd-journal
    relabel_configs:
      - source_labels: [__journal__systemd_unit]
        target_label: unit
      - source_labels: [__journal__hostname]
        target_label: hostname
EOF
podman pull docker.io/grafana/promtail:latest 2>/dev/null || true
podman rm -f promtail 2>/dev/null || true
podman run -d --name promtail \
    --restart unless-stopped \
    -v /etc/promtail/config.yaml:/etc/promtail/config.yaml:Z \
    -v /var/log/journal:/var/log/journal:ro,Z \
    -v /run/log/journal:/run/log/journal:ro,Z \
    -v /var/cache/promtail:/var/cache/promtail:Z \
    -p 9080:9080 \
    docker.io/grafana/promtail:latest -config.file=/etc/promtail/config.yaml
echo "  promtail → http://127.0.0.1:9080"

# ── Grafana (dashboards, port 3030) ──
echo ""
echo "── grafana ──"
$SUDO mkdir -p /etc/grafana/provisioning /var/lib/grafana-container
$SUDO chown -R neg:users /etc/grafana /var/lib/grafana-container
[ -f /etc/grafana/grafana.ini ] || $SUDO tee /etc/grafana/grafana.ini << 'EOF' > /dev/null
[server]
http_port = 3030
[security]
admin_user = admin
admin_password = admin
[auth.anonymous]
enabled = true
EOF
podman pull docker.io/grafana/grafana:latest 2>/dev/null || true
podman rm -f grafana 2>/dev/null || true
podman run -d --name grafana \
    --restart unless-stopped \
    -v /etc/grafana/grafana.ini:/etc/grafana/grafana.ini:Z \
    -v /etc/grafana/provisioning:/etc/grafana/provisioning:Z \
    -v /var/lib/grafana-container:/var/lib/grafana:Z \
    -p 3030:3030 \
    docker.io/grafana/grafana:latest
echo "  grafana → http://127.0.0.1:3030 (admin/admin)"

# ── Alertmanager (port 9093) ──
echo ""
echo "── alertmanager ──"
$SUDO mkdir -p /etc/alertmanager
$SUDO chown -R neg:users /etc/alertmanager
[ -f /etc/alertmanager/config.yml ] || $SUDO tee /etc/alertmanager/config.yml << 'EOF' > /dev/null
route:
  receiver: blackhole
receivers:
  - name: blackhole
EOF
podman pull docker.io/prom/alertmanager:latest 2>/dev/null || true
podman rm -f alertmanager 2>/dev/null || true
podman run -d --name alertmanager \
    --restart unless-stopped \
    -v /etc/alertmanager/config.yml:/etc/alertmanager/config.yml:Z \
    -p 9093:9093 \
    docker.io/prom/alertmanager:latest --config.file=/etc/alertmanager/config.yml
echo "  alertmanager → http://127.0.0.1:9093"

# ── Vaultwarden (Bitwarden-compatible, port 8222) ──
echo ""
echo "── vaultwarden ──"
$SUDO mkdir -p /var/lib/vaultwarden
$SUDO chown -R neg:users /var/lib/vaultwarden
podman pull docker.io/vaultwarden/server:latest 2>/dev/null || true
podman rm -f vaultwarden 2>/dev/null || true
podman run -d --name vaultwarden \
    --restart unless-stopped \
    -v /var/lib/vaultwarden:/data:Z \
    -p 8222:80 \
    docker.io/vaultwarden/server:latest
echo "  vaultwarden → http://127.0.0.1:8222"

# ── Transmission (torrent, port 9091) ──
echo ""
echo "── transmission ──"
$SUDO mkdir -p /etc/transmission ~/dw ~/torrent/data
$SUDO chown -R neg:users /etc/transmission
[ -f /etc/transmission/settings.json ] || $SUDO tee /etc/transmission/settings.json << 'EOF' > /dev/null
{
    "rpc-whitelist": "127.0.0.1,10.0.*.*,172.16.*.*,192.168.*.*",
    "rpc-whitelist-enabled": true,
    "rpc-port": 9091,
    "rpc-authentication-required": false,
    "download-dir": "/downloads",
    "incomplete-dir": "/downloads",
    "watch-dir": "/watch",
    "ratio-limit": 2,
    "ratio-limit-enabled": true
}
EOF
podman pull docker.io/linuxserver/transmission:latest 2>/dev/null || true
podman rm -f transmission 2>/dev/null || true
podman run -d --name transmission \
    --restart unless-stopped \
    -v /etc/transmission:/config:Z \
    -v ~/dw:/watch:Z \
    -v ~/torrent/data:/downloads:Z \
    -p 9091:9091 \
    -e PUID=1001 -e PGID=998 \
    docker.io/linuxserver/transmission:latest
echo "  transmission → http://127.0.0.1:9091"

echo ""
echo "=== Container Services === "
echo ""
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null
echo ""
echo "Service               URL"
echo "────────────────────────────────────────"
echo "adguardhome           http://127.0.0.1:3000"
echo "loki                  http://127.0.0.1:3100"
echo "promtail              http://127.0.0.1:9080"
echo "grafana               http://127.0.0.1:3030  (admin/admin)"
echo "alertmanager          http://127.0.0.1:9093"
echo "vaultwarden           http://127.0.0.1:8222"
echo "transmission          http://127.0.0.1:9091"
