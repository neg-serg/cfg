"""Contract tests for shared shell/bootstrap scripts."""

import json
import os
import stat
import subprocess
import textwrap
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent


def write_executable(path: Path, content: str) -> None:
    path.write_text(textwrap.dedent(content).lstrip())
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


def test_salt_runtime_module_exposes_required_functions():
    source = (REPO_ROOT / "scripts" / "salt-runtime.sh").read_text()

    assert "salt_runtime_prepare_dirs()" in source
    assert "salt_runtime_write_minion_config()" in source
    assert "salt_runtime_clear_stale_proc_locks()" in source


def test_salt_apply_and_validate_source_runtime_module():
    apply_source = (REPO_ROOT / "scripts" / "salt-apply.sh").read_text()
    validate_source = (REPO_ROOT / "scripts" / "salt-validate.sh").read_text()
    apply_call = 'salt_runtime_write_minion_config "${PROJECT_DIR}" "${RUNTIME_CONFIG_DIR}" apply'
    validate_call = 'salt_runtime_write_minion_config "${project_dir}" "${runtime}" validate'

    assert 'source "${SCRIPT_DIR}/salt-runtime.sh"' in apply_source
    assert 'source "${script_dir}/salt-runtime.sh"' in validate_source
    assert apply_call in apply_source
    assert validate_call in validate_source


def test_salt_apply_uses_daemon_stream_instead_of_tailing_log_file():
    apply_source = (REPO_ROOT / "scripts" / "salt-apply.sh").read_text()

    assert 'tail -n 0 -f "${LOG_FILE}" &' not in apply_source
    assert "if msg.get('type') == 'stdout':" in apply_source
    assert "print(msg.get('line', ''), file=sys.stderr)" in apply_source


def test_salt_apply_always_runs_chezmoi_after_success():
    apply_source = (REPO_ROOT / "scripts" / "salt-apply.sh").read_text()

    assert 'echo "--- Applying dotfiles (chezmoi) ---"' in apply_source
    assert 'chezmoi apply --force --source "${PROJECT_DIR}/dotfiles"' in apply_source
    assert "No Salt changes; skipping chezmoi" not in apply_source
    assert "salt_has_changes" not in apply_source


def test_salt_apply_treats_auto_scope_as_full_system_description_for_now():
    apply_source = (REPO_ROOT / "scripts" / "salt-apply.sh").read_text()

    assert 'STATE="auto"' not in apply_source
    assert 'if [[ "$STATE" == "auto" ]]; then' in apply_source
    assert 'STATE="system_description"' in apply_source
    assert "Minimal rollout planning is deferred" in apply_source


def test_salt_apply_auto_plan_delegates_to_planner_and_exits_before_apply_flow():
    apply_source = (REPO_ROOT / "scripts" / "salt-apply.sh").read_text()
    auto_plan_section = apply_source.split(
        'if [[ "$STATE" == "auto" && "$PLAN_MODE" == true ]]; then', 1
    )[1].split('if [[ "$STATE" == "auto" ]]; then', 1)[0]

    assert "PLAN_MODE=false" in apply_source
    assert "--plan) PLAN_MODE=true ;;" in apply_source
    assert 'if [[ "$STATE" == "auto" && "$PLAN_MODE" == true ]]; then' in apply_source
    assert 'python3 "${SCRIPT_DIR}/salt_impact.py"' in apply_source
    assert "exit $? " not in apply_source
    assert 'python3 "${SCRIPT_DIR}/salt_impact.py" "$@"' not in apply_source
    assert 'python3 "${SCRIPT_DIR}/salt_impact.py"' in auto_plan_section
    assert "bootstrap_salt" not in auto_plan_section
    assert "run_via_daemon" not in auto_plan_section
    assert "run_direct" not in auto_plan_section
    assert 'chezmoi apply --force --source "${PROJECT_DIR}/dotfiles"' not in auto_plan_section
    assert "exit $?" in auto_plan_section


def test_salt_apply_auto_plan_passes_explicit_files_to_salt_impact():
    source = (REPO_ROOT / "scripts" / "salt-apply.sh").read_text()

    assert "PLAN_FILES=()" in source
    assert 'PLAN_FILES+=("$arg")' in source or 'PLAN_FILES+=("${arg}")' in source
    assert 'python3 "${SCRIPT_DIR}/salt_impact.py" --files "${PLAN_FILES[@]}"' in source


def test_justfile_lint_delegates_to_script():
    justfile_source = (REPO_ROOT / "Justfile").read_text()
    lint_script_source = (REPO_ROOT / "scripts" / "lint-all.sh").read_text()

    assert "bash scripts/lint-all.sh" in justfile_source
    assert 'run_check "lint-jinja"' in lint_script_source
    assert 'run_check "yamllint"' in lint_script_source


def test_justfile_exposes_selective_validate_shortcuts():
    justfile_source = (REPO_ROOT / "Justfile").read_text()

    assert "validate-one STATE:" in justfile_source
    assert "scripts/salt-validate.sh -- {{STATE}}" in justfile_source
    assert "validate-some *STATES:" in justfile_source
    assert "scripts/salt-validate.sh -- {{STATES}}" in justfile_source


def test_justfile_exposes_auto_plan_wrappers():
    source = (REPO_ROOT / "Justfile").read_text()

    assert "apply-plan *FILES:" in source
    assert "./scripts/salt-apply.sh auto --plan {{FILES}}" in source
    assert "apply-auto:" in source
    assert "./scripts/salt-apply.sh auto" in source


def test_salt_apply_bootstrap_repairs_relocated_venv_launchers():
    source = (REPO_ROOT / "scripts" / "salt-apply.sh").read_text()

    assert "repair_stale_venv_entrypoints()" in source
    assert 'launcher_path="$1"' in source
    assert 'expected_shebang="#!${VENV_DIR}/bin/python3"' in source
    assert 'grep -qF "$expected_shebang" "$launcher_path"' in source
    assert (
        '"$VENV_DIR/bin/python3" -m pip install --force-reinstall -r '
        '"${PROJECT_DIR}/requirements.txt"' in source
    )
    assert 'repair_stale_venv_entrypoints "$VENV_DIR/bin/pytest"' in source
    assert 'repair_stale_venv_entrypoints "$VENV_DIR/bin/salt-call"' in source


def test_salt_apply_refreshes_drift_baseline_after_success():
    source = (REPO_ROOT / "scripts" / "salt-apply.sh").read_text()

    assert 'python3 "${PROJECT_DIR}/scripts/drift_state.py" refresh-expected' in source
    assert '"${HOME}/.cache/salt-monitor"' in source


def test_salt_apply_repairs_runtime_ownership_before_setup_config():
    source = (REPO_ROOT / "scripts" / "salt-apply.sh").read_text()
    main_flow = source.split("# ── Main", 1)[1]

    assert "repair_runtime_permissions()" in source
    assert '"${SUDO_CMD[@]}" chown -R "$(id -u):$(id -g)" "${RUNTIME_CONFIG_DIR}"' in source
    assert 'find "${RUNTIME_CONFIG_DIR}" -type d -exec chmod u+rwx {} +' in source
    assert 'find "${RUNTIME_CONFIG_DIR}" -type f -exec chmod u+rw {} +' in source
    assert main_flow.index("repair_runtime_permissions") < main_flow.index("setup_config")


def test_justfile_exposes_drift_commands():
    source = (REPO_ROOT / "Justfile").read_text()

    assert "drift:" in source
    assert 'python3 scripts/drift_state.py fast --project-dir "${PWD}"' in source
    assert "drift-full:" in source
    assert 'python3 scripts/drift_state.py full --project-dir "${PWD}"' in source
    assert "drift-status:" in source
    assert 'python3 scripts/drift_state.py status --project-dir "${PWD}"' in source


def test_chezmoi_watch_uses_cfg_dotfiles_path():
    source = (REPO_ROOT / "dotfiles" / "dot_local" / "bin" / "executable_chezmoi-watch").read_text()

    assert 'src_dir="${HOME}/src/cfg/dotfiles"' in source
    assert 'src_dir="${HOME}/src/salt/dotfiles"' not in source


def test_health_check_marks_http_probe_failures_as_unhealthy():
    source = (REPO_ROOT / "scripts" / "health-check.sh").read_text()

    assert 'http_ok="FAIL"' in source
    assert 'status="unhealthy"' in source
    assert 'results[i]=$(echo "$entry" | awk -F\'\\t\' -v h="$http_ok" -v s="$status"' in source


def test_health_check_tracks_named_quadlet_units():
    source = (REPO_ROOT / "scripts" / "health-check.sh").read_text()

    assert "jellyfin-container" in source
    assert "transmission-container" in source
    assert "adguardhome-container" in source
    assert "loki-container" in source
    assert "promtail-container" in source
    assert "grafana-container" in source
    assert "bitcoind-container" in source


def test_health_check_uses_catalog_ported_grafana_api_health_endpoint():
    source = (REPO_ROOT / "scripts" / "health-check.sh").read_text()

    assert 'HEALTHCHECKS["grafana-container"]="3030:/api/health"' in source


def test_health_check_only_checks_optional_monitoring_units_when_host_features_enable_them():
    source = (REPO_ROOT / "scripts" / "health-check.sh").read_text()
    loki_expr = (
        "print('true' if host.get('features', {}).get('monitoring', {}).get('loki', "
        "False) else 'false')"
    )
    promtail_expr = (
        "print('true' if host.get('features', {}).get('monitoring', {}).get('promtail', "
        "False) else 'false')"
    )
    grafana_expr = (
        "print('true' if host.get('features', {}).get('monitoring', {}).get('grafana', "
        "False) else 'false')"
    )

    assert loki_expr in source
    assert promtail_expr in source
    assert grafana_expr in source
    assert 'OPTIONAL_SYSTEM+=("loki-container")' in source
    assert 'OPTIONAL_SYSTEM+=("promtail-container")' in source
    assert 'OPTIONAL_SYSTEM+=("grafana-container")' in source


def test_deploy_guide_uses_cfg_project_dir():
    source = (REPO_ROOT / "scripts" / "deploy-cachyos-ext4.sh").read_text()

    assert "~/src/cfg" in source
    assert "~/src/salt" not in source


def test_hot_reload_uses_nanoclaw_quadlet_unit():
    source = (REPO_ROOT / "scripts" / "hot-reload.sh").read_text()

    assert "SVC_UNIT[nanoclaw]='nanoclaw-container.service'" in source
    assert "SVC_TYPE[nanoclaw]='quadlet'" in source


def test_hot_reload_script_parses_in_zsh():
    script = REPO_ROOT / "scripts" / "hot-reload.sh"

    result = subprocess.run(["zsh", "-n", str(script)], capture_output=True, text=True)

    assert result.returncode == 0, result.stderr


def test_pw_route_script_exposes_named_rme_output_pairs():
    source = (REPO_ROOT / "dotfiles" / "dot_local" / "bin" / "executable_pw-route").read_text()

    assert 'targets[an]="0 1"' in source
    assert 'targets[aes]="2 3"' in source
    assert 'targets[spdif]="4 5"' in source
    assert 'targets[phones]="6 7"' in source
    assert "status)" in source
    assert "route_monitor_pair()" in source
    assert "monitor_AUX0" in source
    assert "monitor_AUX1" in source


def test_pw_route_script_exposes_toggle_cycle():
    source = (REPO_ROOT / "dotfiles" / "dot_local" / "bin" / "executable_pw-route").read_text()

    assert "toggle)" in source
    assert "get_current_target()" in source
    assert 'case "$current_target" in' in source
    assert 'an) next_target="aes" ;;' in source
    assert 'aes) next_target="spdif" ;;' in source
    assert 'spdif) next_target="phones" ;;' in source
    assert 'phones) next_target="an" ;;' in source


def test_pw_route_script_parses_in_zsh():
    script = REPO_ROOT / "dotfiles" / "dot_local" / "bin" / "executable_pw-route"

    result = subprocess.run(["zsh", "-n", str(script)], capture_output=True, text=True)

    assert result.returncode == 0, result.stderr


def test_set_zen_proxy_targets_real_zen_profile_path():
    source = (REPO_ROOT / "scripts" / "set-zen-proxy").read_text()

    assert 'PROFILES_INI = Path.home() / ".config/zen/profiles.ini"' in source
    assert "def resolve_profile_path() -> Path:" in source
    assert "Path=qnkh60k3.Default (release)" not in source


def test_yt_alias_uses_wrapper_based_defaults():
    aliases = yaml.safe_load(
        (REPO_ROOT / "dotfiles" / "dot_config" / "aliae" / "aliae.yaml").read_text()
    )["alias"]
    yt = next(entry for entry in aliases if entry["name"] == "yt")

    assert yt["value"] == (
        "yt-dlp --no-playlist --embed-metadata --embed-thumbnail "
        '--embed-subs --sub-langs=all -o "%(title)s [%(id)s].%(ext)s"'
    )
    assert "--cookies-from-browser firefox:$HOME/.floorp/" not in yt["value"]
    assert "--downloader aria2c" not in yt["value"]


def test_yta_alias_adds_info_json_to_wrapper_based_defaults():
    aliases = yaml.safe_load(
        (REPO_ROOT / "dotfiles" / "dot_config" / "aliae" / "aliae.yaml").read_text()
    )["alias"]
    yta = next(entry for entry in aliases if entry["name"] == "yta")

    assert yta["value"] == (
        "yt-dlp --no-playlist --embed-metadata --embed-thumbnail "
        "--embed-subs --sub-langs=all --write-info-json -o "
        '"%(title)s [%(id)s].%(ext)s"'
    )
    assert "--cookies-from-browser firefox:$HOME/.floorp/" not in yta["value"]
    assert "--downloader aria2c" not in yta["value"]


def test_amnezia_import_script_exposes_cli_subcommands_and_source_paths():
    source = (REPO_ROOT / "scripts" / "amnezia-import-tun-config.sh").read_text()

    assert "set -euo pipefail" in source
    assert "~/.config/AmneziaVPN.ORG/AmneziaVPN.conf" in source
    assert "~/.config/sing-box-tun/config.json" in source
    assert "import|show-path|check" in source
    assert "show-path" in source
    assert "check)" in source
    assert "config.json" in source


def test_amnezia_import_script_parses_in_zsh():
    script = REPO_ROOT / "scripts" / "amnezia-import-tun-config.sh"

    result = subprocess.run(["zsh", "-n", str(script)], capture_output=True, text=True)

    assert result.returncode == 0, result.stderr


def test_amnezia_import_check_ignores_router_managed_rule_block():
    source = (REPO_ROOT / "scripts" / "amnezia-import-tun-config.sh").read_text()

    assert 'current.get("route", {}).get("rules", [])' in source
    assert 'rule.get("tag") != "vpn-split-router-managed"' in source
    assert 'current_route["rules"] = filtered_rules' in source
    assert 'expected.get("route", {}).setdefault("rules", [])' in source


def test_telethon_bridge_react_script_contains_guarded_start_restart_logic():
    source = (REPO_ROOT / "scripts" / "telethon-bridge-react.sh").read_text()

    assert "set -euo pipefail" in source
    assert 'STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"' in source
    assert 'SESSION_FILE="${STATE_HOME}/telethon-bridge/telethon.session"' in source
    assert 'systemctl --user is-active --quiet "$UNIT"' in source
    assert 'systemctl --user restart "$UNIT"' in source
    assert 'systemctl --user start "$UNIT"' in source


def test_telethon_bridge_react_script_parses_in_zsh():
    script = REPO_ROOT / "scripts" / "telethon-bridge-react.sh"

    result = subprocess.run(["zsh", "-n", str(script)], capture_output=True, text=True)

    assert result.returncode == 0, result.stderr


def test_telethon_bridge_init_validates_missing_api_credentials_before_casting():
    source = (REPO_ROOT / "states" / "scripts" / "telethon-bridge-init.py").read_text()

    assert 'CONFIG_PATH = Path.home() / ".config" / "telethon-bridge" / "config.yaml"' in source
    assert 'api_id_raw = tg.get("api_id")' in source
    assert 'api_hash = tg.get("api_hash") or ""' in source
    assert '"Error: Telegram API credentials are missing from "' in source
    assert '"~/.config/telethon-bridge/config.yaml"' in source
    assert "int(api_id_raw)" in source


def test_telethon_bridge_runtime_uses_configured_proxy_tuple():
    source = (REPO_ROOT / "states" / "scripts" / "telethon-bridge.py").read_text()

    assert 'proxy_cfg = tg.get("proxy") or {}' in source
    assert "proxy = None" in source
    assert "import socks" in source
    assert "proxy = (socks.SOCKS5, proxy_host, int(proxy_port))" in source
    assert 'TelegramClient(session_path, int(tg["api_id"]), tg["api_hash"], proxy=proxy)' in source


def test_whisper_stt_service_uses_absolute_whisper_cli_path():
    source = (
        REPO_ROOT.parent / "speech" / "engines" / "systemd" / "whisper-stt.service"
    ).read_text()

    assert "--whisper-bin %h/src/speech/engines/whisper.cpp/build-cpu/bin/whisper-cli \\" in source
    assert "--whisper-bin whisper-cli \\" not in source


def test_speech_repo_ignores_local_cosyvoice_and_xtts_artifacts():
    source = (REPO_ROOT.parent / "speech" / ".gitignore").read_text()

    assert "engines/config/cosyvoice.env" in source
    assert "engines/config/xtts.env" in source
    assert "engines/cosyvoice-models/" in source
    assert "engines/xtts-assets/" in source
    assert "engines/cosyvoice/" in source


def test_health_check_parses_user_service_names_from_yaml_mappings():
    source = (REPO_ROOT / "scripts" / "health-check.sh").read_text()

    assert "grep -oP '^\\s+- \\{name:\\s*\\K[^,}]+'" in source


def test_health_check_uses_expected_states_for_timers_and_oneshot_units():
    source = (REPO_ROOT / "scripts" / "health-check.sh").read_text()

    assert 'check_user_service "$timer" "active (waiting)"' in source
    assert 'check_user_service "openrgb-profile.service" "inactive"' in source


def test_health_check_skips_feature_gated_disabled_user_units():
    source = (REPO_ROOT / "scripts" / "health-check.sh").read_text()

    assert "grep -v 'features:'" in source


def test_health_check_uses_host_aware_optional_unbound_and_cronie_checks():
    source = (REPO_ROOT / "scripts" / "health-check.sh").read_text()

    assert "host_name=$(hostnamectl --static 2>/dev/null || hostname)" in source
    assert 'SYSTEM_SERVICES+=("unbound")' in source
    assert 'SYSTEM_SERVICES+=("cronie")' in source


def test_health_check_uses_dash_keys_for_quadlet_http_checks():
    source = (REPO_ROOT / "scripts" / "health-check.sh").read_text()

    assert 'HEALTHCHECKS["loki-container"]="3100:/ready"' in source
    assert 'HEALTHCHECKS["promtail-container"]="9080:/ready"' in source
    assert 'HEALTHCHECKS["grafana-container"]="3030:/api/health"' in source
    assert 'HEALTHCHECKS["adguardhome-container"]="3000:/"' in source


def test_salt_validate_does_not_execute_stale_venv_shebang_wrappers():
    source = (REPO_ROOT / "scripts" / "salt-validate.sh").read_text()

    assert ".venv/bin/salt-call" not in source
    assert '"$salt_python" -m salt.scripts salt_call' in source


def test_salt_validate_supports_named_state_targets():
    source = (REPO_ROOT / "scripts" / "salt-validate.sh").read_text()

    assert "resolve_target()" in source
    assert 'candidate="states/${target}.sls"' in source


def test_salt_validate_accepts_state_paths_and_deduplicates_targets():
    source = (REPO_ROOT / "scripts" / "salt-validate.sh").read_text()

    assert 'if [[ "$target" == states/*.sls ]]; then' in source
    assert 'seen_targets["$resolved"]=1' in source


def test_salt_validate_fails_clearly_for_missing_targets():
    source = (REPO_ROOT / "scripts" / "salt-validate.sh").read_text()

    assert "error: unknown state target:" in source
    assert "exit 1" in source


def test_salt_validate_rejects_empty_explicit_target_list():
    source = (REPO_ROOT / "scripts" / "salt-validate.sh").read_text()

    assert "if [[ $# -eq 0 ]]; then" in source
    assert 'echo "error: -- requires at least one target" >&2' in source


def test_salt_validate_normalizes_nested_state_paths_for_show_sls():
    source = (REPO_ROOT / "scripts" / "salt-validate.sh").read_text()

    assert r'name="${name//\//.}"' in source


def test_salt_validate_writes_machine_readable_summary_artifact_per_run(tmp_path):
    repo_dir = tmp_path / "repo"
    scripts_dir = repo_dir / "scripts"
    states_dir = repo_dir / "states"
    venv_bin_dir = repo_dir / ".venv" / "bin"
    bin_dir = tmp_path / "bin"
    summary_path = tmp_path / "artifacts" / "salt-validate-summary.json"

    scripts_dir.mkdir(parents=True)
    states_dir.mkdir()
    venv_bin_dir.mkdir(parents=True)
    bin_dir.mkdir()

    (scripts_dir / "salt-validate.sh").write_text(
        (REPO_ROOT / "scripts" / "salt-validate.sh").read_text()
    )
    (scripts_dir / "salt-validate.sh").chmod(0o755)

    write_executable(
        scripts_dir / "salt-runtime.sh",
        """
        #!/usr/bin/env bash
        set -euo pipefail

        salt_runtime_prepare_dirs() {
          mkdir -p "$2"
        }

        salt_runtime_write_minion_config() {
          :
        }

        salt_runtime_clear_stale_proc_locks() {
          :
        }

        salt_runtime_reset_validate_cache() {
          :
        }
        """,
    )

    (states_dir / "alpha.sls").write_text("alpha: {}\n")
    (states_dir / "beta.sls").write_text("beta: {}\n")

    write_executable(
        venv_bin_dir / "python3",
        """
        #!/usr/bin/env bash
        set -euo pipefail

        state_name="${*: -2:1}"
        if [[ "$state_name" == "beta" ]]; then
          exit 1
        fi
        exit 0
        """,
    )

    write_executable(
        bin_dir / "parallel",
        """
        #!/usr/bin/env bash
        set -euo pipefail

        joblog=""
        args=("$@")
        index=0
        while [[ $index -lt $# ]]; do
          if [[ "${args[$index]}" == "--joblog" ]]; then
            index=$((index + 1))
            joblog="${args[$index]}"
          fi
          if [[ "${args[$index]}" == ":::" ]]; then
            break
          fi
          index=$((index + 1))
        done

        printf 'Seq\tHost\tStarttime\tRuntime\tSend\tReceive\tExitval\t'\
'Signal\tCommand\n' > "$joblog"

        seq=1
        index=$((index + 1))
        while [[ $index -lt $# ]]; do
          target="${args[$index]}"
          if validate_one "$target" "$seq"; then
            exitval=0
          else
            exitval=1
          fi
          printf '%s\t:localhost\t0\t0\t0\t0\t%s\t0\tvalidate_one %s '\
'%s\n' \
            "$seq" "$exitval" "$target" "$seq" >> "$joblog"
          seq=$((seq + 1))
          index=$((index + 1))
        done
        """,
    )

    env = os.environ.copy()
    env["PATH"] = f"{bin_dir}:{env['PATH']}"
    env["VALIDATE_SUMMARY_FILE"] = str(summary_path)

    result = subprocess.run(
        ["bash", str(scripts_dir / "salt-validate.sh"), "1", "--", "alpha", "beta"],
        cwd=repo_dir,
        env=env,
        capture_output=True,
        text=True,
    )

    assert result.stdout.strip().endswith("Validated 2 states, 1 failed")
    assert result.returncode == 1
    assert summary_path.exists()

    summary = json.loads(summary_path.read_text())
    assert summary["tool"] == "salt-validate"
    assert summary["total"] == 2
    assert summary["failed"] == 1
    assert summary["results"] == [
        {"state": "alpha", "success": True},
        {"state": "beta", "success": False},
    ]


def test_health_check_script_is_executable():
    script = REPO_ROOT / "scripts" / "health-check.sh"

    assert os.access(script, os.X_OK)


def test_image_provider_bootstrap_script_removed():
    script = REPO_ROOT / "scripts" / "bootstrap-image-providers.sh"
    assert not script.exists()


def test_image_gen_docs_use_manual_gopass_setup():
    source = (REPO_ROOT / "docs" / "image-gen-roster.md").read_text()
    assert "scripts/bootstrap-image-providers.sh" not in source
    assert "gopass insert api/together-ai" in source
    assert "just apply image_generation" in source


def test_proxypilot_recovery_artifacts_exist():
    dockerfile = REPO_ROOT / "containers" / "proxypilot-recovery" / "Dockerfile"
    recovery_doc = REPO_ROOT / "docs" / "proxypilot-recovery.md"
    fallback_doc = REPO_ROOT / "docs" / "proxypilot-free-fallback.md"

    assert dockerfile.is_file()
    assert recovery_doc.is_file()
    assert "podman run" in recovery_doc.read_text()
    assert "scripts/bootstrap-free-providers.sh" not in fallback_doc.read_text()


def test_breakglass_recovery_docs_cover_file_based_age_backup_set():
    breakglass = (REPO_ROOT / "docs" / "gopass-breakglass-recovery.md").read_text()
    setup = (REPO_ROOT / "docs" / "gopass-setup.md").read_text()

    assert "~/.config/gopass/age/identities" in breakglass
    assert "Store the identity backup separately from the password" in breakglass
    assert "gopass show -o <known-key>" in breakglass
    assert "gopass-breakglass-recovery.md" in setup


def test_vpn_split_router_script_exposes_expected_subcommands():
    source = (REPO_ROOT / "scripts" / "vpn_split_router.py").read_text()

    assert 'add_parser("status")' in source
    assert 'add_parser("list")' in source
    assert 'add_parser("recheck")' in source
    assert 'add_parser("forget")' in source
    assert 'add_parser("mark-vpn")' in source
    assert 'add_parser("mark-direct")' in source
    assert 'add_parser("observe")' in source


def test_vpn_split_router_script_compiles():
    script = REPO_ROOT / "scripts" / "vpn_split_router.py"

    result = subprocess.run(
        ["python3", "-m", "py_compile", str(script)], capture_output=True, text=True
    )

    assert result.returncode == 0, result.stderr
