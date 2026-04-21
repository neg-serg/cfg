"""Contract tests for shared shell/bootstrap scripts."""

import os
import subprocess
import stat
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


def test_salt_apply_refreshes_drift_baseline_after_success():
    source = (REPO_ROOT / "scripts" / "salt-apply.sh").read_text()

    assert 'python3 "${PROJECT_DIR}/scripts/drift_state.py" refresh-expected' in source
    assert '"${HOME}/.cache/salt-monitor"' in source


def test_justfile_exposes_drift_commands():
    source = (REPO_ROOT / "Justfile").read_text()

    assert "drift:" in source
    assert 'python3 scripts/drift_state.py fast --project-dir "${PWD}"' in source
    assert "drift-full:" in source
    assert 'python3 scripts/drift_state.py full --project-dir "${PWD}"' in source
    assert "drift-status:" in source
    assert 'python3 scripts/drift_state.py status --project-dir "${PWD}"' in source


def test_health_check_tracks_named_quadlet_units():
    source = (REPO_ROOT / "scripts" / "health-check.sh").read_text()

    assert "jellyfin-container" in source
    assert "transmission-container" in source
    assert "adguardhome-container" in source
    assert "loki-container" in source
    assert "promtail-container" in source
    assert "grafana-container" in source
    assert "bitcoind-container" in source


def test_deploy_guide_uses_cfg_project_dir():
    source = (REPO_ROOT / "scripts" / "deploy-cachyos.sh").read_text()

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


def test_yt_alias_uses_wrapper_based_defaults():
    aliases = yaml.safe_load(
        (REPO_ROOT / "dotfiles" / "dot_config" / "aliae" / "aliae.yaml").read_text()
    )["alias"]
    yt = next(entry for entry in aliases if entry["name"] == "yt")

    assert yt["value"] == (
        'yt-dlp --no-playlist --embed-metadata --embed-thumbnail '
        '--embed-subs --sub-langs=all -o "%(title)s [%(id)s].%(ext)s"'
    )
    assert '--cookies-from-browser firefox:$HOME/.floorp/' not in yt["value"]
    assert '--downloader aria2c' not in yt["value"]


def test_yta_alias_adds_info_json_to_wrapper_based_defaults():
    aliases = yaml.safe_load(
        (REPO_ROOT / "dotfiles" / "dot_config" / "aliae" / "aliae.yaml").read_text()
    )["alias"]
    yta = next(entry for entry in aliases if entry["name"] == "yta")

    assert yta["value"] == (
        'yt-dlp --no-playlist --embed-metadata --embed-thumbnail '
        '--embed-subs --sub-langs=all --write-info-json -o '
        '"%(title)s [%(id)s].%(ext)s"'
    )
    assert '--cookies-from-browser firefox:$HOME/.floorp/' not in yta["value"]
    assert '--downloader aria2c' not in yta["value"]


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
    assert 'SESSION_FILE="${HOME}/.telethon-bridge/telethon.session"' in source
    assert 'systemctl --user is-active --quiet "$UNIT"' in source
    assert 'systemctl --user restart "$UNIT"' in source
    assert 'systemctl --user start "$UNIT"' in source


def test_telethon_bridge_react_script_parses_in_zsh():
    script = REPO_ROOT / "scripts" / "telethon-bridge-react.sh"

    result = subprocess.run(["zsh", "-n", str(script)], capture_output=True, text=True)

    assert result.returncode == 0, result.stderr


def test_pw_restore_links_retries_entire_restore_when_first_pass_hits_transient_link_failures(
    tmp_path,
):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    attempts_file = tmp_path / "pw-link-attempts.txt"
    calls_file = tmp_path / "pw-link-calls.txt"
    attempts_file.write_text("0")

    write_executable(
        bin_dir / "pw-cli",
        f"""
        #!/usr/bin/env zsh
        setopt ERR_EXIT NOUNSET PIPE_FAIL

        if [[ "$1" == "list-objects" && "$2" == "Node" ]]; then
          print 'node.name = "alsa_output.usb-RME_ADI-2_4_Pro_SE__53011083__B992903C2BD8DC8-00.pro-output-0"'
          print 'node.name = "rme-out-1-2"'
          print 'node.name = "rme-out-3-4"'
          print 'node.name = "rme-out-5-6"'
          print 'node.name = "rme-out-7-8"'
          exit 0
        fi

        if [[ "$1" == "info" ]]; then
          print 'node.link-group = "audio-group"'
          exit 0
        fi

        print -u2 "unexpected pw-cli invocation: $*"
        exit 1
        """,
    )

    write_executable(
        bin_dir / "pw-link",
        f"""
        #!/usr/bin/env zsh
        setopt ERR_EXIT NOUNSET PIPE_FAIL

        attempts_file="{attempts_file}"
        calls_file="{calls_file}"

        if [[ "$1" == "-l" ]]; then
          exit 0
        fi

        current=0
        if [[ -f "$attempts_file" ]]; then
          current=$(<"$attempts_file")
        fi
        current=$((current + 1))
        print -r -- "$current" > "$attempts_file"
        print -r -- "$*" >> "$calls_file"

        if (( current <= 2 )); then
          exit 1
        fi

        exit 0
        """,
    )

    write_executable(
        bin_dir / "notify-send",
        """
        #!/usr/bin/env zsh
        exit 0
        """,
    )

    write_executable(
        bin_dir / "sleep",
        """
        #!/usr/bin/env zsh
        exit 0
        """,
    )

    env = os.environ.copy()
    env["PATH"] = f"{bin_dir}:{env['PATH']}"

    result = subprocess.run(
        ["zsh", str(REPO_ROOT / "dotfiles" / "dot_local" / "bin" / "executable_pw-restore-links")],
        cwd=REPO_ROOT,
        env=env,
        capture_output=True,
        text=True,
    )

    assert result.returncode == 0, result.stderr
    assert "All loopback links restored" in result.stdout
    assert len([line for line in calls_file.read_text().splitlines() if line]) >= 3


def test_pw_restore_links_restarts_user_audio_when_expected_sink_topology_is_incomplete(
    tmp_path,
):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    phase_file = tmp_path / "phase.txt"
    phase_file.write_text("before")
    systemctl_calls = tmp_path / "systemctl-calls.txt"

    write_executable(
        bin_dir / "pw-cli",
        f"""
        #!/usr/bin/env zsh
        setopt ERR_EXIT NOUNSET PIPE_FAIL

        phase=$(<"{phase_file}")

        if [[ "$1" == "list-objects" && "$2" == "Node" ]]; then
          print 'node.name = "alsa_output.usb-RME_ADI-2_4_Pro_SE__53011083__B992903C2BD8DC8-00.pro-output-0"'
          if [[ "$phase" == "before" ]]; then
            print 'node.name = "rme-out-1-2"'
            print 'node.name = "rme-out-3-4"'
            print 'node.name = "rme-out-5-6"'
          else
            print 'node.name = "rme-out-1-2"'
            print 'node.name = "rme-out-3-4"'
            print 'node.name = "rme-out-5-6"'
            print 'node.name = "rme-out-7-8"'
          fi
          exit 0
        fi

        if [[ "$1" == "info" ]]; then
          if [[ "$2" == "rme-out-7-8" && "$phase" == "before" ]]; then
            print -u2 'Error: "info: unknown global '\''rme-out-7-8'\''"'
            exit 0
          fi
          print 'node.link-group = "audio-group"'
          exit 0
        fi

        print -u2 "unexpected pw-cli invocation: $*"
        exit 1
        """,
    )

    write_executable(
        bin_dir / "pw-link",
        """
        #!/usr/bin/env zsh
        setopt ERR_EXIT NOUNSET PIPE_FAIL
        if [[ "$1" == "-l" ]]; then
          exit 0
        fi
        exit 0
        """,
    )

    write_executable(
        bin_dir / "systemctl",
        f"""
        #!/usr/bin/env zsh
        setopt ERR_EXIT NOUNSET PIPE_FAIL
        print -r -- "$*" >> "{systemctl_calls}"
        if [[ "$1" == "--user" && "$2" == "restart" ]]; then
          print -r -- restart > "{phase_file}"
          exit 0
        fi
        exit 0
        """,
    )

    write_executable(
        bin_dir / "notify-send",
        """
        #!/usr/bin/env zsh
        exit 0
        """,
    )

    write_executable(
        bin_dir / "sleep",
        """
        #!/usr/bin/env zsh
        exit 0
        """,
    )

    env = os.environ.copy()
    env["PATH"] = f"{bin_dir}:{env['PATH']}"

    result = subprocess.run(
        ["zsh", str(REPO_ROOT / "dotfiles" / "dot_local" / "bin" / "executable_pw-restore-links")],
        cwd=REPO_ROOT,
        env=env,
        capture_output=True,
        text=True,
    )

    assert result.returncode == 0, result.stderr
    assert "All loopback links restored" in result.stdout
    calls = systemctl_calls.read_text().splitlines()
    assert calls == ["--user restart pipewire.service pipewire-pulse.service wireplumber.service"]


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
