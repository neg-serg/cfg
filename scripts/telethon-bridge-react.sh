#!/usr/bin/env bash
# @script
# purpose: Reactive path-triggered launcher for telethon-bridge service: checks for existing session file and starts telethon-bridge.service via a .path systemd unit.
#

set -euo pipefail

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
SESSION_FILE="${STATE_HOME}/telethon-bridge/telethon.session"
UNIT="telethon-bridge.service"

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export XDG_RUNTIME_DIR="$runtime_dir"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${runtime_dir}/bus"

if [ ! -f "$SESSION_FILE" ]; then
	logger -t telethon-bridge-react "session file missing; skipping reactive start"
	exit 0
fi

if systemctl --user is-active --quiet "$UNIT"; then
	systemctl --user restart "$UNIT"
else
	systemctl --user start "$UNIT"
fi
