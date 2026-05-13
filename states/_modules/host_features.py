"""Salt execution module: feature flag resolution.

Replaces _macros_registry.jinja feature_enabled() / feature_default() macros.
Callable from Jinja as salt['host.feature_enabled']('mpd') or
salt['host.feature_default']('mpd').

Lint/offline: reads feature_registry.yaml directly.
Salt runtime: uses common.get_host() for feature state.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any


def _load_registry() -> dict[str, Any]:
    path = Path(__file__).resolve().parent.parent / "data" / "feature_registry.yaml"
    if not path.is_file():
        return {}
    try:
        import yaml
        data = yaml.safe_load(path.read_text())
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def _traverse(obj: Any, parts: list[str]) -> Any:
    """Deep-traverse dict by dotted path, returning intermediate dicts too."""
    current = obj
    for part in parts:
        if isinstance(current, dict) and part in current:
            current = current[part]
        else:
            return None
    return current


def feature_enabled(name: str, host: dict[str, Any] | None = None) -> bool:
    """Return True if feature 'name' is enabled in host.features.

    Args:
        name: Dotted feature path (e.g. 'monitoring.loki', 'mpd')
        host: Host config dict (from common.get_host()). If None, uses
              common.get_host() to auto-resolve.

    Returns:
        True if feature resolves to a boolean True at the host level.
    """
    if host is None:
        try:
            from .common import get_host
            host = get_host()
        except Exception:
            return False

    features = host.get("features", {})
    if not isinstance(features, dict):
        return False

    parts = name.split(".")
    val = _traverse(features, parts)
    return val is True


def feature_default(name: str) -> bool | None:
    """Return the default value for feature 'name' from feature_registry.yaml.

    The registry may have nested groups with a 'features' sub-dict that
    contains more features.  E.g. 'monitoring.loki' traverses:
    registry.features.monitoring.features.loki.default

    Returns None if the feature is not found in the registry.
    """
    registry = _load_registry()
    reg_features = registry.get("features", {})
    if not isinstance(reg_features, dict):
        return None

    parts = name.split(".")
    current: Any = reg_features

    for i, part in enumerate(parts):
        if isinstance(current, dict) and part in current:
            current = current[part]
            # If this entry has a nested 'features' sub-dict and we have
            # more parts to traverse, step into it.
            if isinstance(current, dict) and "features" in current and i < len(parts) - 1:
                current = current["features"]
        else:
            return None

    # We iterated all parts.  The final current may be:
    # - A dict with 'default' key → return default
    # - Not a dict → unexpected, return None
    if isinstance(current, dict) and "default" in current:
        return current["default"]

    return None


__func_alias__ = {
    "feature_enabled": "feature_enabled",
    "feature_default": "feature_default",
}
