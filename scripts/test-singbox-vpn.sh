#!/usr/bin/env bash
set -euo pipefail

# Test sing-box VPN connection with safe fallback
# Phase 1: Test SOCKS proxy only (no TUN)
# Phase 2: Test TUN interface with restricted routing

CONFIG="${1:-$HOME/.config/sing-box-tun/config.json}"
TIMEOUT=30
SOCKS_PROXY="127.0.0.1:10809"
TEST_URL="https://httpbin.org/ip"
SINGBOX_BIN="${SINGBOX_BIN:-/usr/bin/sing-box}"
TEMP_SOCKS_CONFIG=""
TEMP_TUN_CONFIG=""
SINGBOX_PID=""
OVERALL_RESULT=0

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
    
    # Remove temp configs
    [[ -f "$TEMP_SOCKS_CONFIG" ]] && rm -f "$TEMP_SOCKS_CONFIG"
    [[ -f "$TEMP_TUN_CONFIG" ]] && rm -f "$TEMP_TUN_CONFIG"
    
    # Clean up any lingering TUN interface
    sudo ip link delete sb0 2>/dev/null || true
    sudo ip route flush table 200 2>/dev/null || true
    sudo ip rule del pref 100 2>/dev/null || true
    sudo ip rule del pref 200 2>/dev/null || true
}

# Setup trap for cleanup
trap cleanup EXIT

if [[ ! -f "$CONFIG" ]]; then
    echo "ERROR: Config file not found: $CONFIG" >&2
    echo "Run: ./scripts/amnezia-import-tun-config.sh import" >&2
    exit 1
fi

if [[ ! -x "$SINGBOX_BIN" ]]; then
    echo "ERROR: sing-box binary not found or not executable: $SINGBOX_BIN" >&2
    exit 1
fi

echo "=== Testing sing-box VPN connection ==="
echo "Source config: $CONFIG"
echo "sing-box: $SINGBOX_BIN"
echo ""

# Phase 1: Test SOCKS proxy only (safe, no TUN)
echo "=== PHASE 1: Testing SOCKS proxy only (no TUN) ==="
TEMP_SOCKS_CONFIG="$(mktemp /tmp/singbox-socks-test-XXXXXX.json)"

python3 -c "
import json
import sys

with open('$CONFIG', 'r') as f:
    config = json.load(f)

# Keep only SOCKS inbound, remove TUN
config['inbounds'] = [i for i in config.get('inbounds', []) if i.get('type') != 'tun']

# Change port for any existing SOCKS inbound to avoid conflict with running xray
for inbound in config.get('inbounds', []):
    if inbound.get('type') == 'socks':
        inbound['listen_port'] = 10809
        inbound['listen'] = '127.0.0.1'  # Ensure localhost only

# Ensure we have at least one SOCKS inbound
has_socks = any(i.get('type') == 'socks' for i in config.get('inbounds', []))
if not has_socks:
    config['inbounds'].append({
        'type': 'socks',
        'tag': 'socks-in',
        'listen': '127.0.0.1',
        'listen_port': 10809
    })

# Add sniff rule for SOCKS inbound
if 'route' not in config:
    config['route'] = {}
if 'rules' not in config['route']:
    config['route']['rules'] = []
    
# Remove any existing sniff rules for SOCKS
config['route']['rules'] = [r for r in config['route']['rules'] if r.get('inbound') != 'socks-in']
config['route']['rules'].append({
    'inbound': 'socks-in',
    'action': 'sniff',
    'timeout': '1s'
})

# Ensure default_domain_resolver
config['route']['default_domain_resolver'] = 'local'

with open('$TEMP_SOCKS_CONFIG', 'w') as f:
    json.dump(config, f, indent=2)
" || {
    echo "ERROR: Failed to create SOCKS-only config" >&2
    exit 1
}

echo "SOCKS-only config: $TEMP_SOCKS_CONFIG"

# Check config
if ! "$SINGBOX_BIN" check -c "$TEMP_SOCKS_CONFIG" 2>&1; then
    echo "ERROR: SOCKS config check failed" >&2
    exit 1
fi

# Kill any existing sing-box
pkill -f "sing-box.*$CONFIG" 2>/dev/null || true
sleep 2

# Start sing-box (no sudo needed for SOCKS only)
echo "Starting sing-box for SOCKS testing..."
"$SINGBOX_BIN" run -c "$TEMP_SOCKS_CONFIG" &
SINGBOX_PID=$!
sleep 3

if ! kill -0 "$SINGBOX_PID" 2>/dev/null; then
    echo "ERROR: sing-box failed to start for SOCKS test" >&2
    exit 1
fi

echo "sing-box running (PID $SINGBOX_PID)"

# Test SOCKS proxy
echo ""
echo "Testing SOCKS proxy ($SOCKS_PROXY)..."
if curl --max-time "$TIMEOUT" --socks5 "$SOCKS_PROXY" --silent --fail "$TEST_URL"; then
    echo "✅ PHASE 1 SUCCESS: SOCKS proxy works!"
    PHASE1_RESULT=0
else
    echo "❌ PHASE 1 FAILED: SOCKS proxy not working" >&2
    PHASE1_RESULT=1
    OVERALL_RESULT=1
fi

# Stop sing-box for phase 1
sudo kill "$SINGBOX_PID" 2>/dev/null || true
wait "$SINGBOX_PID" 2>/dev/null || true
SINGBOX_PID=""
sleep 2

# Phase 2: Test TUN interface with restricted routing (only if phase 1 succeeded)
if [[ "$PHASE1_RESULT" -eq 0 ]]; then
    echo ""
    echo "=== PHASE 2: Testing TUN interface (restricted routing) ==="
    
    TEMP_TUN_CONFIG="$(mktemp /tmp/singbox-tun-test-XXXXXX.json)"
    
    python3 -c "
import json
import sys

with open('$CONFIG', 'r') as f:
    config = json.load(f)

# Configure TUN inbound with restricted routing
for inbound in config.get('inbounds', []):
    if inbound.get('type') == 'tun':
        # Disable auto_route to avoid capturing all traffic
        inbound['auto_route'] = False
        inbound['strict_route'] = False
        # Exclude local networks
        inbound['route_exclude_address'] = [
            '10.0.0.0/8',
            '172.16.0.0/12', 
            '192.168.0.0/16',
            'fc00::/7',
            'fe80::/10',
            '100.64.0.0/10'  # Tailscale
        ]
        # Don't automatically add routes
        inbound.pop('inet4_route_address', None)
        inbound.pop('inet6_route_address', None)
        inbound.pop('route_address', None)

# Change port for any SOCKS inbound to avoid conflict with running xray
for inbound in config.get('inbounds', []):
    if inbound.get('type') == 'socks':
        inbound['listen_port'] = 10809
        inbound['listen'] = '127.0.0.1'  # Ensure localhost only

# Ensure default_domain_resolver
if 'route' in config:
    config['route']['default_domain_resolver'] = 'local'

with open('$TEMP_TUN_CONFIG', 'w') as f:
    json.dump(config, f, indent=2)
" || {
        echo "ERROR: Failed to create TUN test config" >&2
        OVERALL_RESULT=1
    }
    
    if [[ -f "$TEMP_TUN_CONFIG" ]]; then
        echo "TUN test config: $TEMP_TUN_CONFIG"
        
        if "$SINGBOX_BIN" check -c "$TEMP_TUN_CONFIG" 2>&1; then
            # Clean up existing TUN interface
            sudo ip link delete sb0 2>/dev/null || true
            
            # Start sing-box with TUN (capabilities already set)
            echo "Starting sing-box with TUN..."
            "$SINGBOX_BIN" run -c "$TEMP_TUN_CONFIG" &
            SINGBOX_PID=$!
            sleep 5
            
            if kill -0 "$SINGBOX_PID" 2>/dev/null; then
                echo "sing-box TUN running (PID $SINGBOX_PID)"
                
                # Check if TUN interface was created
                if ip link show sb0 2>/dev/null; then
                    echo "✅ TUN interface sb0 created"
                    
                    # Test that direct connection still works (TUN didn't capture traffic)
                    echo ""
                    echo "Testing direct connection (should still work)..."
                    if curl --max-time "$TIMEOUT" --silent --fail "$TEST_URL"; then
                        echo "✅ Direct connection works - TUN routing restricted correctly"
                        echo "✅ PHASE 2 SUCCESS: TUN interface created without disrupting traffic"
                    else
                        echo "⚠️  Direct connection failed - TUN may have captured traffic" >&2
                        OVERALL_RESULT=1
                    fi
                else
                    echo "⚠️  TUN interface not created (check permissions)" >&2
                    OVERALL_RESULT=1
                fi
            else
                echo "❌ Failed to start sing-box with TUN" >&2
                OVERALL_RESULT=1
            fi
        else
            echo "ERROR: TUN config check failed" >&2
            OVERALL_RESULT=1
        fi
    fi
else
    echo ""
    echo "Skipping Phase 2 (TUN test) due to Phase 1 failure"
fi

echo ""
if [[ "$OVERALL_RESULT" -eq 0 ]]; then
    echo "=== ✅ ALL TESTS PASSED ==="
else
    echo "=== ❌ SOME TESTS FAILED ==="
fi

exit "$OVERALL_RESULT"