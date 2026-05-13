"""Salt execution module: desktop session helpers.

Replaces _macros_desktop.jinja: browser_extensions, hyprpm_update/add/enable, dconf_settings.
"""

from __future__ import annotations

from typing import Any
from _yaml_out import yaml_output


def _host() -> dict[str, Any]:
    try:
        from _modules.common import get_host
        return get_host()
    except Exception:
        return {"user": "root", "home": "/root", "runtime_dir": "/run/user/1000"}


def _const() -> dict[str, Any]:
    try:
        from _modules.common import get_constants
        return get_constants()
    except Exception:
        return {"retry_attempts": 3, "retry_interval": 10}


@yaml_output
def dconf_settings(name: str, settings: dict[str, str],
                   user: str | None = None,
                   require: list[str] | None = None) -> dict[str, Any]:
    u = user or _host()["user"]
    h = _host()
    import re

    def _escape(v: str) -> str:
        for ch in ["\\", '"', "`", "$"]:
            v = v.replace(ch, "\\" + ch)
        return v

    lines = ["set -eo pipefail"]
    checks = [f"export DBUS_SESSION_BUS_ADDRESS=unix:path={h['runtime_dir']}/bus"]
    for key, val in settings.items():
        safe = _escape(val)
        lines.append(f"dconf write {key} \"'{safe}'\"")
        checks.append(f"test \"$(dconf read {key})\" = \"'{safe}'\"")
    checks_joined = " && ".join(checks)

    args: list[dict[str, Any]] = [
        {"name": "\n".join(lines)},
        {"shell": "/bin/bash"}, {"runas": u},
        {"env": [{"DBUS_SESSION_BUS_ADDRESS": f"unix:path={h['runtime_dir']}/bus"}]},
        {"unless": checks_joined},
    ]
    if require:
        args.append({"require": [r for r in require]})

    return {name: {"cmd.run": args}}


@yaml_output
def hyprpm_update(name: str, check_plugins: list[str] | None = None,
                  require: list[str] | None = None,
                  timeout: int = 300) -> dict[str, Any]:
    h = _host()
    u = h["user"]
    sig_cmd = (
        f"ls -d /run/user/{h['uid']}/hypr/*/.socket.sock 2>/dev/null | "
        f"head -1 | xargs dirname | xargs basename"
    )
    onlyif = f"ss -xl 2>/dev/null | grep -q /run/user/{h['uid']}/hypr/"

    env_entries = [
        f"HOME: {h['home']}",
        f"XDG_RUNTIME_DIR: {h['runtime_dir']}",
    ]

    cmd = (
        f"export HYPRLAND_INSTANCE_SIGNATURE=$({sig_cmd}) && "
        f"hyprpm update 2>/dev/null || true"
    )

    unless_cmd = None
    if check_plugins:
        checks = [f"export HYPRLAND_INSTANCE_SIGNATURE=$({sig_cmd})"]
        for plugin in check_plugins:
            checks.append(f"(hyprpm list 2>&1 | grep -q '{plugin}')")
        unless_cmd = " && ".join(checks)

    args: list[dict[str, Any]] = [
        {"name": cmd}, {"runas": u}, {"onlyif": onlyif},
        {"env": env_entries},
        {"retry": {"attempts": _const()["retry_attempts"], "interval": _const()["retry_interval"]}},
        {"timeout": timeout},
    ]
    if unless_cmd:
        args.append({"unless": unless_cmd})
    if require:
        args.append({"require": [r for r in require]})

    return {name: {"cmd.run": args}}


@yaml_output
def hyprpm_add(name: str, repo_url: str, check_plugin: str,
               require: list[str] | None = None,
               timeout: int = 300) -> dict[str, Any]:
    h = _host()
    u = h["user"]
    sig_cmd = (
        f"ls -d /run/user/{h['uid']}/hypr/*/.socket.sock 2>/dev/null | "
        f"head -1 | xargs dirname | xargs basename"
    )
    onlyif = f"ss -xl 2>/dev/null | grep -q /run/user/{h['uid']}/hypr/"

    env_entries = [
        f"HOME: {h['home']}",
        f"XDG_RUNTIME_DIR: {h['runtime_dir']}",
    ]

    cmd = (
        f"export HYPRLAND_INSTANCE_SIGNATURE=$({sig_cmd}) && "
        f"yes | hyprpm add {repo_url} 2>/dev/null || true"
    )
    unless_cmd = (
        f"export HYPRLAND_INSTANCE_SIGNATURE=$({sig_cmd}) && "
        f"(hyprpm list 2>&1 | grep -q '{check_plugin}') || true"
    )

    args: list[dict[str, Any]] = [
        {"name": cmd}, {"runas": u}, {"onlyif": onlyif}, {"unless": unless_cmd},
        {"env": env_entries}, {"timeout": timeout},
        {"retry": {"attempts": _const()["retry_attempts"], "interval": _const()["retry_interval"]}},
    ]
    if require:
        args.append({"require": [r for r in require]})

    return {name: {"cmd.run": args}}


@yaml_output
def hyprpm_enable(name: str, plugin: str,
                  require: list[str] | None = None) -> dict[str, Any]:
    h = _host()
    u = h["user"]
    sig_cmd = (
        f"ls -d /run/user/{h['uid']}/hypr/*/.socket.sock 2>/dev/null | "
        f"head -1 | xargs dirname | xargs basename"
    )
    onlyif = f"ss -xl 2>/dev/null | grep -q /run/user/{h['uid']}/hypr/"

    env_entries = [
        f"HOME: {h['home']}",
        f"XDG_RUNTIME_DIR: {h['runtime_dir']}",
    ]

    cmd = (
        f"export HYPRLAND_INSTANCE_SIGNATURE=$({sig_cmd}) && "
        f"hyprpm enable {plugin} 2>/dev/null || true"
    )
    unless_cmd = (
        f"export HYPRLAND_INSTANCE_SIGNATURE=$({sig_cmd}) && "
        f"(hyprpm list 2>&1 | grep -A1 '{plugin}' | grep -q 'enabled:.*true') || true"
    )

    args: list[dict[str, Any]] = [
        {"name": cmd}, {"runas": u}, {"onlyif": onlyif}, {"unless": unless_cmd},
        {"env": env_entries},
    ]
    if require:
        args.append({"require": [r for r in require]})

    return {name: {"cmd.run": args}}
