#!/usr/bin/env bash
set -euo pipefail

# Health check for opencode-telegram-bot: verifies the bot has an active
# TCP connection to its SOCKS5 proxy. If the proxy is listening but the
# bot has no connection, the bot is not polling Telegram (silently broken)
# and needs a restart.
#
# Skips the restart if the proxy itself is down (nothing to restart to).

SERVICE="opencode-telegram-bot.service"
PROXY_PORT="10808"

if ! systemctl --user is-active --quiet "$SERVICE"; then
	exit 0
fi

PID=$(systemctl --user show -p MainPID --value "$SERVICE" 2>/dev/null || true)
if [ -z "$PID" ] || [ "$PID" = "0" ]; then
	exit 0
fi

if ss -tnp 2>/dev/null | awk -v pid="$PID" -v port="$PROXY_PORT" '
	$0 ~ "pid=" pid && $0 ~ "127\\.0\\.0\\.1:" port {
		found=1; exit
	}
	END { exit !found }
'; then
	exit 0
fi

if ! ss -tlnp 2>/dev/null | grep -q "127.0.0.1:${PROXY_PORT}"; then
	exit 0
fi

logger -t "opencode-telegram-bot-healthcheck" "no TCP connection to proxy port ${PROXY_PORT}, restarting ${SERVICE}"
systemctl --user restart "$SERVICE"
