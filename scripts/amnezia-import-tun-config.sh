#!/usr/bin/env bash

set -euo pipefail

# Source: ~/.config/AmneziaVPN.ORG/AmneziaVPN.conf
# Output: ~/.config/sing-box-tun/config.json

SRC_CONFIG="${HOME}/.config/AmneziaVPN.ORG/AmneziaVPN.conf"
OUT_CONFIG="${HOME}/.config/sing-box-tun/config.json"

usage() {
	printf '%s\n' 'Usage: amnezia-import-tun-config.sh import|show-path|check'
}

write_runtime_config() {
	python3 - "$SRC_CONFIG" "$OUT_CONFIG" <<'PY'
import base64
import json
import re
import sys
from pathlib import Path

src = Path(sys.argv[1])
out = Path(sys.argv[2])
data = src.read_text(encoding='utf-8', errors='strict')
match = re.search(r'last_config\s*=\s*@ByteArray\(([^)]*)\)', data, re.S)
if not match:
    raise SystemExit('could not locate last_config in AmneziaVPN.conf')

blob = ''.join(match.group(1).split())
padding = '=' * (-len(blob) % 4)
try:
    decoded = base64.b64decode(blob + padding, validate=True)
    payload = json.loads(decoded.decode('utf-8'))
except (ValueError, UnicodeDecodeError, json.JSONDecodeError) as exc:
    raise SystemExit(f'invalid last_config payload in {src}: {exc}') from exc

out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
PY
	chmod 600 "$OUT_CONFIG"
	printf '%s\n' "$OUT_CONFIG"
}

check_runtime_config() {
	python3 - "$SRC_CONFIG" "$OUT_CONFIG" <<'PY'
import base64
import json
import re
import sys
from pathlib import Path

src = Path(sys.argv[1])
out = Path(sys.argv[2])
if not src.is_file():
    raise SystemExit(f'missing source config: {src}')
if not out.is_file():
    raise SystemExit(f'missing runtime config: {out}')

data = src.read_text(encoding='utf-8', errors='strict')
match = re.search(r'last_config\s*=\s*@ByteArray\(([^)]*)\)', data, re.S)
if not match:
    raise SystemExit(f'could not locate last_config in {src}')

blob = ''.join(match.group(1).split())
padding = '=' * (-len(blob) % 4)
try:
    decoded = base64.b64decode(blob + padding, validate=True)
    expected = json.loads(decoded.decode('utf-8'))
    current = json.loads(out.read_text(encoding='utf-8'))
except (ValueError, UnicodeDecodeError, json.JSONDecodeError):
    raise SystemExit(f'invalid last_config payload in {src}')

if current != expected:
    raise SystemExit(f'{out} does not match imported AmneziaVPN payload')

raise SystemExit(0)
PY
}

case "${1:-import}" in
import)
	if [[ ! -f "$SRC_CONFIG" ]]; then
		printf 'ERROR: missing source config: %s\n' "$SRC_CONFIG" >&2
		exit 1
	fi
	write_runtime_config
	;;
show-path)
	printf '%s\n' "$OUT_CONFIG"
	;;
check)
	check_runtime_config
	;;
*)
	usage >&2
	exit 2
	;;
esac
