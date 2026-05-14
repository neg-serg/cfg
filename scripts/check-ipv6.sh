#!/usr/bin/env zsh
# @script
# purpose: IPv6 diagnostics script
#

set -euo pipefail

# IPv6 diagnostics script
# Usage: ./check-ipv6.sh [--json]

SCRIPT_DIR="${0:A:h}"
source "${SCRIPT_DIR}/lib/pretty.sh"

declare -A RESULTS
RESULTS[global_addr]=0
RESULTS[route]=0
RESULTS[dns_aaaa]=0
RESULTS[ping]=0
RESULTS[curl]=0
RESULTS[tunnel]=0
RESULTS[icmpv6]=0

echo "IPv6 Diagnostics"
echo "================"
echo ""

# ── 1. Interface addresses ──────────────────────────────────────────
echo "1. Interface addresses"
echo "----------------------"

LINK_LOCAL=$(ip -6 addr show scope link 2>/dev/null | grep -c 'fe80:' || true)
GLOBAL=$(ip -6 addr show scope global 2>/dev/null | grep -c 'inet6' || true)
ULA=$(ip -6 addr show | grep -c 'fd[0-9a-f][0-9a-f]:' || true)

if [[ "$LINK_LOCAL" -gt 0 ]]; then
    pass "Link-local addresses: $LINK_LOCAL interface(s)"
else
    fail "No link-local addresses (IPv6 stack disabled or kernel module missing)"
fi

if [[ "$GLOBAL" -gt 0 ]]; then
    pass "Global IPv6 addresses: $GLOBAL"
    RESULTS[global_addr]=1
else
    warn "No global IPv6 addresses — tunnel or native IPv6 needed"
fi

if [[ "$ULA" -gt 0 ]]; then
    info "ULA addresses present: $ULA"
fi

ip -6 addr show 2>/dev/null | while read -r line; do
    if [[ "$line" =~ ^[0-9]+:\ ([^:]+) ]]; then
        iface="${BASH_REMATCH[1]}"
    fi
    if [[ "$line" =~ inet6\ ([^ ]+) ]]; then
        addr="${BASH_REMATCH[1]}"
        scope=$(echo "$line" | grep -oP 'scope \K\w+')
        echo "    $iface → $addr ($scope)"
    fi
done

echo ""

# ── 2. IPv6 routes ─────────────────────────────────────────────────
echo "2. IPv6 routes"
echo "--------------"

DEFAULT_V6=$(ip -6 route show default 2>/dev/null || true)
if [[ -n "$DEFAULT_V6" ]]; then
    pass "Default IPv6 route: $DEFAULT_V6"
    RESULTS[route]=1
else
    fail "No default IPv6 route — external IPv6 unreachable"
fi

echo "    Full table:"
ip -6 route show 2>/dev/null | while read -r route; do
    echo "    $route"
done

echo ""

# ── 3. DNS resolution ──────────────────────────────────────────────
echo "3. AAAA DNS resolution"
echo "----------------------"

AAAA_HOSTS=("ipv6.google.com" "he.net" "ip6.me")
for host in "${AAAA_HOSTS[@]}"; do
    if AAAA=$(dig +short AAAA "$host" 2>/dev/null | head -1 || true); then
        if [[ -n "$AAAA" ]]; then
            pass "$host → $AAAA"
            RESULTS[dns_aaaa]=1
        else
            fail "$host → no AAAA record"
        fi
    else
        fail "$host → DNS lookup failed"
    fi
done

echo ""

# ── 4. Connectivity tests ──────────────────────────────────────────
echo "4. Connectivity tests"
echo "--------------------"

if command -v ping &>/dev/null; then
    if ping -6 -c 2 -W 3 ipv6.google.com &>/dev/null; then
        pass "ping -6 ipv6.google.com"
        RESULTS[ping]=1
    else
        fail "ping -6 ipv6.google.com — unreachable"
    fi
else
    info "ping not available"
fi

if command -v curl &>/dev/null; then
    if curl -6 --max-time 5 --silent --output /dev/null --write-out '%{remote_ip}' ip6.me 2>/dev/null; then
        pass "curl -6 ip6.me"
        RESULTS[curl]=1
    else
        fail "curl -6 ip6.me — unreachable"
    fi
else
    info "curl not available"
fi

echo ""

# ── 5. Tunnel interfaces ───────────────────────────────────────────
echo "5. Tunnel interfaces (6in4/6to4/sit)"
echo "-------------------------------------"

TUNNEL_IFACES=$(ip -6 link show type sit 2>/dev/null || true)
if [[ -n "$TUNNEL_IFACES" ]]; then
    info "Tunnel interfaces found:"
    echo "$TUNNEL_IFACES" | while read -r line; do
        echo "    $line"
    done
    RESULTS[tunnel]=1
else
    info "No sit/6in4 tunnel interfaces found"
fi

echo ""

# ── 6. ip6tables ───────────────────────────────────────────────────
echo "6. ip6tables policy"
echo "-------------------"

if command -v ip6tables &>/dev/null; then
    INPUT_POLICY=$(ip6tables -L INPUT 2>/dev/null | head -1 | awk '{print $4}' || echo "unknown")
    FORWARD_POLICY=$(ip6tables -L FORWARD 2>/dev/null | head -1 | awk '{print $4}' || echo "unknown")
    info "INPUT policy: $INPUT_POLICY"
    info "FORWARD policy: $FORWARD_POLICY"

    if [[ "$INPUT_POLICY" == "DROP" ]] || [[ "$FORWARD_POLICY" == "DROP" ]]; then
        warn "DROP policy active — ICMPv6 may be blocked (IPv6 needs ICMPv6 for ND/RA)"
        ICMP_ACCEPT=$(ip6tables -L INPUT -n 2>/dev/null | grep -c 'icmpv6' || true)
        if [[ "$ICMP_ACCEPT" -eq 0 ]]; then
            fail "No ICMPv6 rules found — IPv6 may not work correctly"
        else
            pass "ICMPv6 accepted: $ICMP_ACCEPT rule(s)"
            RESULTS[icmpv6]=1
        fi
    else
        pass "No DROP policy on INPUT/FORWARD"
        RESULTS[icmpv6]=1
    fi
else
    info "ip6tables not available"
fi

echo ""

# ── 7. Public IPv6 check ───────────────────────────────────────────
echo "7. Public IPv6 address"
echo "----------------------"

if command -v curl &>/dev/null; then
    PUBLIC_V6=$(curl -6 --max-time 5 --silent https://ip6.me/api/ 2>/dev/null || true)
    if [[ -n "$PUBLIC_V6" ]]; then
        pass "Public IPv6: $PUBLIC_V6"
    else
        if curl -6 --max-time 5 --silent --output /dev/null https://ifconfig.io 2>/dev/null; then
            pass "IPv6 outbound connectivity works"
        else
            fail "No outbound IPv6 connectivity"
        fi
    fi
else
    info "curl not available"
fi

echo ""

# ── Verdict ─────────────────────────────────────────────────────────
echo "===================================="
TOTAL=0
PASS_COUNT=0
for key in "${!RESULTS[@]}"; do
    TOTAL=$((TOTAL + 1))
    if [ "${RESULTS[$key]}" -eq 1 ]; then
        PASS_COUNT=$((PASS_COUNT + 1))
    fi
done
if [ "$PASS_COUNT" -ge 4 ]; then
    echo "Verdict: IPv6 is WORKING ($PASS_COUNT/$TOTAL checks passed)"
elif [ "$PASS_COUNT" -ge 2 ]; then
    echo "Verdict: PARTIAL IPv6 ($PASS_COUNT/$TOTAL checks passed) — tunnel or native config needed"
elif [ "$PASS_COUNT" -ge 1 ]; then
    echo "Verdict: Minimal IPv6 ($PASS_COUNT/$TOTAL)"
else
    echo "Verdict: NO IPv6 ($PASS_COUNT/$TOTAL)"
fi
echo "===================================="
echo "===================================="

# ── Recommendations ─────────────────────────────────────────────────
echo ""
echo "Next steps if IPv6 is not working:"
echo "  1. Check router: enable SLAAC/DHCPv6 if ISP provides IPv6"
echo "  2. If ISP does NOT provide IPv6: configure HE.net tunnel (tunnelbroker.net)"
echo "     - Register at https://tunnelbroker.net"
echo "     - Create Regular Tunnel with your public IPv4"
echo "     - Run: gopass insert api/he-tunnel"
echo "     - Enable in Salt: features.network.ipv6_tunnel: true"
echo "  3. Verify ip6tables accepts ICMPv6 (required for Neighbor Discovery)"
echo "  4. Check kernel module: lsmod | grep sit"
