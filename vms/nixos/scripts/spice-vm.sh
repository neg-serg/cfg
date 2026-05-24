#!/usr/bin/env bash
# Launch SPICE viewer on a dedicated workspace (background).
# Usage: spice-vm [HOST] [PORT]
# Default: spice://127.0.0.1:5900
HOST="${1:-127.0.0.1}"
PORT="${2:-5900}"
URI="spice://${HOST}:${PORT}"
WIN_ID="nixos-vm-spice"

# Kill existing instance
pkill -f "remote-viewer $URI" 2>/dev/null || true
sleep 0.5

# Launch remote-viewer
remote-viewer "$URI" &
VIEWER_PID=$!

# Wait for window to appear, then move to workspace 9 (background)
sleep 2
if command -v hyprctl >/dev/null 2>&1; then
  # Hyprland: move to workspace 9 (silent, no focus)
  hyprctl dispatch movetoworkspace 9,pid:$VIEWER_PID 2>/dev/null || true
  echo "Moved remote-viewer to workspace 9 (Hyprland)"
elif command -v swaymsg >/dev/null 2>&1; then
  # Sway: move to workspace 9
  swaymsg "[pid=$VIEWER_PID]" move to workspace 9 2>/dev/null || true
  echo "Moved remote-viewer to workspace 9 (Sway)"
else
  echo "No compositor detected — window may open in foreground"
fi

echo "SPICE viewer PID: $VIEWER_PID"
echo "Connect: $URI"
echo "Switch to workspace 9 to see it, or run: hyprctl dispatch workspace 9"
