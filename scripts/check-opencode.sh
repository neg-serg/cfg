#!/usr/bin/env bash
set -euo pipefail

# OpenCode health check script
# Checks all components needed for opencode CLI to work

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

pass()  { echo -e "  ${GREEN}PASS${NC}  $1"; }
warn()  { echo -e "  ${YELLOW}WARN${NC}  $1"; }
fail()  { echo -e "  ${RED}FAIL${NC}  $1"; }
info()  { echo -e "  INFO  $1"; }

ISSUES=0

echo "═══════════════════════════════════════════"
echo "  OpenCode Health Check"
echo "═══════════════════════════════════════════"
echo ""

# ── 1. opencode-serve service ────────────────────────────────────
echo "1. OpenCode Serve Service"
echo "-------------------------"

if systemctl --user is-active opencode-serve.service &>/dev/null; then
    pass "opencode-serve.service is running"
else
    SVC_STATE=$(systemctl --user is-active opencode-serve.service 2>/dev/null || echo "inactive")
    if [[ "$SVC_STATE" == "failed" ]]; then
        fail "opencode-serve.service FAILED"
        journalctl --user -u opencode-serve --no-pager -n 5 2>/dev/null
        ((ISSUES++))
    elif [[ "$SVC_STATE" == "inactive" ]]; then
        warn "opencode-serve.service not running (not enabled or stopped)"
        ((ISSUES++))
    fi
fi

# ── Check port ───────────────────────────────────────────────────
if ss -tlnp 2>/dev/null | grep -q ":4096"; then
    pass "Port 4096 listening"
else
    warn "Port 4096 not listening"
    ((ISSUES++))
fi

echo ""

# ── 2. Environment file ──────────────────────────────────────────
echo "2. Secrets & Environment"
echo "------------------------"

ENV_FILE="${HOME}/.config/opencode/env"
if [[ -f "$ENV_FILE" ]]; then
    if grep -q "DEEPSEEK_API_KEY=sk-" "$ENV_FILE"; then
        KEY=$(grep "DEEPSEEK_API_KEY" "$ENV_FILE" | cut -d= -f2)
        pass "DEEPSEEK_API_KEY set (${KEY:0:10}...)"
    else
        fail "DEEPSEEK_API_KEY missing or invalid in $ENV_FILE"
        ((ISSUES++))
    fi
else
    fail "env file missing: $ENV_FILE"
    ((ISSUES++))
fi

SYSTEMD_OVERRIDE="${HOME}/.config/systemd/user/opencode-serve.service.d/override.conf"
if [[ -f "$SYSTEMD_OVERRIDE" ]]; then
    pass "systemd override exists"
else
    warn "systemd override missing — DEEPSEEK_API_KEY may not be loaded"
    ((ISSUES++))
fi

# Check gopass key
if gopass show -o api/deepseek &>/dev/null; then
    pass "gopass api/deepseek key exists"
else
    fail "gopass api/deepseek key missing"
    ((ISSUES++))
fi

echo ""

# ── 3. opencode.json config ──────────────────────────────────────
echo "3. OpenCode Config"
echo "------------------"

CFG="${HOME}/.config/opencode/opencode.json"
if [[ -f "$CFG" ]]; then
    pass "opencode.json exists"
    if python3 -c "import json; json.load(open('$CFG'))" 2>/dev/null; then
        pass "opencode.json is valid JSON"
    else
        fail "opencode.json is invalid JSON"
        ((ISSUES++))
    fi
else
    fail "opencode.json missing"
    ((ISSUES++))
fi

echo ""

# ── 4. Proxypilot proxy ──────────────────────────────────────────
echo "4. Proxypilot Proxy"
echo "-------------------"

if curl -sf --max-time 3 http://127.0.0.1:8317/v1/models -H "Authorization: Bearer dummy" &>/dev/null; then
    pass "Proxypilot responding on :8317"
elif ss -tlnp 2>/dev/null | grep -q ":8317"; then
    warn "Proxypilot port open but not responding"
    ((ISSUES++))
else
    warn "Proxypilot not listening on :8317"
    ((ISSUES++))
fi

echo ""

# ── 5. opencode CLI connectivity ─────────────────────────────────
echo "5. OpenCode CLI Check"
echo "---------------------"

if command -v opencode &>/dev/null; then
    pass "opencode binary found: $(which opencode)"
else
    fail "opencode not in PATH"
    ((ISSUES++))
fi

echo ""

# ── 6. Audio subsystem ───────────────────────────────────────────
echo "6. Audio Subsystem"
echo "------------------"

for svc in pipewire wireplumber pipewire-pulse; do
    if systemctl --user is-active "$svc.service" &>/dev/null; then
        pass "$svc is running"
    else
        fail "$svc is NOT running"
        ((ISSUES++))
    fi
done

if command -v pactl &>/dev/null; then
    if SINK=$(pactl get-default-sink 2>/dev/null); then
        info "Default sink: $SINK"
    fi
    if SINKS=$(pactl list short sinks 2>/dev/null | wc -l); then
        pass "$SINKS audio sink(s) available"
    fi
else
    warn "pactl not available"
fi

if [[ -e /dev/snd/pcmC0D0p ]] || [[ -e /dev/snd ]]; then
    pass "ALSA devices present"
else
    warn "No ALSA devices found"
fi

echo ""

# ── 7. Steam/Wine audio ──────────────────────────────────────────
echo "7. Steam / Wine Audio"
echo "---------------------"

if command -v wine &>/dev/null; then
    WINEPREFIX="${WINEPREFIX:-${HOME}/.wine}"
    if [[ -f "$WINEPREFIX/drive_c/windows/system32/winepulse.drv" ]]; then
        info "winepulse.drv found (Wine → PulseAudio bridge)"
    fi
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"

if [[ "$ISSUES" -eq 0 ]]; then
    echo -e "${GREEN}All checks passed — OpenCode should be operational${NC}"
    exit 0
elif [[ "$ISSUES" -le 2 ]]; then
    echo -e "${YELLOW}$ISSUES issue(s) found — may still work but should be fixed${NC}"
    exit 1
else
    echo -e "${RED}$ISSUES issue(s) found — OpenCode may not work correctly${NC}"
    exit 2
fi
