"""Salt execution module: YAML data pre-loader and Jinja globals injector.

Replaces inline {% import_yaml 'data/X.yaml' as X %} calls in .sls files.
On Salt startup (or render-time), loads all states/data/*.yaml files and
injects them into the Jinja template namespace.  Templates then access data
files as bare variables (e.g. {{ catalog.ollama.container_image }}) without
any import statement.

Also injects HostConfig from common.py, replacing _macros_common.jinja
variable declarations.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:
    yaml = None  # type: ignore[assignment]


def _get_data_dir() -> Path:
    return Path(__file__).resolve().parent.parent / "data"


def load_data_file(filename: str) -> dict[str, Any]:
    """Load a single states/data/*.yaml file by basename."""
    path = _get_data_dir() / filename
    if not path.is_file():
        return {}
    if yaml is None:
        return {}
    try:
        data = yaml.safe_load(path.read_text())
        return data if isinstance(data, dict) else {"_data": data}
    except (yaml.YAMLError, OSError):
        return {}


def load_all() -> dict[str, dict[str, Any]]:
    """Load all states/data/*.yaml files into a dict keyed by basename without .yaml.

    Returns: {'hosts': {...}, 'desktop': {...}, 'packages': {...}, ...}
    """
    data_dir = _get_data_dir()
    result: dict[str, dict[str, Any]] = {}

    if not data_dir.is_dir():
        return result

    for path in sorted(data_dir.glob("*.yaml")):
        name = path.stem
        data = load_data_file(path.name)
        if data:
            result[name] = data

    return result


def inject_globals(env) -> dict[str, Any]:
    """Inject all data files + HostConfig into a Jinja Environment globals.

    Call this from a Salt loader or custom Jinja extension to populate
    the template namespace before rendering.

    Args:
        env: Jinja Environment object (has .globals dict)

    Returns:
        dict of injected variable names → values
    """
    from .common import get_host as _get_host

    injected: dict[str, Any] = {}

    # Host config (replaces _macros_common.jinja imports)
    host = _get_host()
    injected["host"] = host
    injected["user"] = host.get("user", "root")
    injected["home"] = host.get("home", "/root")
    injected["pkg_list"] = host.get("pkg_list", "")

    # Constants
    from .common import get_constants as _get_constants
    constants = _get_constants()
    for key, value in constants.items():
        injected[key] = value

    # All data YAML files
    all_data = load_all()
    for name, data in all_data.items():
        injected[name] = data

    # Push into Jinja globals
    if hasattr(env, "globals") and isinstance(env.globals, dict):
        env.globals.update(injected)

    return injected


__func_alias__ = {
    "load_all": "load_all",
    "inject_globals": "inject_globals",
}
