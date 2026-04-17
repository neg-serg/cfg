#!/usr/bin/env bash
set -euo pipefail

SESSION_FILE="${HOME}/.telethon-bridge/telethon.session"
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
