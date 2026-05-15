"""Salt execution module: config file editing.

Replaces _macros_config.jinja config_file_edit().
"""

from __future__ import annotations

from typing import Any

from _yaml_out import yaml_output

from _modules.common import _parse_requires


def _const() -> dict[str, Any]:
    try:
        from _modules.common import get_constants

        return get_constants()
    except Exception:
        return {"retry_attempts": 3, "retry_interval": 10}


@yaml_output
def config_file_edit(
    name: str,
    cmd: str,
    unless: str | None = None,
    check_pattern: str | None = None,
    check_file: str | None = None,
    onlyif: str | None = None,
    require: list[str] | None = None,
    retry: bool = False,
    shell: str | None = None,
) -> dict[str, Any]:
    """Wrap a config-file edit with idempotency guard and optional retry."""
    guard = unless
    if guard is None and check_pattern and check_file:
        guard = f"grep -q '{check_pattern}' {check_file}"

    args: list[dict[str, Any]] = [{"name": cmd.strip()}]
    if shell:
        args.append({"shell": shell})
    if guard:
        args.append({"unless": guard.strip()})
    if onlyif:
        args.append({"onlyif": onlyif.strip()})
    if retry:
        c = _const()
        args.append({"retry": {"attempts": c["retry_attempts"], "interval": c["retry_interval"]}})
    if require:
        args.append({"require": _parse_requires(require)})

    return {name: {"cmd.run": args}}
