"""YAML serialization helper for state-emitting execution modules.

When a Salt execution module returns a YAML string via {{ }},
Jinja injects it directly into the template output as valid state YAML.
"""

from __future__ import annotations

from typing import Any

try:
    import yaml
except ImportError:
    yaml = None  # type: ignore[assignment]


def to_yaml(obj: Any) -> str:
    """Convert a Python dict to a YAML string suitable for {{ }} injection.

    Handles Salt state data structures like:
      {'state_id': {'file.managed': [{'name': '/path'}, ...]}}
    """
    if yaml is None:
        return str(obj)
    raw = yaml.dump(obj, default_flow_style=False, allow_unicode=True, sort_keys=False)
    if raw.endswith("\n...\n"):
        raw = raw[:-4]
    return raw


def to_yaml_multi(states: dict[str, Any]) -> str:
    """Convert multiple state dicts into one YAML block.

    Accepts either {'id': state_dict} or a list of such dicts.
    """
    merged: dict[str, Any] = {}
    if isinstance(states, list):
        for d in states:
            if isinstance(d, dict):
                merged.update(d)
    elif isinstance(states, dict):
        merged = states
    return to_yaml(merged)
