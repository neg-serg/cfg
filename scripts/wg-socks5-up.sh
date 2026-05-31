#!/usr/bin/env bash
set -euo pipefail

AWG_CONF="${AWG_CONF:-/etc/wireguard/awg-tunnel.conf}"
SOCKS5_PORT="${SOCKS5_PORT:-10809}"
SOCKS5_PID_FILE="/tmp/socks5-forward-${SOCKS5_PORT}.pid"
AWG_IFACE="awg-tunnel"

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "INFO: $*" >&2; }

[[ "$(id -u)" -eq 0 ]] || die "must run as root (sudo)"

if ! command -v awg-quick &>/dev/null; then
    die "awg-quick not found. Install AmneziaWG first: sudo salt-call --local state.apply amnezia"
fi

if [[ ! -f "$AWG_CONF" ]]; then
    die "config not found: $AWG_CONF"
fi

if ip link show "$AWG_IFACE" &>/dev/null; then
    info "AWG interface $AWG_IFACE already up"
else
    info "Bringing up AWG tunnel: $AWG_IFACE"
    awg-quick up "$AWG_CONF"
fi

if [[ -f "$SOCKS5_PID_FILE" ]]; then
    OLD_PID=$(cat "$SOCKS5_PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        info "SOCKS5 proxy already running (pid $OLD_PID)"
        exit 0
    fi
    rm -f "$SOCKS5_PID_FILE"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROXY_SCRIPT="${SCRIPT_DIR}/socks5-forward.py"

if [[ ! -f "$PROXY_SCRIPT" ]]; then
    die "SOCKS5 forwarder not found: $PROXY_SCRIPT"
fi

info "Starting SOCKS5 proxy on 127.0.0.1:$SOCKS5_PORT..."
python3 "$PROXY_SCRIPT" 127.0.0.1 "$SOCKS5_PORT" &
SOCKS5_PID=$!
echo "$SOCKS5_PID" > "$SOCKS5_PID_FILE"

sleep 1
if ! kill -0 "$SOCKS5_PID" 2>/dev/null; then
    die "SOCKS5 proxy failed to start"
fi

info "SOCKS5 proxy running (pid $SOCKS5_PID)"
info "AWG interface: $AWG_IFACE, Address: $(ip -4 addr show "$AWG_IFACE" 2>/dev/null | awk '/inet /{print $2}' || echo unknown)"
info "Usage: export ALL_PROXY=socks5://127.0.0.1:$SOCKS5_PORT"
info "Test:   curl --socks5 127.0.0.1:$SOCKS5_PORT https://ifconfig.me"
