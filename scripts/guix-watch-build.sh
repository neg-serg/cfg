#!/usr/bin/env bash
set -euo pipefail

# Watch active guix build log

list_active() {
  guix gc --list-roots 2>/dev/null |
    rg -o '/gnu/store/[^-]+-[^-]+' |
    while read -r drv; do
      local path
      path="$(guix build --log-file "$drv" 2>/dev/null)" && echo "$drv"
    done || true

  ps aux | rg 'guix.*build.*\.drv' | rg -o '/gnu/store/[^ ]+\.drv' || true
}

drv="${1:-}"
if [ -z "$drv" ]; then
  echo "Looking for active builds..."
  drv=$(list_active | head -1)
fi

if [ -z "$drv" ]; then
  echo "No active build found."
  echo "Usage: $0 [path-to-.drv]"
  echo ""
  echo "To tail a specific build:"
  echo "  guix build --log-file /gnu/store/xxxx-go-1.26.3.drv | xargs tail -f"
  exit 1
fi

log=$(guix build --log-file "$drv" 2>/dev/null || true)
if [ -n "$log" ] && [ -f "$log" ]; then
  echo "Tailing build log for: $drv"
  echo "(file: $log)"
  echo "---"
  tail -f "$log"
else
  echo "Build not started yet or log unavailable for: $drv"
  echo "Watching for log to appear..."
  while true; do
    log=$(guix build --log-file "$drv" 2>/dev/null || true)
    if [ -n "$log" ] && [ -f "$log" ]; then
      echo "Log found, tailing: $log"
      tail -f "$log"
      break
    fi
    sleep 3
  done
fi
