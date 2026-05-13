"""Salt execution module: shared host config and constants.

Provides get_host() and get_constants() — replaces _macros_common.jinja
variable declarations.  Loads hosts.yaml, resolves derived paths, and
returns a dict that templates can access via salt['common.get_host']()
or via Jinja globals injected by data_loader.

Salt runtime context: importable from Salt with __salt__, __opts__, etc.
Offline context: importable by lint-jinja.py mock and pytest directly.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:
    yaml = None  # type: ignore[assignment]

# ── Path resolution (works both inside Salt and standalone) ──────────
def _find_states_dir() -> Path:
    """Resolve states/ directory relative to this module file."""
    return Path(__file__).resolve().parent.parent


STATES_DIR = _find_states_dir()
HOSTS_YAML = STATES_DIR / "data" / "hosts.yaml"
FEATURE_REGISTRY_YAML = STATES_DIR / "data" / "feature_registry.yaml"




def _load_yaml(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    if yaml is None:
        return {}
    try:
        data = yaml.safe_load(path.read_text())
        return data if isinstance(data, dict) else {}
    except (yaml.YAMLError, OSError):
        return {}


# ── Data-driven defaults from system.yaml ─────────────────────────
_SYSTEM = _load_yaml(STATES_DIR / "data" / "system.yaml")
_TIMEOUTS = _SYSTEM.get("timeouts", {})
RETRY_ATTEMPTS = _TIMEOUTS.get("retry_attempts", 3)
RETRY_INTERVAL = _TIMEOUTS.get("retry_interval", 10)
HEALTHCHECK_TIMEOUT = _TIMEOUTS.get("healthcheck_timeout", 30)
OLLAMA_PULL_TIMEOUT = _TIMEOUTS.get("ollama_pull_timeout", 14400)


def _build_host(hosts_data: dict[str, Any] | None = None) -> dict[str, Any]:
    """Build a fully-resolved host config from hosts.yaml."""
    if hosts_data is None:
        hosts_data = _load_yaml(HOSTS_YAML)

    defaults = hosts_data.get("defaults", {})
    if not isinstance(defaults, dict):
        defaults = {}

    host = dict(defaults)

    # Resolve derived fields (matching host_model.py _add_derived_fields)
    user = host.get("user", os.environ.get("USER", "root"))
    home = host.get("home", f"/home/{user}")
    uid = host.get("uid", 1000)

    host.setdefault("user", user)
    host.setdefault("home", home)
    host.setdefault("uid", uid)
    host["runtime_dir"] = f"/run/user/{host['uid']}"
    host["pkg_list"] = "/var/cache/salt/pacman_installed.txt"
    host["ver_dir"] = f"{home}/.cache/salt-versions"
    host["sys_ver_dir"] = "/var/cache/salt/versions"
    host["download_cache"] = "/var/cache/salt/downloads"
    host["gopass_dir"] = f"{home}/.local/share/pass"
    host["gnupg_dir"] = f"{home}/.local/share/gnupg"
    host["systemd_unit_dir"] = "/etc/systemd/system/"
    host["systemd_user_unit_dir"] = f"{home}/.config/systemd/user/"
    host["quadlet_system_dir"] = "/etc/containers/systemd/"
    host["quadlet_user_dir"] = f"{home}/.config/containers/systemd/"
    host["nftables_dir"] = "/etc/nftables/"
    host["sysctl_dir"] = "/etc/sysctl.d/"
    host["logrotate_dir"] = "/etc/logrotate.d/"
    host["stamp_dir"] = "/var/cache/salt/"
    host["mkinitcpio_dir"] = "/etc/mkinitcpio.d/"

    return host


def get_host() -> dict[str, Any]:
    """Return resolved host configuration dict.

    Fields: user, home, uid, features, runtime_dir, pkg_list,
    cpu_vendor, display, hostname, and all other hosts.yaml defaults.
    """
    return _build_host()


def get_constants() -> dict[str, Any]:
    """Return shared constants matching _macros_common.jinja."""
    host = get_host()
    home = host.get("home", "/root")
    return {
        "retry_attempts": RETRY_ATTEMPTS,
        "retry_interval": RETRY_INTERVAL,
        "healthcheck_timeout": HEALTHCHECK_TIMEOUT,
        "ollama_pull_timeout": OLLAMA_PULL_TIMEOUT,
        "ver_dir": f"{home}/.cache/salt-versions",
        "sys_ver_dir": "/var/cache/salt/versions",
        "download_cache": "/var/cache/salt/downloads",
    }


def ver_dir(user_home: str | None = None) -> str:
    hm = user_home or get_host().get("home", "/root")
    return f"{hm}/.cache/salt-versions"


def sys_ver_dir() -> str:
    return "/var/cache/salt/versions"


def download_cache() -> str:
    return "/var/cache/salt/downloads"


def get_registry() -> dict[str, Any]:
    """Load feature_registry.yaml."""
    return _load_yaml(FEATURE_REGISTRY_YAML)


# Make module callable as salt['common.get_host']() etc.
__func_alias__ = {
    "get_host": "get_host",
    "get_constants": "get_constants",
}
