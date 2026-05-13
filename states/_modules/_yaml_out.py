"""YAML conversion helpers for Salt execution modules."""

from __future__ import annotations

import functools
from typing import Any, Callable

try:
    import yaml
except ImportError:
    yaml = None  # type: ignore[assignment]


def to_yaml(obj: Any) -> str:
    """Convert Python object to YAML string suitable for {{ }} injection."""
    if yaml is None:
        return str(obj)
    raw = yaml.dump(obj, default_flow_style=False, allow_unicode=True, sort_keys=False)
    if raw.endswith("...\n"):
        raw = raw[:-4]
    return raw


def yaml_output(func: Callable) -> Callable:
    """Decorator: convert dict return values to YAML strings.
    
    State-emitting functions that return Salt state dicts use this
    decorator so {{ salt['module.func'](...) }} outputs valid YAML.
    Value-returning functions (bool, str, None) pass through unchanged.
    """
    @functools.wraps(func)
    def wrapper(*args: Any, **kwargs: Any) -> Any:
        result = func(*args, **kwargs)
        if isinstance(result, dict):
            return to_yaml(result)
        return result
    return wrapper
