#!/usr/bin/env bash
set -euo pipefail

AWG_CONF="${AWG_CONF:-/etc/wireguard/awg-tunnel.conf}"
SOCKS5_PORT="${SOCKS5_PORT:-10809}"
SOCKS5_PID_FILE="/tmp/socks5-forward-${SOCKS5_PORT}.pid"
AWG_IFACE="awg-tunnel"

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "INFO: $*" >&2; }

[[ "$(id -u)" -eq 0 ]] || die "must run as root (sudo)"

if [[ -f "$SOCKS5_PID_FILE" ]]; then
    PID=$(cat "$SOCKS5_PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        info "Stopping SOCKS5 proxy (pid $PID)..."
        kill "$PID" 2>/dev/null || true
        sleep 0.5
        kill -9 "$PID" 2>/dev/null || true
    fi
    rm -f "$SOCKS5_PID_FILE"
    info "SOCKS5 proxy stopped"
else
    info "SOCKS5 proxy not running"
fi

if ip link show "$AWG_IFACE" &>/dev/null; then
    info "Tearing down AWG tunnel: $AWG_IFACE"
    awg-quick down "$AWG_CONF"
fi
