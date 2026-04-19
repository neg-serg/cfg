#!/usr/bin/env bash
# Quick start script for VPN browser integration

set -e

echo "=== VPN Browser Integration Quick Start ==="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

step() {
    echo
    echo "=== Step $1: $2 ==="
}

# Step 1: Start VPN
step "1" "Starting VPN system"
if sudo /home/neg/src/cfg/scripts/start-hybrid-vpn.sh; then
    success "VPN started successfully"
else
    warning "VPN start had issues, trying manual setup..."
    sudo /home/neg/src/cfg/scripts/manual-tun-routes.sh start
fi

# Step 2: Update RKN domains
step "2" "Updating RKN blocked domains"
if python3 /home/neg/src/cfg/scripts/rkn-domains-fetcher.py fetch --force --integrate; then
    success "RKN domains updated"
else
    warning "RKN domains update failed (continuing anyway)"
fi

# Step 3: Check system status
step "3" "Checking system status"
echo "Checking TUN interface..."
if ip link show sb0 >/dev/null 2>&1; then
    success "TUN interface sb0 is active"
else
    error "TUN interface not found"
    echo "Trying to fix..."
    sudo /home/neg/src/cfg/scripts/manual-tun-routes.sh start
fi

echo "Checking routing..."
if ip route show table vpn-tun >/dev/null 2>&1; then
    success "VPN routing table exists"
else
    warning "VPN routing table not found (may need manual setup)"
fi

# Step 4: Test connectivity
step "4" "Testing connectivity"
echo "Testing direct connection..."
if curl -s --max-time 5 https://httpbin.org/ip >/dev/null; then
    success "Direct internet connection works"
else
    error "Direct connection failed"
fi

echo "Testing VPN proxy..."
if curl -s --max-time 5 --socks5 127.0.0.1:10808 https://httpbin.org/ip >/dev/null; then
    success "VPN proxy connection works"
else
    error "VPN proxy connection failed"
fi

# Step 5: Browser configuration
step "5" "Browser configuration"
echo
echo "To configure your browser:"
echo
echo "1. Zen Browser (recommended):"
echo "   Run: /home/neg/src/cfg/scripts/zen-vpn.sh enable"
echo
echo "2. Manual configuration:"
echo "   - SOCKS5 Proxy: 127.0.0.1:10808"
echo "   - Check 'Proxy DNS when using SOCKS v5'"
echo
echo "3. Test with blocked site:"
echo "   curl --socks5 127.0.0.1:10808 https://twitter.com"
echo

# Step 6: Enable automatic updates
step "6" "Enabling automatic updates"
if systemctl --user enable --now rkn-domains-fetcher.timer >/dev/null 2>&1; then
    success "Automatic updates enabled"
    echo "   Updates will run every 6 hours"
else
    warning "Could not enable automatic updates"
    echo "   You can run updates manually:"
    echo "   python3 /home/neg/src/cfg/scripts/rkn-domains-fetcher.py fetch"
fi

# Final summary
echo
echo "=== Quick Start Complete ==="
echo
echo "Next steps:"
echo "1. Configure your browser proxy (see Step 5)"
echo "2. Test with a blocked site"
echo "3. Check status anytime: /home/neg/src/cfg/scripts/test-browser-vpn.sh"
echo "4. View documentation: docs/vpn-browser-integration.md"
echo
echo "Troubleshooting:"
echo "- Check VPN status: systemctl status sing-box-tun"
echo "- Check RKN updates: journalctl --user -u rkn-domains-fetcher.service"
echo "- Test proxy: curl --socks5 127.0.0.1:10808 https://httpbin.org/ip"
echo
echo "For more details, see the full documentation."