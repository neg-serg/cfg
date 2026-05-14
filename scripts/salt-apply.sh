#!/usr/bin/env zsh
# salt-apply.sh — apply Salt states (daemon-aware)
#
# Bootstraps venv + runtime config on first run, then uses the running
# salt-daemon if available, otherwise falls back to direct salt-call.
# Runs chezmoi apply after a successful state run.
# Refreshes drift baseline after a fully successful apply (RC=0).
#
# Usage:
#   scripts/salt-apply.sh                        # apply system_description
#   scripts/salt-apply.sh cachyos                # smoke-test bootstrap
#   scripts/salt-apply.sh hardware --test        # dry-run a specific state
#   scripts/salt-apply.sh kernel_modules
#   scripts/salt-apply.sh auto                   # minimal-rollout mode (git diff)
#   scripts/salt-apply.sh auto --plan            # show impact plan, no exec
#   scripts/salt-apply.sh auto --plan file1.sls  # plan with explicit files
#   scripts/salt-apply.sh --force                # skip contract validation
#   scripts/salt-apply.sh hardware --force       # apply with force
#
# Auto mode:
#   git diff against last-applied-commit marker (stored in .salt_runtime/)
#   → salt_impact.py maps changed files to minimal Salt state target.
#   Falls back to system_description for shared inputs, multi-target, or
#   unmapped files. Marker advances on every successful apply.
#   Override: set AUTO_BASE env var to any git ref.
#   Disable: SALT_AUTO_DISABLE=1 forces system_description unconditionally.
#
# Gating:
#   Maintenance lock is always held during apply (suppresses salt-monitor
#   alerts). Drift baseline is refreshed only on RC=0 + chezmoi success.
#   Contract validation runs before every apply; use --force to skip it.
#
# Environment:
#   SALT_DAEMON_SOCK  Unix socket path (default: /tmp/salt-daemon.sock)
#   SALT_LOG_FILE     Override log file path
#   AUTO_BASE         Git diff base for auto mode (default: last-applied marker or HEAD~1)
#   SALT_AUTO_DISABLE Disable minimal-rollout, force system_description

set -euo pipefail

SCRIPT_DIR="${0:A:h}"

# Early pretty loading for auto-mode messages and general output
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/pretty.sh" 2>/dev/null || true
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VENV_DIR="${PROJECT_DIR}/.venv"
RUNTIME_CONFIG_DIR="${PROJECT_DIR}/.salt_runtime"
DAEMON_SOCK="${SALT_DAEMON_SOCK:-/run/salt-daemon.sock}"
DAEMON_SCRIPT="${SCRIPT_DIR}/salt-daemon.py"
source "${SCRIPT_DIR}/salt-runtime.sh"

STATE="system_description"
TEST_MODE=false
PLAN_MODE=false
PLAN_FILES=()
AUDIT_MODE=false
FORCE_MODE=false

for arg in "$@"; do
	case "$arg" in
	--plan) PLAN_MODE=true ;;
	--test | --dry-run) TEST_MODE=true ;;
	--audit) AUDIT_MODE=true ;;
	--force | -f) FORCE_MODE=true ;;
	-*)
		pretty::fail "Unknown flag: $arg"
		exit 1
		;;
	*)
		if [[ "$STATE" == "auto" && "$PLAN_MODE" == true && "$arg" != "auto" ]]; then
			PLAN_FILES+=("$arg")
		else
			STATE="$arg"
		fi
		;;
	esac
done

if [[ "$STATE" == "auto" && "$PLAN_MODE" == true ]]; then
	if [[ ${#PLAN_FILES[@]} -eq 0 ]]; then
		PLAN_FILES=("states/system_description.sls")
	fi
	python3 "${SCRIPT_DIR}/salt_impact.py" --files "${PLAN_FILES[@]}"
	exit $?
fi

AUTO_MODE=false
if [[ "$STATE" == "auto" ]]; then
	AUTO_MODE=true
	if [[ -n "${SALT_AUTO_DISABLE:-}" ]]; then
		pretty::warn "auto: disabled via SALT_AUTO_DISABLE, applying system_description"
		STATE="system_description"
	else
		AUTO_BASE="${AUTO_BASE:-}"
		MARKER_FILE="${RUNTIME_CONFIG_DIR}/last-applied-commit"

		if [[ -z "$AUTO_BASE" && -f "$MARKER_FILE" ]]; then
			AUTO_BASE=$(cat "$MARKER_FILE")
		elif [[ -z "$AUTO_BASE" ]]; then
			AUTO_BASE="HEAD~1"
		fi

		CHANGED_STR=$(git -C "$PROJECT_DIR" diff --name-only "$AUTO_BASE" 2>/dev/null || true)

		if [[ -z "$CHANGED_STR" ]]; then
			if $FORCE_MODE; then
				pretty::info "auto: no changed files — --force, applying system_description"
				STATE="system_description"
			else
				pretty::ok "auto: no changed files since $AUTO_BASE, nothing to apply"
				exit 0
			fi
		else
			CHANGED_FILES=(${(f)CHANGED_STR})
			PLAN_JSON=$(python3 "${SCRIPT_DIR}/salt_impact.py" \
				--files "${CHANGED_FILES[@]}" --json 2>/dev/null || \
				python3 -c "import json; print(json.dumps({'changed_files':[],'selected_states':[],'fallback_reasons':['salt_impact.py failed'],'final_target':'system_description'}))")

			pretty::section "Salt impact plan"
			echo "$PLAN_JSON" | python3 -c "
import json, sys
plan = json.load(sys.stdin)
cf = plan.get('changed_files', [])
ss = plan.get('selected_states', [])
fr = plan.get('fallback_reasons', [])
print(f'Changed files ({len(cf)}):')
for f in cf:
    print(f'  - {f}')
if ss:
    print('Target states: ' + ', '.join(ss))
else:
    print('Target states: none (fallback)')
if fr:
    for r in fr:
        print(f'Reason: {r}')
print(f'Result: {plan[\"final_target\"]}')
print('------------------------')
"
			STATE=$(echo "$PLAN_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin)['final_target'])")
			if [[ "$STATE" == "none" ]]; then
				pretty::ok "auto: no impactful changes, nothing to apply"
				exit 0
			fi
			[[ "$STATE" != "system_description" ]] && pretty::info "auto: narrowed to $STATE"
		fi
	fi
fi

# Normalise state name: accept both group/core and group.core
SALT_STATE="${STATE//\//.}"

LOG_DIR="${PROJECT_DIR}/logs"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_STEM="${STATE//\//-}"
LOG_FILE="${SALT_LOG_FILE:-${LOG_DIR}/${LOG_STEM}-${TIMESTAMP}.log}"
mkdir -p "${LOG_DIR}"
install -m 0640 /dev/null "${LOG_FILE}"

# ── Bootstrap: venv + Salt install ────────────────────────────────────────────
repair_stale_venv_entrypoints() {
	local launcher_path="$1"
	local expected_shebang="#!${VENV_DIR}/bin/python3"

	[[ -f "$launcher_path" ]] || return 0
	grep -qF "$expected_shebang" "$launcher_path" && return 0

	pretty::warn "Repairing relocated venv entrypoints"
	"$VENV_DIR/bin/python3" -m pip install --force-reinstall -r "${PROJECT_DIR}/requirements.txt"
}

bootstrap_salt() {
	if [[ ! -d "$VENV_DIR" ]]; then
		pretty::phase "Bootstrapping Salt (creating venv)"
		python3 -m venv "$VENV_DIR"
	fi

	if [[ ! -f "$VENV_DIR/bin/salt-call" ]]; then
		pretty::phase "Installing Salt and dependencies"
		"$VENV_DIR/bin/pip" install -r "${PROJECT_DIR}/requirements.txt"
	fi

	repair_stale_venv_entrypoints "$VENV_DIR/bin/pytest"
	repair_stale_venv_entrypoints "$VENV_DIR/bin/salt-call"

	# Python 3.14 sitecustomize: auto-apply salt_compat patches on any venv import
	local site_pkgs sitecustomize_file
	site_pkgs=$("$VENV_DIR/bin/python3" -c "import site; print(site.getsitepackages()[0])" 2>/dev/null) || return 0
	[[ -d "$site_pkgs" ]] || return 0
	sitecustomize_file="$site_pkgs/sitecustomize.py"
	# Write only if missing or root-owned (previous manual sudo fix)
	if [[ ! -f "$sitecustomize_file" ]] || [[ ! -w "$sitecustomize_file" ]]; then
		"${SUDO_CMD[@]}" tee "$sitecustomize_file" > /dev/null <<'PYEOF'
import os, sys
_this_dir = os.path.dirname(__file__)
# site-packages → python3.14 → lib → .venv → cfg (repo root)
_repo_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(_this_dir))))
_scripts_dir = os.path.join(_repo_root, "scripts")
if os.path.isdir(_scripts_dir):
    sys.path.insert(0, _scripts_dir)
    try:
        import salt_compat
        salt_compat.patch()
    except ImportError:
        pass
PYEOF
	fi
}

# ── Runtime config: generate .salt_runtime/minion ─────────────────────────────
setup_config() {
	salt_runtime_prepare_dirs "${PROJECT_DIR}" "${RUNTIME_CONFIG_DIR}"
	salt_runtime_write_minion_config "${PROJECT_DIR}" "${RUNTIME_CONFIG_DIR}" apply
}

repair_runtime_permissions() {
	[[ -d "${RUNTIME_CONFIG_DIR}" ]] || return 0
	"${SUDO_CMD[@]}" chown -R "$(id -u):$(id -g)" "${RUNTIME_CONFIG_DIR}"
	find "${RUNTIME_CONFIG_DIR}" -type d -exec chmod u+rwx {} +
	find "${RUNTIME_CONFIG_DIR}" -type f -exec chmod u+rw {} +
}

# ── Sudo: prefer NOPASSWD, fall back to .password file ────────────────────────
get_sudo() {
	if sudo -n true 2>/dev/null; then
		SUDO_CMD=(sudo)
		SUDO_PASS=""
	elif [[ -f "${PROJECT_DIR}/.password" ]]; then
		SUDO_CMD=(sudo -S)
		SUDO_PASS=$(<"${PROJECT_DIR}/.password")
	else
		pretty::fail "no NOPASSWD sudo and no .password file found"
		pretty::info "either configure NOPASSWD or create .password"
		exit 1
	fi
}

# ── Daemon helpers ─────────────────────────────────────────────────────────────
daemon_running() {
	[[ -S "$DAEMON_SOCK" ]] || return 1
	if python3 -c "
import socket, sys
try:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(1)
    s.connect('$DAEMON_SOCK')
    s.close()
except Exception:
    sys.exit(1)
" 2>/dev/null; then
		return 0
	fi
	# Socket exists but daemon is dead — remove stale socket so ensure_daemon
	# can start a fresh daemon without bind() failing on the existing path.
	"${SUDO_CMD[@]}" rm -f "$DAEMON_SOCK"
	return 1
}

ensure_daemon() {
	daemon_running && return 0
	[[ -x "$DAEMON_SCRIPT" ]] || return 1
	pretty::info "starting salt-daemon in background..."
	"${SUDO_CMD[@]}" "$DAEMON_SCRIPT" \
		--config-dir "$RUNTIME_CONFIG_DIR" \
		--socket "$DAEMON_SOCK" \
		--log-level warning &>/dev/null &
	for _ in $(seq 1 10); do
		sleep 0.5
		daemon_running && return 0
	done
	return 1 # timeout — fall back to direct
}

# ── Run via daemon ─────────────────────────────────────────────────────────────
run_via_daemon() {
	pretty::header "Apply ${STATE} (via daemon)"
	pretty::info "Log: ${LOG_FILE}"

	local kwargs='{}'
	$TEST_MODE && kwargs='{"test":true}'

	local exit_code
	exit_code=$(
		python3 - <<PYEOF
import json, socket, sys
req = json.dumps({
    'state': '${SALT_STATE}',
    'kwargs': json.loads('${kwargs}'),
    'log_file': '${LOG_FILE}'
}) + '\n'
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect('${DAEMON_SOCK}')
s.sendall(req.encode())
buf = b''
rc = 1
try:
    while True:
        chunk = s.recv(4096)
        if not chunk:
            break
        buf += chunk
        while b'\n' in buf:
            line, buf = buf.split(b'\n', 1)
            if not line:
                continue
            try:
                msg = json.loads(line.decode())
            except json.JSONDecodeError:
                continue
            if msg.get('type') == 'stdout':
                print(msg.get('line', ''), file=sys.stderr)
            if msg.get('type') == 'exit':
                rc = msg.get('code', 0)
except ConnectionResetError:
    rc = 75
s.close()
print(rc)
PYEOF
	)
	return "${exit_code:-1}"
}

# ── Fallback: direct salt-call ─────────────────────────────────────────────────
SALT_RUNNER="${SCRIPT_DIR}/salt_runner.py"

run_direct() {
	pretty::header "Apply ${STATE} (direct)"
	pretty::info "Log: ${LOG_FILE}"
	pretty::dim "Start salt-daemon for faster subsequent runs"

	local -a salt_cmd
	salt_cmd=(
		"${SUDO_CMD[@]}" "$VENV_DIR/bin/python3" -u "$SALT_RUNNER"
		--config-dir="${RUNTIME_CONFIG_DIR}"
		--local --log-level=warning --force-color
		--log-file="${LOG_FILE}" --log-file-level=debug
		state.sls "${SALT_STATE}"
	)
	$TEST_MODE && salt_cmd+=(test=True)

	# Let Salt stream native highstate output directly to the terminal
	# while tee also appends it to the log file for post-run inspection.
	if [[ -n "${SUDO_PASS:-}" ]]; then
		echo "$SUDO_PASS" | "${salt_cmd[@]}" 2>&1 | tee -a "${LOG_FILE}"
		local rc="${pipestatus[2]}"
	else
		"${salt_cmd[@]}" 2>&1 | tee -a "${LOG_FILE}"
		local rc="${pipestatus[1]}"
	fi

	return "$rc"
}

# ── Maintenance lock (suppresses salt-monitor alerts during apply) ─────────────
MAINTENANCE_LOCK="${HOME}/.cache/salt-monitor/maintenance.lock"

maintenance_lock_create() {
	mkdir -p "${HOME}/.cache/salt-monitor"
	touch "$MAINTENANCE_LOCK"
}

maintenance_lock_remove() {
	rm -f "$MAINTENANCE_LOCK"
}

# ── Pre-flight: source shared libraries ───────────────────────────────────────
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/pretty.sh" 2>/dev/null || true

# ── Bootstrap helpers (after pretty.sh loaded) ────────────────────────────────
# Set SALT_SKIP_CONTRACTS=1 or use --force to bypass (e.g., bootstrap scenarios)
if [[ -z "${SALT_SKIP_CONTRACTS:-}" && "$FORCE_MODE" != true ]]; then
	CONTRACT_OUTPUT=$(python3 "${SCRIPT_DIR}/salt_contracts.py" 2>&1)
	CONTRACT_RC=$?
	if [[ $CONTRACT_RC -ne 0 ]]; then
		VIOLATION_COUNT=$(echo "$CONTRACT_OUTPUT" | grep -c . 2>/dev/null || echo 0)
		if declare -f pretty::header >/dev/null 2>&1; then
			pretty::fail "${VIOLATION_COUNT} data contract violation(s)"
			echo "$CONTRACT_OUTPUT"
			pretty::info "Fix the violations above, then re-run"
			pretty::info "Bypass: just force  |  Inspect: python3 scripts/salt_contracts.py --verbose"
		else
			pretty::fail "Data contract violations detected"
			echo "$CONTRACT_OUTPUT"
			pretty::info "Fix: resolve violations, then re-run."
		fi
		exit 1
	fi
fi
bootstrap_salt
get_sudo
repair_runtime_permissions
setup_config

maintenance_lock_create
trap maintenance_lock_remove EXIT

if ensure_daemon; then
	run_via_daemon && RC=$? || RC=$?
	if [[ $RC -eq 75 ]]; then
		pretty::warn "daemon busy — falling back to direct salt-call"
		run_direct && RC=$? || RC=$?
	fi
else
	run_direct && RC=$? || RC=$?
fi

echo ""
if declare -f pretty::section >/dev/null 2>&1; then
    pretty::section "Apply ${STATE}"
    pretty::info "Log: ${LOG_FILE}"
else
    pretty::ok "Apply ${STATE} — exit ${RC}"
    echo "Log: ${LOG_FILE}"
fi

if [[ $RC -eq 0 ]]; then
    if declare -f pretty::ok >/dev/null 2>&1; then
        pretty::ok "All states applied successfully"
        pretty::phase 1 2 "Dotfiles (chezmoi)"
    else
        pretty::ok "${STATE}: all states passed"
        echo "--- Applying dotfiles ---"
    fi
    gpg-connect-agent updatestartuptty /bye &>/dev/null || true
    install -Dm644 "${PROJECT_DIR}/dotfiles/dot_config/chezmoi/chezmoi.toml" \
        "${HOME}/.config/chezmoi/chezmoi.toml" 2>/dev/null || true
    chezmoi_output=""
    if ! chezmoi_output=$(chezmoi apply --force --source "${PROJECT_DIR}/dotfiles" 2>&1); then
        echo ""
        if declare -f pretty::warn >/dev/null 2>&1; then
            if printf '%s\n' "$chezmoi_output" | rg -qi 'gopass|pinentry|failed to decrypt|decryption failed'; then
                pretty::warn "gopass locked — dotfiles skipped (Salt states OK)"
                pretty::info "Unlock: gopass show -o <key>"
            else
                pretty::fail "chezmoi apply failed"
                printf '%s\n' "$chezmoi_output"
                exit 1
            fi
        else
            printf '\033[33m━━━ chezmoi apply failed ━━━\033[0m\n'
            if printf '%s\n' "$chezmoi_output" | rg -qi 'gopass|pinentry|failed to decrypt|decryption failed'; then
                printf '\033[33m  Reason: gopass locked — Salt states OK, dotfiles skipped.\033[0m\n'
            else
                printf '%s\n' "$chezmoi_output"
                exit 1
            fi
        fi
    else
        declare -f pretty::ok >/dev/null 2>&1 && pretty::phase 2 2 "Dotfiles applied"
    fi
    if $AUTO_MODE; then
        git -C "$PROJECT_DIR" rev-parse HEAD > "${RUNTIME_CONFIG_DIR}/last-applied-commit" 2>/dev/null || true
    fi
    python3 "${PROJECT_DIR}/scripts/drift_state.py" refresh-expected \
        --project-dir "${PROJECT_DIR}" \
        --cache-dir "${HOME}/.cache/salt-monitor" \
        --salt-target "${STATE}"
    if $AUDIT_MODE; then
        TEST_FLAG=""
        $TEST_MODE && TEST_FLAG="--test"
        python3 "${SCRIPT_DIR}/salt_audit.py" --target "${STATE}" $TEST_FLAG
    fi
else
    JSON_FILE="${LOG_FILE}.json"
    if [[ -f "${JSON_FILE}" ]]; then
        # Machine-readable output from salt-daemon.py
        FAILED_COUNT=$(python3 -c "
import json
with open('${JSON_FILE}') as f:
    data = json.load(f)
print(data['summary']['failed'])
" 2>/dev/null || echo 0)
        PASSED=$(python3 -c "
import json
with open('${JSON_FILE}') as f:
    data = json.load(f)
print(data['summary']['succeeded'])
" 2>/dev/null || echo 0)
        CHANGED=$(python3 -c "
import json
with open('${JSON_FILE}') as f:
    data = json.load(f)
print(data['summary']['changed'])
" 2>/dev/null || echo 0)
    else
        FAILED_COUNT=$(grep -c 'Result: False' "${LOG_FILE}" 2>/dev/null || echo 0)
        PASSED=$(( $(grep -c 'Result: True' "${LOG_FILE}" 2>/dev/null || echo 0) ))
        CHANGED=0
    fi
    echo ""
    if [[ $FAILED_COUNT -gt 0 && -f "${LOG_FILE}" ]]; then
        if declare -f pretty::summary_line >/dev/null 2>&1; then
            pretty::summary_line "$PASSED" "$FAILED_COUNT" "States"
        fi
        if [[ -f "${JSON_FILE}" ]]; then
            python3 -c "
import json
with open('${JSON_FILE}') as f:
    data = json.load(f)
for d in data.get('details', []):
    if d.get('result') is False:
        print(f\"  [FAIL] {d['id']}: {d['comment']}\")
" 2>/dev/null
        else
            awk '/^----------$/{buf=\$0; while(getline>0){buf=buf\"\n\"\$0; if(/Result: False/){print buf; print \"\"; break} if(/^----------$/){break}}}' "${LOG_FILE}" 2>/dev/null
        fi
        if declare -f pretty::info >/dev/null 2>&1; then
            pretty::info "grep 'Result: False' ${LOG_FILE}"
            pretty::info "grep 'Requisite.*not found' ${LOG_FILE}"
            pretty::info "just validate  |  python3 scripts/salt_contracts.py"
        else
            pretty::fail "State failures detected"
            pretty::info "grep 'Result: False' ${LOG_FILE}"
            pretty::info "grep 'Requisite.*not found' ${LOG_FILE}"
            pretty::info "just validate  |  python3 scripts/salt_contracts.py"
        fi
    else
        if declare -f pretty::fail >/dev/null 2>&1; then
            pretty::fail "apply failed (exit ${RC}) — pre-flight or salt-call crash"
        else
            pretty::fail "${STATE}: apply failed (exit ${RC}) — see log above"
        fi
    fi
    exit $RC
fi
