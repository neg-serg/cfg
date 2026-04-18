#!/usr/bin/env bash
set -euo pipefail

XRAY_CONFIG="$HOME/.config/sing-box-tun/config.json"
SINGBOX_CONFIG="$HOME/.config/sing-box-tun/config-singbox-hybrid-final.json"
XRAY_BIN="$HOME/.local/bin/xray"
SINGBOX_BIN="/usr/bin/sing-box"

# Kill existing
pkill -f "xray.*config.json" 2>/dev/null || true
pkill -f "sing-box.*config-singbox-hybrid-final" 2>/dev/null || true
sleep 2

echo "=== Starting Xray ==="
cd "$(dirname "$XRAY_CONFIG")"
"$XRAY_BIN" run -c "$(basename "$XRAY_CONFIG")" &
XRAY_PID=$!
sleep 3

echo "=== Starting sing-box ==="
"$SINGBOX_BIN" run -c "$SINGBOX_CONFIG" &
SINGBOX_PID=$!
sleep 5

echo "=== Checking interfaces ==="
ip link show sb0 2>/dev/null || echo "TUN interface sb0 not found"
ip addr show sb0 2>/dev/null || true

echo "=== Checking routes ==="
ip route show table all | grep -E "sb0|172.19" || true
ip -6 route show table all | grep -E "sb0|fd00" || true

echo "=== Testing connectivity ==="
echo "Testing direct connectivity (should work):"
curl --max-time 5 --silent --fail https://httpbin.org/ip 2>/dev/null && echo "✅ Direct connectivity works"

echo "Testing via TUN (should go through VPN):"
# Use curl with interface binding (requires curl built with interface support)
# Alternative: use ping or traceroute
ping -c 1 -W 2 1.1.1.1 2>/dev/null && echo "✅ Ping via TUN works"

echo "=== Checking process status ==="
if kill -0 "$XRAY_PID" 2>/dev/null; then
    echo "✅ Xray running (PID $XRAY_PID)"
else
    echo "❌ Xray not running"
fi

if kill -0 "$SINGBOX_PID" 2>/dev/null; then
    echo "✅ sing-box running (PID $SINGBOX_PID)"
else
    echo "❌ sing-box not running"
fi

echo ""
echo "=== Press Ctrl+C to stop ==="
trap "kill $XRAY_PID $SINGBOX_PID 2>/dev/null; echo 'Stopped'" INT TERM
wait $XRAY_PID $SINGBOX_PID