#!/usr/bin/env bash
set -euo pipefail

# Test VPN connection using imported AmneziaVPN config
CONFIG="${1:-$HOME/.config/sing-box-tun/config.json}"
XRAY_BIN="${XRAY_BIN:-$HOME/.local/bin/xray}"
TIMEOUT=30
SOCKS_PROXY="127.0.0.1:10808"
TEST_URL="https://httpbin.org/ip"

if [[ ! -f "$CONFIG" ]]; then
    echo "ERROR: Config file not found: $CONFIG" >&2
    echo "Run: ./scripts/amnezia-import-tun-config.sh import" >&2
    exit 1
fi

if [[ ! -x "$XRAY_BIN" ]]; then
    echo "ERROR: Xray binary not found or not executable: $XRAY_BIN" >&2
    exit 1
fi

echo "=== Testing VPN connection ==="
echo "Config: $CONFIG"
echo "Xray: $XRAY_BIN"
echo ""

# Kill any existing xray instance using this config port
pkill -f "xray.*$CONFIG" 2>/dev/null || true
sleep 1

# Start xray in background
echo "Starting Xray..."
"$XRAY_BIN" run -config "$CONFIG" &
XRAY_PID=$!
sleep 3

if ! kill -0 "$XRAY_PID" 2>/dev/null; then
    echo "ERROR: Xray failed to start (PID $XRAY_PID)" >&2
    exit 1
fi

echo "Xray running (PID $XRAY_PID)"

# Test connection via SOCKS5 proxy
echo ""
echo "Testing connection via SOCKS5 proxy ($SOCKS_PROXY)..."
if curl --max-time "$TIMEOUT" --socks5 "$SOCKS_PROXY" --silent --fail "$TEST_URL"; then
    echo ""
    echo "✅ SUCCESS: VPN connection is working!"
    RESULT=0
else
    echo ""
    echo "❌ FAILED: Cannot connect via VPN proxy" >&2
    RESULT=1
fi

# Cleanup
echo ""
echo "Stopping Xray..."
kill "$XRAY_PID" 2>/dev/null || true
wait "$XRAY_PID" 2>/dev/null || true

exit "$RESULT"