#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DOMAIN_XML="${PROJECT_DIR}/../nixos.xml"
DISK_IMAGE="/mnt/one/vms/nixos.qcow2"
DISK_SIZE="40G"

red()   { echo -e "\033[31m$*\033[0m" >&2; }
green() { echo -e "\033[32m$*\033[0m"; }
cyan()  { echo -e "\033[36m$*\033[0m"; }

# Validate age key
cyan "=== Validating age key ==="
"$SCRIPT_DIR/decrypt-secrets.sh"

# Disk space check
cyan "=== Checking disk space ==="
DISK_DIR="$(dirname "$DISK_IMAGE")"
AVAIL_GB=$(df -BG "$DISK_DIR" 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//' || echo 0)
MIN_GB=40
if [ "${AVAIL_GB:-0}" -lt "$MIN_GB" ]; then
    red "ERROR: Insufficient disk space: ${AVAIL_GB}G available, ${MIN_GB}G required"
    red "Free up space on $DISK_DIR or choose a different location"
    exit 1
fi
green "Disk space OK: ${AVAIL_GB}G available"

# Build NixOS system configuration
cyan "=== Building NixOS system closure ==="
cd "$PROJECT_DIR"
nix flake check --no-build || {
    red "Flake check failed — fix configuration errors before deploying"
    exit 1
}

nix build '.#nixosConfigurations.nixos.config.system.build.toplevel' --no-link -v || {
    red "System build failed — check build logs"
    exit 1
}

# Build disko disk image (produces /dev/sda equivalent)
cyan "=== Building disk image ==="
nix build '.#nixosConfigurations.nixos.config.system.build.diskoImages' --no-link -v || {
    cyan "diskoImages target not available; creating empty qcow2 as fallback"
    if [ ! -f "$DISK_IMAGE" ]; then
        qemu-img create -f qcow2 "$DISK_IMAGE" "$DISK_SIZE"
    fi
    green "Using existing/named qcow2 at $DISK_IMAGE"
}

# Ensure disk image exists
if [ ! -f "$DISK_IMAGE" ]; then
    red "ERROR: No disk image found at $DISK_IMAGE"
    exit 1
fi

# Start VM via virsh
cyan "=== Starting VM ==="
if ! virsh list --name | grep -qFx nixos; then
    virsh define "$DOMAIN_XML"
    virsh start nixos
    green "VM nixos started"
else
    green "VM nixos is already running"
fi

# Wait for SSH
cyan "=== Waiting for SSH (up to 60s) ==="
for i in $(seq 1 30); do
    IP=$(virsh domifaddr nixos --source agent 2>/dev/null | awk '/ipv4/ {print $4}' | cut -d/ -f1 | head -1)
    if [ -n "$IP" ]; then
        green "VM IP: $IP"
        echo "Connect: ssh root@$IP"
        exit 0
    fi
    sleep 2
done

cyan "VM booted but IP not yet available via guest agent"
cyan "Check with: virsh domifaddr nixos --source agent"
exit 0
