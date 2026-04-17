"""Contract tests for shared shell/bootstrap scripts."""

import os
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


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
