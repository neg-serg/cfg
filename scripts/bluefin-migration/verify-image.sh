#!/bin/bash
set -euo pipefail
IMAGE="${1:-bluefin-custom:latest}"
echo "=== Verifying $IMAGE ==="

FAIL=0
check() { local pkg=$1; shift
  for cmd in "$@"; do $cmd "$pkg" >/dev/null 2>&1 && return 0; done
  echo "  ❌ $pkg"; FAIL=1
}

C=$(podman run --rm "$IMAGE" sh -c '
check() { p=$1; shift; for c in "$@"; do $c "$p" >/dev/null 2>&1 && return 0; done; echo "MISS:$p"; }
echo "── Core ──"
check zsh      "rpm -q"
check neovim   "rpm -q"
check git      "rpm -q"
check curl     "rpm -q"
check tmux     "rpm -q"
check podman   "rpm -q"
check distrobox "rpm -q"
check flatpak  "rpm -q"
check chezmoi  "rpm -q"
check gopass   "rpm -q"
check age      "rpm -q"
check wget     "command -v"
echo "── CLI ──"
check ripgrep  "rpm -q"
check bat      "command -v"
check eza      "command -v"
check fd-find  "rpm -q"
check jq       "rpm -q"
check fzf      "command -v"
check zoxide   "command -v"
check direnv   "command -v"
echo "── Dev ──"
check cargo    "command -v"
check go       "command -v"
check node     "command -v"
check pipx     "rpm -q"
check rustc    "command -v"
echo "── Desktop ──"
check Hyprland "command -v"
check steam    "command -v"
echo "── Gaming ──"
check mangohud  "rpm -q"
check gamemode  "rpm -q"
check gamescope "rpm -q"
echo "STATS:$(rpm -qa|wc -l) RPMs,$(find /usr/bin -type f|wc -l) bins"
')

echo "$C" | grep -v "^STATS:" || true
echo "$C" | grep "^STATS:" | sed 's/STATS://'
echo "$C" | grep -q "MISS:" && echo "❌ ISSUES" || echo "✅ ALL GOOD"
echo "Size: $(podman images "$IMAGE" --format '{{.Size}}')"
