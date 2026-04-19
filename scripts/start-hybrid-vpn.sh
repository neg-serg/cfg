#!/usr/bin/env bash
set -euo pipefail

# Hybrid VPN setup: Xray handles XHTTP transport, sing-box handles TUN interface
# Xray runs the AmneziaVPN config with XHTTP+REALITY
# sing-box creates TUN interface and routes traffic through Xray SOCKS5 proxy

XRAY_CONFIG="${1:-$HOME/.config/sing-box-tun/config.json}"
SINGBOX_CONFIG="${2:-$HOME/.config/sing-box-tun/config-singbox-hybrid-final.json}"
XRAY_BIN="${XRAY_BIN:-$HOME/.local/bin/xray}"
SINGBOX_BIN="${SINGBOX_BIN:-/usr/bin/sing-box}"
TIMEOUT=30
TEST_URL="https://httpbin.org/ip"

XRAY_PID=""
SINGBOX_PID=""
OVERALL_RESULT=0

# shellcheck disable=SC2329  # function is called via trap
cleanup() {
    echo ""
    echo "=== Cleanup ==="
    
    # Stop sing-box
    if [[ -n "$SINGBOX_PID" ]] && kill -0 "$SINGBOX_PID" 2>/dev/null; then
        echo "Stopping sing-box (PID $SINGBOX_PID)..."
        kill "$SINGBOX_PID" 2>/dev/null || true
        sleep 1
        if kill -0 "$SINGBOX_PID" 2>/dev/null; then
            kill -9 "$SINGBOX_PID" 2>/dev/null || true
        fi
        wait "$SINGBOX_PID" 2>/dev/null || true
    fi
    
    # Stop xray
    if [[ -n "$XRAY_PID" ]] && kill -0 "$XRAY_PID" 2>/dev/null; then
        echo "Stopping xray (PID $XRAY_PID)..."
        kill "$XRAY_PID" 2>/dev/null || true
        sleep 1
        if kill -0 "$XRAY_PID" 2>/dev/null; then
            kill -9 "$XRAY_PID" 2>/dev/null || true
        fi
        wait "$XRAY_PID" 2>/dev/null || true
    fi
    
    # Clean up TUN interface
    sudo ip link delete sb0 2>/dev/null || true
    sudo ip route flush table 200 2>/dev/null || true
    sudo ip rule del pref 100 2>/dev/null || true
    sudo ip rule del pref 200 2>/dev/null || true
    
    echo "Cleanup complete"
}

# Setup trap for cleanup
trap cleanup EXIT INT TERM

# Verify binaries
if [[ ! -x "$XRAY_BIN" ]]; then
    echo "ERROR: xray binary not found or not executable: $XRAY_BIN" >&2
    echo "Install with: curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh | sudo bash" >&2
    exit 1
fi

if [[ ! -x "$SINGBOX_BIN" ]]; then
    echo "ERROR: sing-box binary not found or not executable: $SINGBOX_BIN" >&2
    echo "Install with: sudo pacman -S sing-box" >&2
    exit 1
fi

# Verify configs
if [[ ! -f "$XRAY_CONFIG" ]]; then
    echo "ERROR: Xray config not found: $XRAY_CONFIG" >&2
    echo "Run: ./scripts/amnezia-import-tun-config.sh import" >&2
    exit 1
fi

if [[ ! -f "$SINGBOX_CONFIG" ]]; then
    echo "ERROR: sing-box config not found: $SINGBOX_CONFIG" >&2
    echo "Create config with: python3 scripts/xray-to-singbox.py $XRAY_CONFIG $SINGBOX_CONFIG" >&2
    exit 1
fi

echo "=== Starting Hybrid VPN (Xray + sing-box) ==="
echo "Xray config: $XRAY_CONFIG"
echo "sing-box config: $SINGBOX_CONFIG"
echo "Xray binary: $XRAY_BIN"
echo "sing-box binary: $SINGBOX_BIN"
echo ""

# Kill existing processes
pkill -f "xray.*$XRAY_CONFIG" 2>/dev/null || true
pkill -f "sing-box.*$SINGBOX_CONFIG" 2>/dev/null || true
sleep 2

# Clean up existing TUN interface
sudo ip link delete sb0 2>/dev/null || true

echo "=== Phase 1: Starting Xray (XHTTP + REALITY transport) ==="
cd "$(dirname "$XRAY_CONFIG")"
"$XRAY_BIN" run -config "$(basename "$XRAY_CONFIG")" &
XRAY_PID=$!
sleep 3

if ! kill -0 "$XRAY_PID" 2>/dev/null; then
    echo "❌ Failed to start xray" >&2
    exit 1
fi

echo "✅ Xray started (PID $XRAY_PID)"

# Test Xray SOCKS5 proxy
echo ""
echo "Testing Xray SOCKS5 proxy (127.0.0.1:10808)..."
if curl --max-time "$TIMEOUT" --socks5 "127.0.0.1:10808" --silent --fail "$TEST_URL"; then
    echo "✅ Xray SOCKS5 proxy works!"
else
    echo "❌ Xray SOCKS5 proxy failed" >&2
    OVERALL_RESULT=1
    exit 1
fi

echo ""
echo "=== Phase 2: Starting sing-box (TUN interface) ==="

# Check sing-box config
if ! "$SINGBOX_BIN" check -c "$SINGBOX_CONFIG" 2>&1; then
    echo "ERROR: sing-box config check failed" >&2
    exit 1
fi

# Start sing-box
"$SINGBOX_BIN" run -c "$SINGBOX_CONFIG" &
SINGBOX_PID=$!
sleep 5

if ! kill -0 "$SINGBOX_PID" 2>/dev/null; then
    echo "❌ Failed to start sing-box" >&2
    OVERALL_RESULT=1
    exit 1
fi

echo "✅ sing-box started (PID $SINGBOX_PID)"

# Check TUN interface
echo ""
echo "Checking TUN interface..."
if ip link show sb0 2>/dev/null; then
    echo "✅ TUN interface sb0 created"
    
    # Show interface details
    echo "TUN interface details:"
    ip addr show sb0 2>/dev/null || true
    
    # Test TUN routing
    echo ""
    echo "Testing TUN routing (through Xray proxy)..."
    echo "This test uses the TUN interface to route traffic through VPN"
    echo "Note: May take a moment for routes to establish"
    sleep 2
    
    # Simple test - check if we can resolve DNS through TUN
    if ping -c 1 -W 2 1.1.1.1 2>/dev/null; then
        echo "✅ Basic network connectivity via TUN works"
    else
        echo "⚠️  Basic ping test failed (may be blocked by firewall)" >&2
    fi
    
    # Test that direct connection still works (split routing)
    echo ""
    echo "Testing direct connection (should still work)..."
    if curl --max-time "$TIMEOUT" --silent --fail "$TEST_URL"; then
        echo "✅ Direct connection works - split routing configured"
    else
        echo "⚠️  Direct connection failed - check routing" >&2
    fi
    
else
    echo "❌ TUN interface not created" >&2
    echo "Check permissions: sudo setcap 'cap_net_admin,cap_net_raw,cap_net_bind_service=+ep' /usr/bin/sing-box" >&2
    OVERALL_RESULT=1
fi

echo ""
if [[ "$OVERALL_RESULT" -eq 0 ]]; then
    echo "=== ✅ HYBRID VPN RUNNING SUCCESSFULLY ==="
    echo ""
    echo "Configuration:"
    echo "  • Xray: SOCKS5 proxy on 127.0.0.1:10808 (XHTTP+REALITY)"
    echo "  • sing-box: TUN interface sb0 with auto routing"
    echo "  • Traffic routing: Through TUN → Xray → VPN server"
    echo ""
    echo "Press Ctrl+C to stop"
    echo ""
    
    # Keep running until interrupted
    while kill -0 "$XRAY_PID" 2>/dev/null && kill -0 "$SINGBOX_PID" 2>/dev/null; do
        sleep 5
    done
    
    echo "One of the services stopped"
    OVERALL_RESULT=1
else
    echo "=== ❌ HYBRID VPN FAILED ==="
fi

exit "$OVERALL_RESULT"