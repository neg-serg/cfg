"""Render-contract tests for critical Salt states."""

import os

import pytest
import yaml

from tests import REPO_ROOT_STR

REPO_ROOT = REPO_ROOT_STR


def test_salt_monitor_unit_is_templated_for_runtime_dir():
    state_path = os.path.join(REPO_ROOT, "states", "monitoring_alerts.sls")
    with open(state_path) as fh:
        state_source = fh.read()
    unit_path = os.path.join(REPO_ROOT, "states", "units", "user", "salt-monitor.service")
    with open(unit_path) as fh:
        unit_source = fh.read()

    assert "template='jinja'" in state_source
    assert "runtime_dir': host.runtime_dir" in state_source
    assert "Environment=XDG_RUNTIME_DIR={{ runtime_dir }}" in unit_source


def test_salt_monitor_state_templates_project_dir_for_drift_commands():
    state_path = os.path.join(REPO_ROOT, "states", "monitoring_alerts.sls")
    with open(state_path) as fh:
        state_source = fh.read()
    unit_path = os.path.join(REPO_ROOT, "states", "units", "user", "salt-monitor.service")
    with open(unit_path) as fh:
        unit_source = fh.read()
    script_path = os.path.join(REPO_ROOT, "states", "scripts", "salt-monitor")
    with open(script_path) as fh:
        script_source = fh.read()

    assert "'project_dir': host.project_dir" in state_source
    assert "Environment=PROJECT_DIR={{ project_dir }}" in unit_source
    assert "--drift-fast" in script_source
    assert "--drift-full" in script_source
    assert "--drift-status" in script_source
    assert "--drift-report" in script_source


def test_salt_daemon_unit_is_templated_for_user_runtime_dir():
    state_path = os.path.join(REPO_ROOT, "states", "desktop", "user.sls")
    with open(state_path) as fh:
        state_source = fh.read()
    unit_path = os.path.join(REPO_ROOT, "states", "units", "salt-daemon.service.j2")
    with open(unit_path) as fh:
        unit_source = fh.read()

    assert "runtime_dir': host.runtime_dir" in state_source
    assert "Environment=XDG_RUNTIME_DIR={{ runtime_dir }}" in unit_source
    assert "Environment=DBUS_SESSION_BUS_ADDRESS=unix:path={{ runtime_dir }}/bus" in unit_source


def test_user_services_source_has_no_parallel_feature_lists():
    path = os.path.join(REPO_ROOT, "states", "user_services.sls")
    with open(path) as fh:
        source = fh.read()

    assert "mail_unit_ids" not in source
    assert "vdirsyncer_unit_ids" not in source
    assert "mail_enable" not in source
    assert "vdirsyncer_timers" not in source


def test_video_ai_uses_shared_huggingface_macro():
    root_path = os.path.join(REPO_ROOT, "states", "video_ai.sls")
    with open(root_path) as fh:
        root_source = fh.read()
    models_path = os.path.join(REPO_ROOT, "states", "video_ai", "models.sls")
    with open(models_path) as fh:
        models_source = fh.read()

    assert "- video_ai.models" in root_source
    assert "huggingface_file(" in models_source
    assert "curl -fsSL -C -" not in models_source


def test_transmission_uses_named_quadlet_unit_file():
    path = os.path.join(REPO_ROOT, "states", "transmission.sls")
    with open(path) as fh:
        source = fh.read()

    assert "quadlet_unit_name='transmission-container'" in source


def test_quadlet_unit_names_match_on_disk_files():
    cases = [
        ("duckdns.sls", "duckdns-update-container"),
        ("jellyfin.sls", "jellyfin-container"),
        ("bitcoind.sls", "bitcoind-container"),
        ("adguardhome.sls", "adguardhome-container"),
        ("nanoclaw.sls", "nanoclaw-container"),
        ("proxypilot.sls", "proxypilot-container"),
        ("telethon_bridge.sls", "telethon-bridge"),
        ("opencode_telegram.sls", "opencode-serve"),
        ("opencode_telegram.sls", "opencode-telegram-bot"),
    ]

    for filename, quadlet_name in cases:
        path = os.path.join(REPO_ROOT, "states", filename)
        with open(path) as fh:
            source = fh.read()
        assert f"quadlet_unit_name='{quadlet_name}'" in source


def test_container_service_system_scope_enables_via_cmd_run():
    path = os.path.join(REPO_ROOT, "states", "_macros_service.jinja")
    with open(path) as fh:
        source = fh.read()

    assert (
        "systemctl is-enabled {{ _quadlet_name }}.service >/dev/null 2>&1 || "
        "systemctl enable {{ _quadlet_name }}.service" in source
    )


def test_container_service_daemon_reload_is_required():
    path = os.path.join(REPO_ROOT, "states", "_macros_service.jinja")
    with open(path) as fh:
        source = fh.read()

    assert "- require:" in source
    assert "- file: {{ name }}_container" in source


def test_service_healthcheck_macro_uses_strict_shell_mode():
    path = os.path.join(REPO_ROOT, "states", "_macros_service.jinja")
    with open(path) as fh:
        source = fh.read()

    assert "set -euo pipefail" in source


def test_user_daemon_reload_macros_have_onlyif_guards():
    path = os.path.join(REPO_ROOT, "states", "_macros_service.jinja")
    with open(path) as fh:
        source = fh.read()

    assert "- onlyif: systemctl --user show-environment >/dev/null 2>&1" in source


def test_touched_native_unit_daemon_reload_states_have_onlyif_guards():
    files = [
        "adguardhome.sls",
        "bitcoind.sls",
        "duckdns.sls",
        "jellyfin.sls",
        "llama_embed.sls",
        "nanoclaw.sls",
        "ollama.sls",
        "proxypilot.sls",
        "t5_summarization.sls",
        "transmission.sls",
    ]

    for filename in files:
        path = os.path.join(REPO_ROOT, "states", filename)
        with open(path) as fh:
            source = fh.read()
        assert (
            "- onlyif: test -e /run/systemd/system || test -e /etc/systemd/system" in source
            or "- onlyif: systemctl --user show-environment >/dev/null 2>&1" in source
        )


def test_dns_unbound_restart_has_guard():
    path = os.path.join(REPO_ROOT, "states", "dns.sls")
    with open(path) as fh:
        source = fh.read()

    assert (
        "- onlyif: command -v unbound-control >/dev/null 2>&1 || "
        "systemctl cat unbound >/dev/null 2>&1" in source
    )


def test_versioned_paru_install_uses_strict_shell_mode():
    path = os.path.join(REPO_ROOT, "states", "_macros_pkg.jinja")
    with open(path) as fh:
        source = fh.read()

    assert "sudo -u {{ _user }} paru -S --noconfirm --needed {{ pkg }}" in source
    assert "set -euo pipefail" in source


def test_paru_install_supports_all_packages_guard_for_category_installs():
    path = os.path.join(REPO_ROOT, "states", "_macros_pkg.jinja")
    with open(path) as fh:
        source = fh.read()

    assert "check == '__ALL__'" in source
    assert "for _pkg in {{ pkg.split() | tojson }}; do" not in source
    assert "for pkg_name in pkg.split()" in source
    assert "grep -qxF '{{ pkg_name }}' {{ host.pkg_list }} || exit 1" in source


def test_paru_install_defaults_multi_package_checks_to_all_packages():
    path = os.path.join(REPO_ROOT, "states", "_macros_pkg.jinja")
    with open(path) as fh:
        source = fh.read()

    assert "_check_all = check == '__ALL__' or (check is none and ' ' in pkg)" in source
    assert "elif _check_all" in source


def test_container_service_daemon_reload_only_runs_on_quadlet_changes():
    path = os.path.join(REPO_ROOT, "states", "_macros_service.jinja")
    with open(path) as fh:
        source = fh.read()

    marker = (
        "# container_service({{ name }}): daemon-reload so Quadlet regenerates the systemd unit"
    )
    block = source[
        source.index(marker) : source.index("{%- if not _manual_start %}", source.index(marker))
    ]

    assert "{{ name }}_daemon_reload:" in block
    assert "- onchanges:" in block
    assert "- file: {{ name }}_container" in block
    assert "- require:" not in block


def test_win11_vm_definition_is_not_staged_via_tmp_file():
    path = os.path.join(REPO_ROOT, "states", "desktop", "vm_win11.sls")
    with open(path) as fh:
        source = fh.read()

    assert "/tmp/win11.xml" not in source
    assert "virsh -c qemu:///system define" in source


def test_managed_service_paths_ensure_is_stateful_noop_when_guards_match():
    path = os.path.join(REPO_ROOT, "states", "systemd_resources.sls")
    with open(path) as fh:
        source = fh.read()

    marker = "managed_service_paths_ensure:"
    block = source[source.index(marker) :]

    assert "stateful: True" in block
    assert 'echo "changed=no' in block
    assert "systemd-tmpfiles --create /etc/tmpfiles.d/salt-managed-service-paths.conf" in block


def test_npm_build_workflow_version_pin_uses_strict_shell_mode():
    path = os.path.join(REPO_ROOT, "states", "_macros_install.jinja")
    with open(path) as fh:
        source = fh.read()

    assert "git fetch --tags --depth=1" in source
    assert "set -euo pipefail" in source


def test_ollama_tmp_start_uses_strict_shell_mode():
    path = os.path.join(REPO_ROOT, "states", "ollama.sls")
    with open(path) as fh:
        source = fh.read()

    assert "set -euo pipefail" in source


def test_t5_convert_uses_strict_shell_mode():
    path = os.path.join(REPO_ROOT, "states", "t5_summarization.sls")
    with open(path) as fh:
        source = fh.read()

    assert "set -euo pipefail" in source


def test_user_and_system_quadlets_use_environment_not_env_keys():
    paths = [
        os.path.join(REPO_ROOT, "states", "units", "transmission-container.container"),
        os.path.join(REPO_ROOT, "states", "units", "user", "nanoclaw-container.container"),
    ]

    for path in paths:
        with open(path) as fh:
            source = fh.read()
        assert "Environment=" in source
        assert "\nEnv=" not in source


def test_localhost_quadlets_disable_pull_attempts():
    paths = [
        os.path.join(REPO_ROOT, "states", "units", "user", "proxypilot-container.container"),
        os.path.join(REPO_ROOT, "states", "units", "user", "nanoclaw-container.container"),
    ]

    for path in paths:
        with open(path) as fh:
            source = fh.read()
        assert "Pull=never" in source


def test_transmission_quadlet_does_not_override_webui_path():
    path = os.path.join(REPO_ROOT, "states", "units", "transmission-container.container")
    with open(path) as fh:
        source = fh.read()

    assert "TRANSMISSION_WEB_HOME" not in source


def test_proxypilot_dockerfile_copies_packaged_binary_from_repo_root():
    path = os.path.join(REPO_ROOT, "build", "proxypilot", "Dockerfile")
    with open(path) as fh:
        source = fh.read()

    assert (
        "COPY build/pkgbuilds/proxypilot/pkg/proxypilot/usr/bin/proxypilot /usr/bin/proxypilot"
        in source
    )


def test_proxypilot_quadlet_uses_mounted_config_without_overriding_sdnotify():
    path = os.path.join(REPO_ROOT, "states", "units", "user", "proxypilot-container.container")
    with open(path) as fh:
        source = fh.read()

    assert "Exec=-config /config/config.yaml" in source
    assert "Environment=HOME=/root" in source
    assert "HealthCmd=" not in source
    assert "\nNotify=" not in source
    assert "--sdnotify=" not in source


def test_nanoclaw_dockerfile_skips_husky_prepare_in_container_build():
    path = os.path.join(REPO_ROOT, "build", "nanoclaw", "Dockerfile")
    with open(path) as fh:
        source = fh.read()

    assert "FROM node:22-bookworm-slim" in source
    assert "npm pkg delete scripts.prepare" in source
    assert "npm ci --production" in source
    assert "apt-get install -y --no-install-recommends docker.io" in source
    assert "USER node" not in source


def test_proxypilot_uses_user_scope_systemd_health_command():
    path = os.path.join(REPO_ROOT, "states", "data", "service_catalog.yaml")
    with open(path) as fh:
        source = fh.read()

    assert 'health_cmd: "systemctl --user is-active --quiet proxypilot-container.service"' in source


def test_nanoclaw_is_manual_start_until_channels_are_configured():
    path = os.path.join(REPO_ROOT, "states", "data", "service_catalog.yaml")
    with open(path) as fh:
        source = fh.read()

    assert "nanoclaw:" in source
    assert "manual_start: true" in source


def test_nanoclaw_quadlet_mounts_podman_socket_as_docker_sock():
    catalog_path = os.path.join(REPO_ROOT, "states", "data", "service_catalog.yaml")
    with open(catalog_path) as fh:
        catalog_source = fh.read()

    assert "nanoclaw:" in catalog_source
    assert "- host: ~/.local/share/nanoclaw" in catalog_source
    assert "container: /app" in catalog_source
    assert "- host: ~/.config/nanoclaw" in catalog_source
    assert "container: /config" in catalog_source
    assert "- host: ~/.local/share/nanoclaw/entrypoint.sh" in catalog_source
    assert "container: /app/entrypoint.sh" in catalog_source
    assert "- host: ~/.local/share/nanoclaw/container-runtime-patched.ts" in catalog_source
    assert "container: /app/src/container-runtime.ts" in catalog_source
    assert "- host: ~/.local/share/nanoclaw/index-main-patched.ts" in catalog_source
    assert "container: /app/src/index.ts" in catalog_source

    unit_path = os.path.join(REPO_ROOT, "states", "units", "user", "nanoclaw-container.container")
    with open(unit_path) as fh:
        unit_source = fh.read()

    assert "{% for m in expanded_mounts -%}" in unit_source
    assert "Volume={{ m.host }}:{{ m.container }}:{{ m.mode }}" in unit_source
    assert "Volume=/run/user/1000/podman/podman.sock:/var/run/docker.sock:rw" in unit_source
    assert "Volume=/home/neg/.local/share/nanoclaw/store:/app/store:rw" not in unit_source
    assert "Volume=/home/neg/.local/share/nanoclaw/data:/app/data:rw" not in unit_source
    assert "Volume=/home/neg/.local/share/nanoclaw/groups:/app/groups:rw" not in unit_source
    assert "Volume=/home/neg/.local/share/nanoclaw/.env:/app/.env:rw" not in unit_source


def test_video_ai_registry_uses_public_gemma_tokenizer_repo():
    path = os.path.join(REPO_ROOT, "states", "data", "video_ai.yaml")
    with open(path) as fh:
        source = fh.read()

    assert "repo: unsloth/gemma-3-12b-it" in source
    assert "file: tokenizer.model" in source


def test_service_healthcheck_macro_supports_user_scope_systemctl():
    path = os.path.join(REPO_ROOT, "states", "_macros_service.jinja")
    with open(path) as fh:
        source = fh.read()

    assert (
        "macro service_with_healthcheck(name, service, check_cmd=None, "
        "timeout=_healthcheck_timeout, requires=None, catalog=None, "
        "user_scope=False, user=_user)" in source
    )
    assert (
        "systemctl {% if user_scope %}--user {% endif %}is-active --quiet {{ service }}" in source
    )


def test_nanoclaw_container_image_note_matches_agent_image_name():
    path = os.path.join(REPO_ROOT, "states", "data", "container_images.yaml")
    with open(path) as fh:
        source = fh.read()

    assert "image: nanoclaw-agent" in source
    assert "podman build -f build/nanoclaw/Dockerfile -t localhost/nanoclaw-agent" in source


def test_video_ai_registry_uses_current_model_filenames():
    path = os.path.join(REPO_ROOT, "states", "data", "video_ai.yaml")
    with open(path) as fh:
        source = fh.read()

    assert "repo: unsloth/gemma-3-12b-it" in source
    assert "file: tokenizer.model" in source
    assert "LTX23_video_vae_bf16.safetensors" in source


def test_container_service_healthcheck_requires_service_state_for_system_scope():
    path = os.path.join(REPO_ROOT, "states", "_macros_service.jinja")
    with open(path) as fh:
        source = fh.read()

    assert "requires=['service: ' ~ name ~ '_running']" in source


def test_transmission_state_disables_native_service_before_container_cutover():
    path = os.path.join(REPO_ROOT, "states", "transmission.sls")
    with open(path) as fh:
        source = fh.read()

    assert "service_stopped('transmission_native_service_disabled', 'transmission'" in source


def test_nanoclaw_uses_existing_localhost_agent_image_name():
    path = os.path.join(REPO_ROOT, "states", "data", "container_images.yaml")
    with open(path) as fh:
        source = fh.read()

    assert "image: nanoclaw-agent" in source


def test_udev_rule_macro_has_guard():
    path = os.path.join(REPO_ROOT, "states", "_macros_service.jinja")
    with open(path) as fh:
        source = fh.read()

    assert "- onlyif: command -v udevadm >/dev/null 2>&1" in source


def test_next_guard_batch_has_onlyif_guards():
    cases = {
        "zapret2.sls": "- onlyif: test -x /opt/zapret2/ipset/get_config.sh",
        "systemd_resources.sls": "- onlyif: command -v systemd-sysusers >/dev/null 2>&1",
        "sysctl.sls": "- onlyif: command -v sysctl >/dev/null 2>&1",
        "mkinitcpio.sls": "- onlyif: command -v mkinitcpio >/dev/null 2>&1",
        "kanata.sls": (
            "- onlyif: id -u {{ user }} >/dev/null 2>&1 && command -v usermod "
            ">/dev/null 2>&1 && id -nG {{ user }} | grep -qw input && ! "
            "id -nG {{ user }} | grep -qw uinput"
        ),
    }

    for filename, needle in cases.items():
        path = os.path.join(REPO_ROOT, "states", filename)
        with open(path) as fh:
            source = fh.read()
        assert needle in source


def test_service_with_unit_daemon_reload_has_guard():
    path = os.path.join(REPO_ROOT, "states", "_macros_service.jinja")
    with open(path) as fh:
        source = fh.read()

    assert "{{ name }}_daemon_reload:" in source
    assert "- onlyif: test -e /run/systemd/system || test -e /etc/systemd/system" in source


def test_pip_pkg_macro_uses_strict_shell_mode():
    path = os.path.join(REPO_ROOT, "states", "_macros_install.jinja")
    with open(path) as fh:
        source = fh.read()

    assert "pipx install" in source
    assert "set -euo pipefail" in source


def test_amnezia_cmdrun_states_have_guards():
    path = os.path.join(REPO_ROOT, "states", "amnezia.sls")
    with open(path) as fh:
        source = fh.read()

    assert (
        "- onlyif: test -x {{ cache }}/amneziawg-go-bin && test -x {{ cache }}/awg-bin "
        "&& test -x {{ cache }}/AmneziaVPN-bin && test -x {{ cache }}/AmneziaVPN-service-bin"
        in source
    )
    assert (
        "('amneziawg_go', '/usr/local/bin/amneziawg-go --version', "
        "'amneziawg_go_bin', '/usr/local/bin/amneziawg-go')" in source
    )
    assert (
        "('awg', '/usr/local/bin/awg --version', 'amneziawg_tools_bin', '/usr/local/bin/awg')"
        in source
    )
    assert (
        "('amnezia_vpn', 'ldd /usr/local/bin/AmneziaVPN', "
        "'amnezia_vpn_bin', '/usr/local/bin/AmneziaVPN')" in source
    )
    assert (
        "('amnezia_service', 'ldd /usr/local/bin/AmneziaVPN-service', "
        "'amnezia_service_bin', '/usr/local/bin/AmneziaVPN-service')" in source
    )
    assert "- onlyif: test -x {{ binary_path }}" in source


def test_sing_box_tun_uses_imported_runtime_config_and_split_routing():
    state_path = os.path.join(REPO_ROOT, "states", "network.sls")
    with open(state_path) as fh:
        state_source = fh.read()
    services_path = os.path.join(REPO_ROOT, "states", "services.sls")
    with open(services_path) as fh:
        services_source = fh.read()
    services_data_path = os.path.join(REPO_ROOT, "states", "data", "services.yaml")
    with open(services_data_path) as fh:
        services_data_source = fh.read()
    unit_path = os.path.join(REPO_ROOT, "states", "units", "sing-box-tun.service")
    with open(unit_path) as fh:
        unit_source = fh.read()

    assert "net.vpn_split_router" in state_source
    assert "/usr/local/bin/amnezia-import-tun-config" in state_source
    assert "vpn_split_router: vpn_split_router" in services_data_source
    assert "known_vars[v]" in services_source
    assert "{{ home }}/.config/sing-box-tun/config.json" in unit_source
    assert "{% if vpn_split_router %}" in unit_source
    assert "/run/user/{{ uid }}/secrets/vless-reality-singbox-tun.json" in unit_source
    assert "ExecStart=/usr/bin/sing-box run -c" in unit_source


def test_amnezia_import_runtime_artifacts_are_deployed_as_user_space_files():
    state_path = os.path.join(REPO_ROOT, "states", "network.sls")
    with open(state_path) as fh:
        state_source = fh.read()

    assert "scripts/amnezia-import-tun-config.sh" in state_source
    assert "/usr/local/bin/amnezia-import-tun-config" in state_source
    assert "{{ home }}/.local/bin/amnezia-import-tun-config" in state_source
    assert "target: /usr/local/bin/amnezia-import-tun-config" in state_source
    assert "~/.config/AmneziaVPN.ORG/AmneziaVPN.conf" not in state_source


def test_amnezia_import_user_units_are_deployed_but_not_auto_enabled():
    state_path = os.path.join(REPO_ROOT, "states", "network.sls")
    with open(state_path) as fh:
        state_source = fh.read()

    service_path = os.path.join(REPO_ROOT, "states", "units", "user", "amnezia-import-tun.service")
    with open(service_path) as fh:
        service_source = fh.read()

    assert (
        "user_service_file('amnezia_import_tun_user_service', 'amnezia-import-tun.service'"
        in state_source
    )
    assert "amnezia-import-tun.path" not in state_source

    assert "Type=oneshot" in service_source
    assert "ExecStart=%h/.local/bin/amnezia-import-tun-config import" in service_source


def test_vpn_split_router_state_deploys_helper_config_and_units():
    path = os.path.join(REPO_ROOT, "states", "network.sls")
    with open(path) as fh:
        source = fh.read()

    assert "vpn_split_router_script:" in source
    assert "vpn_split_router.py" in source
    assert "vpn_split_router_config:" in source
    assert "configs/vpn-split-router.yaml.j2" in source
    assert "user_service_file('vpn_split_router_service', 'vpn-split-router.service'" in source
    assert "user_service_file('vpn_split_router_timer', 'vpn-split-router.timer'" in source
    assert "user_service_enable('vpn_split_router_enabled'" in source
    assert "cmd: vpn_split_router_service_daemon_reload" in source
    assert "cmd: vpn_split_router_timer_daemon_reload" in source


def test_vpn_split_router_units_use_user_scope_and_timer_schedule():
    service_path = os.path.join(REPO_ROOT, "states", "units", "user", "vpn-split-router.service")
    timer_path = os.path.join(REPO_ROOT, "states", "units", "user", "vpn-split-router.timer")

    with open(service_path) as fh:
        service_source = fh.read()
    with open(timer_path) as fh:
        timer_source = fh.read()

    assert "Type=oneshot" in service_source
    assert "ExecStart=%h/.local/bin/vpn-split-router recheck" in service_source
    assert "OnBootSec=2m" in timer_source
    assert "OnUnitActiveSec=15m" in timer_source
    assert "WantedBy=timers.target" in timer_source


def test_vpn_split_router_state_deploys_sing_box_react_units():
    path = os.path.join(REPO_ROOT, "states", "network.sls")
    with open(path) as fh:
        source = fh.read()

    assert "sing_box_tun_react_service_unit:" in source
    assert "sing-box-tun-react.service" in source
    assert "sing_box_tun_react_path_unit:" in source
    assert "sing-box-tun-react.path" in source
    assert "sing_box_tun_react_path_running:" in source


def test_sing_box_tun_react_units_watch_runtime_config_and_restart_service():
    service_path = os.path.join(REPO_ROOT, "states", "units", "sing-box-tun-react.service")
    path_path = os.path.join(REPO_ROOT, "states", "units", "sing-box-tun-react.path")
    with open(service_path) as fh:
        service_source = fh.read()
    with open(path_path) as fh:
        path_source = fh.read()

    assert (
        "systemctl is-active sing-box-tun.service --quiet && "
        "systemctl restart sing-box-tun.service || true" in service_source
    )
    assert "PathChanged={{ home }}/.config/sing-box-tun/config.json" in path_source
    assert "Unit=sing-box-tun-react.service" in path_source


def test_vpn_split_router_config_template_preserves_empty_seed_domain_list():
    path = os.path.join(REPO_ROOT, "states", "configs", "vpn-split-router.yaml.j2")
    with open(path) as fh:
        source = fh.read()

    assert "seed_domains: []" in source
    assert "{% if router.seed_domains %}" in source


def test_telethon_bridge_state_deploys_reactivity_units_and_helper():
    path = os.path.join(REPO_ROOT, "states", "telethon_bridge.sls")
    with open(path) as fh:
        source = fh.read()

    assert "telethon_bridge_react_helper:" in source
    assert "telethon_bridge_react_path" in source
    assert "telethon_bridge_react_service" in source


def test_telethon_bridge_react_path_watches_exact_runtime_files():
    path = os.path.join(REPO_ROOT, "states", "units", "user", "telethon-bridge-react.path")
    with open(path) as fh:
        source = fh.read()

    assert "PathChanged=%h/.telethon-bridge/config.yaml" in source
    assert "PathChanged=%h/.local/bin/telethon-bridge" in source
    assert "%h/.telethon-bridge/telethon.session" not in source
    assert "%h/.telethon-bridge/" not in source.replace("%h/.telethon-bridge/config.yaml", "")


def test_telethon_bridge_react_service_runs_helper_script():
    path = os.path.join(REPO_ROOT, "states", "units", "user", "telethon-bridge-react.service")
    with open(path) as fh:
        source = fh.read()

    assert "Type=oneshot" in source
    assert "ExecStart=%h/.local/bin/telethon-bridge-react" in source


def test_remaining_multiline_cmdrun_states_use_strict_shell_mode():
    cases = [
        ("hardware.sls", "set -euo pipefail"),
        ("hiddify.sls", "set -euo pipefail"),
        ("network.sls", "set -euo pipefail"),
        ("xen.sls", "set -euo pipefail"),
    ]

    for filename, needle in cases:
        path = os.path.join(REPO_ROOT, "states", filename)
        with open(path) as fh:
            source = fh.read()
        assert needle in source


def test_system_description_includes_shared_systemd_resources_state():
    path = os.path.join(REPO_ROOT, "states", "system_description.sls")
    with open(path) as fh:
        source = fh.read()

    assert "- systemd_resources" in source


def test_system_description_includes_os_release_state():
    path = os.path.join(REPO_ROOT, "states", "system_description.sls")
    with open(path) as fh:
        source = fh.read()

    assert "system_os_release" in source


def test_hyprlock_uses_fancy_name_fallback_for_os_release():
    paths = [
        os.path.join(REPO_ROOT, "dotfiles", "dot_config", "hypr", "hyprlock", "greetd.conf"),
        os.path.join(
            REPO_ROOT,
            "dotfiles",
            "dot_config",
            "hypr",
            "hyprlock",
            "greetd-wallbash.conf",
        ),
    ]

    for path in paths:
        with open(path) as fh:
            source = fh.read()

        assert ". /etc/os-release" in source
        assert "FANCY_NAME:-${PRETTY_NAME:-$NAME}" in source


def test_managed_resources_inventory_covers_phase1_services():
    path = os.path.join(REPO_ROOT, "states", "data", "managed_resources.yaml")
    with open(path) as fh:
        data = yaml.safe_load(fh)

    identities = data["managed_service_identities"]
    paths = data["managed_service_paths"]

    assert {"loki", "greetd"} <= set(identities)
    assert {
        "loki_root",
        "greetd_root",
        "mpd_fifo",
    } <= set(paths)
    assert paths["mpd_fifo"]["user"] == "__CURRENT_USER__"


@pytest.mark.skip(reason="States dns, services, mpd don't use shared resources; need refactor")
def test_service_states_use_shared_managed_resource_ensures():
    state_paths = [
        os.path.join(REPO_ROOT, "states", "monitoring_loki.sls"),
        os.path.join(REPO_ROOT, "states", "dns.sls"),
        os.path.join(REPO_ROOT, "states", "services.sls"),
        os.path.join(REPO_ROOT, "states", "mpd.sls"),
    ]

    combined = []
    for path in state_paths:
        with open(path) as fh:
            combined.append(fh.read())
    source = "\n".join(combined)

    assert "cmd: managed_service_accounts_ensure" in source
    assert "cmd: managed_service_paths_ensure" in source
    assert "system_daemon_user(" not in source
    assert "/etc/tmpfiles.d/mpd-fifo.conf" not in source


def test_greetd_state_depends_on_shared_managed_resources():
    path = os.path.join(REPO_ROOT, "states", "greetd.sls")
    with open(path) as fh:
        source = fh.read()

    assert "- systemd_resources" in source
    assert "cmd: managed_service_accounts_ensure" in source
    assert "cmd: managed_service_paths_ensure" in source


def test_quickshell_services_qmldir_registers_widget_registry():
    path = os.path.join(REPO_ROOT, "dotfiles", "dot_config", "quickshell", "Services", "qmldir")
    with open(path) as fh:
        source = fh.read()

    assert "singleton WidgetRegistry 1.0 WidgetRegistry.qml" in source


def test_systemd_resource_templates_reference_shared_macros():
    accounts_path = os.path.join(REPO_ROOT, "states", "configs", "managed-service-accounts.conf.j2")
    with open(accounts_path) as fh:
        accounts_source = fh.read()

    paths_path = os.path.join(REPO_ROOT, "states", "configs", "managed-service-paths.conf.j2")
    with open(paths_path) as fh:
        paths_source = fh.read()

    assert "managed_sysusers_line" in accounts_source
    assert "managed_tmpfiles_line" in paths_source


def test_opencode_config_uses_template_source_without_removed_local_paths():
    template_path = os.path.join(
        REPO_ROOT, "dotfiles", "dot_config", "opencode", "opencode.json.tmpl"
    )
    managed_paths = {
        os.path.join(REPO_ROOT, "dotfiles", "dot_config", "opencode", "opencode.json.tmpl"),
        os.path.join(REPO_ROOT, "dotfiles", "dot_config", "opencode", "tui.json"),
    }

    assert os.path.exists(template_path)
    assert (
        os.path.join(REPO_ROOT, "dotfiles", "dot_config", "opencode", "opencode.json")
        not in managed_paths
    )

    with open(template_path) as fh:
        template_source = fh.read()

    assert "http://192.168.2.166:8317/v1" in template_source
    assert "/home/me/MyProjects/opencode-tg/skills" not in template_source
    assert "YTDLP_COOKIES_FILE" not in template_source


def test_opencode_config_keeps_expected_plugins():
    template_path = os.path.join(
        REPO_ROOT, "dotfiles", "dot_config", "opencode", "opencode.json.tmpl"
    )

    with open(template_path) as fh:
        template_source = fh.read()

    assert '"opencode-gemini-auth@latest"' in template_source
    assert '"superpowers@git+https://github.com/obra/superpowers.git"' in template_source


def test_opencode_repo_manages_minimal_runtime_files():
    managed_paths = [
        os.path.join(REPO_ROOT, "dotfiles", "dot_config", "opencode", "opencode.json.tmpl"),
        os.path.join(REPO_ROOT, "dotfiles", "dot_config", "opencode", "tui.json"),
        os.path.join(REPO_ROOT, "dotfiles", "dot_config", "opencode", "themes", "neg.json"),
        os.path.join(REPO_ROOT, "dotfiles", "dot_config", "opencode", "themes", "neg-light.json"),
    ]
    legacy_runtime_path = os.path.join(
        REPO_ROOT, "dotfiles", "dot_config", "opencode", "opencode.json"
    )

    for path in managed_paths:
        assert os.path.exists(path)

    assert legacy_runtime_path not in managed_paths
    assert not os.path.isfile(legacy_runtime_path)


def test_desktop_system_persists_balanced_cpu_epp_policy():
    state_path = os.path.join(REPO_ROOT, "states", "desktop", "system.sls")
    with open(state_path) as fh:
        state_source = fh.read()

    unit_path = os.path.join(REPO_ROOT, "states", "units", "cpu-balanced-epp.service")
    with open(unit_path) as fh:
        unit_source = fh.read()

    script_path = os.path.join(REPO_ROOT, "states", "scripts", "cpu-balanced-epp.sh")
    with open(script_path) as fh:
        script_source = fh.read()

    assert "cpu_balanced_epp_script:" in state_source
    assert "service_with_unit('cpu-balanced-epp'" in state_source
    assert "energy_performance_preference" in script_source
    assert "balance_performance" in script_source
    assert "Type=oneshot" in unit_source
