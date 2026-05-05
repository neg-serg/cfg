#!/usr/bin/env bash
# kvm-network-rc-local.sh — boot-time network setup for KVM test VMs
# Deployed as /etc/rc.local in the VM rootfs by kvm-bootstrap recipe.
set -euo pipefail

modprobe e1000 2>/dev/null || modprobe virtio_net 2>/dev/null || true

for i in $(seq 1 20); do
    for iface in /sys/class/net/e*; do
        [ -d "$iface" ] || continue
        name=$(basename "$iface")
        [ "$name" = "lo" ] && continue
        ip link set "$name" up 2>/dev/null || true
        ip addr add 10.0.2.15/24 dev "$name" 2>/dev/null || true
        ip route add default via 10.0.2.2 2>/dev/null || true
        exit 0
    done
    sleep 1
done
