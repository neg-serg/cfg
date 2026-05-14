#!/bin/bash
# @script
# purpose: Periodic cache cleanup for user-level caches not covered by paccache.timer.
#

# Periodic cache cleanup for user-level caches not covered by paccache.timer.
# Runs as a systemd --user oneshot service, triggered by cache-cleanup.timer.
set -euo pipefail

log() { echo "[cache-cleanup] $(date '+%Y-%m-%d %H:%M:%S') $*"; }

# ── paru AUR clone cache ──────────────────────────────────────────────
if command -v paru &>/dev/null; then
    log "paru -Sc --noconfirm ..."
    paru -Sc --noconfirm 2>&1 | sed 's/^/  /'
    log "paru done"
else
    log "paru not installed, skipping"
fi

# ── pip cache ─────────────────────────────────────────────────────────
if command -v pip &>/dev/null; then
    log "pip cache purge ..."
    pip cache purge 2>&1 | sed 's/^/  /'
    log "pip done"
fi

# ── npm cache ─────────────────────────────────────────────────────────
if command -v npm &>/dev/null; then
    log "npm cache clean --force ..."
    npm cache clean --force 2>&1 | sed 's/^/  /'
    log "npm done"
fi

# ── flatpak unused runtimes ──────────────────────────────────────────
if command -v flatpak &>/dev/null; then
    log "flatpak uninstall --unused -y ..."
    flatpak uninstall --unused -y 2>&1 | sed 's/^/  /'
    log "flatpak done"
fi

# ── cargo registry cache ─────────────────────────────────────────────
if command -v cargo &>/dev/null && command -v cargo-cache &>/dev/null; then
    log "cargo cache -a ..."
    cargo cache -a 2>&1 | sed 's/^/  /'
    log "cargo done"
elif command -v cargo &>/dev/null; then
    log "cargo-cache not installed (try: cargo install cargo-cache), skipping"
fi

log "all cleanups complete"
