"""Salt execution module: desktop session helpers.

Replaces _macros_desktop.jinja: browser_extensions, hyprpm_update/add/enable, dconf_settings.
"""

from __future__ import annotations

from typing import Any

from _yaml_out import yaml_output

from common import _parse_requires


def _host() -> dict[str, Any]:
    try:
        return __salt__["common.get_host"]()
    except (NameError, KeyError):
        try:
            from common import get_host

            return get_host()
        except Exception:
            import os
            import pwd
            _user = os.environ.get("SUDO_USER") or os.environ.get("USER") or "root"
            try:
                _pw = pwd.getpwnam(_user)
                _home = _pw.pw_dir
                _uid = _pw.pw_uid
            except KeyError:
                _home = f"/home/{_user}" if _user != "root" else "/root"
                _uid = 0 if _user == "root" else 1000
            return {
                "user": _user,
                "home": _home,
                "uid": _uid,
                "runtime_dir": f"/run/user/{_uid}",
                "pkg_list": "/var/cache/salt/pacman_installed.txt",
                "ver_dir": f"{_home}/.cache/salt-versions",
            }


def _const() -> dict[str, Any]:
    try:
        return __salt__["common.get_constants"]()
    except (NameError, KeyError):
        try:
            from common import get_constants

            return get_constants()
        except Exception:
            return {"retry_attempts": 3, "retry_interval": 10}


@yaml_output
def dconf_settings(
    name: str, settings: dict[str, str], user: str | None = None, require: list[str] | None = None
) -> dict[str, Any]:
    u = user or _host()["user"]
    h = _host()

    def _escape(v: str) -> str:
        for ch in ["\\", '"', "`", "$"]:
            v = v.replace(ch, "\\" + ch)
        return v

    lines = ["set -eo pipefail"]
    checks = [f"export DBUS_SESSION_BUS_ADDRESS=unix:path={h['runtime_dir']}/bus"]
    for key, val in settings.items():
        safe = _escape(val)
        lines.append(f"dconf write {key} \"'{safe}'\"")
        checks.append(f'test "$(dconf read {key})" = "\'{safe}\'"')
    checks_joined = " && ".join(checks)

    args: list[dict[str, Any]] = [
        {"name": "\n".join(lines)},
        {"shell": "/bin/bash"},
        {"runas": u},
        {"env": {"DBUS_SESSION_BUS_ADDRESS": f"unix:path={h['runtime_dir']}/bus"}},
        {"unless": checks_joined},
    ]
    if require:
        args.append({"require": _parse_requires(require)})

    return {name: {"cmd.run": args}}


def hyprpm_data(
    check_plugins: list[str] | None = None,
) -> dict[str, Any]:
    """Return context dict for building hyprpm_headers_update state in SLS.

    Guard (stamp + plugin check) is built into the command prefix since Salt 3008
    ignores ``unless`` for ``Function: unknown`` states in highstate context.
    """
    h = _host()
    u = h["user"]
    sig_cmd = (
        f"ls -d /run/user/{h['uid']}/hypr/*/.socket.sock 2>/dev/null | "
        f"head -1 | xargs dirname | xargs basename"
    )
    stamp_path = f"{h['ver_dir']}/hyprpm_updated"
    guard = ""
    if check_plugins:
        checks = " && ".join(
            f"(hyprpm list 2>&1 | grep -q '{plugin}')" for plugin in check_plugins
        )
        guard = f"test -f {stamp_path} && {checks} && echo '{{\"changed\": false, \"comment\": \"up to date\"}}' && exit 0; "
    cmd = (
        f"MARKER_V2_{guard}"
        f"export HYPRLAND_INSTANCE_SIGNATURE=$({sig_cmd}) && "
        f"(hyprpm update 2>/dev/null || true); "
        f"echo '{{\"changed\": true, \"comment\": \"hyprpm updated\"}}'; "
        f"touch {stamp_path}"
    )
    return {
        "cmd": cmd,
        "runas": u,
        "onlyif": f"ss -xl 2>/dev/null | grep -q /run/user/{h['uid']}/hypr/",
        "home": h["home"],
        "uid": h["uid"],
        "runtime_dir": h["runtime_dir"],
        "stamp": stamp_path,
    }


def hyprpm_add_data(
    repo_url: str,
    check_plugin: str,
) -> dict[str, Any]:
    """Return context dict for building hyprpm_add_* state in SLS."""
    h = _host()
    u = h["user"]
    sig_cmd = (
        f"ls -d /run/user/{h['uid']}/hypr/*/.socket.sock 2>/dev/null | "
        f"head -1 | xargs dirname | xargs basename"
    )
    guard = f"(hyprpm list 2>&1 | grep -q '{check_plugin}') && echo '{{\"changed\": false, \"comment\": \"already added\"}}' && exit 0; "
    cmd = (
        f"{guard}"
        f"export HYPRLAND_INSTANCE_SIGNATURE=$({sig_cmd}) && "
        f"yes | hyprpm add {repo_url} 2>/dev/null || true"
    )
    return {
        "cmd": cmd,
        "runas": u,
        "onlyif": f"ss -xl 2>/dev/null | grep -q /run/user/{h['uid']}/hypr/",
        "home": h["home"],
        "uid": h["uid"],
        "runtime_dir": h["runtime_dir"],
    }


def hyprpm_enable_data(
    plugin: str,
) -> dict[str, Any]:
    """Return context dict for building hyprpm_enable_* state in SLS."""
    h = _host()
    u = h["user"]
    sig_cmd = (
        f"ls -d /run/user/{h['uid']}/hypr/*/.socket.sock 2>/dev/null | "
        f"head -1 | xargs dirname | xargs basename"
    )
    guard = (
        f"(hyprpm list 2>&1 | grep -A1 '{plugin}' | grep -q 'enabled:.*true') && "
        f"echo '{{\"changed\": false, \"comment\": \"already enabled\"}}' && exit 0; "
    )
    cmd = (
        f"{guard}"
        f"export HYPRLAND_INSTANCE_SIGNATURE=$({sig_cmd}) && "
        f"hyprpm enable {plugin} 2>/dev/null || true"
    )
    return {
        "cmd": cmd,
        "runas": u,
        "onlyif": f"ss -xl 2>/dev/null | grep -q /run/user/{h['uid']}/hypr/",
        "home": h["home"],
        "uid": h["uid"],
        "runtime_dir": h["runtime_dir"],
    }


@yaml_output
def hyprpm_update(
    name: str,
    check_plugins: list[str] | None = None,
    require: list[str] | None = None,
    timeout: int = 300,
) -> dict[str, Any]:
    h = _host()
    u = h["user"]
    sig_cmd = (
        f"ls -d /run/user/{h['uid']}/hypr/*/.socket.sock 2>/dev/null | "
        f"head -1 | xargs dirname | xargs basename"
    )
    onlyif = f"ss -xl 2>/dev/null | grep -q /run/user/{h['uid']}/hypr/"

    env_entries = {
        "HOME": h["home"],
        "XDG_RUNTIME_DIR": h["runtime_dir"],
    }

    stamp_path = f"{h['ver_dir']}/hyprpm_updated"

    cmd = (
        f"export HYPRLAND_INSTANCE_SIGNATURE=$({sig_cmd}) && "
        f"(hyprpm update 2>/dev/null || true); "
        f"touch {stamp_path}"
    )

    unless_cmd = None
    if check_plugins:
        checks = [f"(hyprpm list 2>&1 | grep -q '{plugin}')" for plugin in check_plugins]
        plugin_check = " && ".join(checks)
        unless_cmd = f"test -f {stamp_path} && {plugin_check}"

    args: list[dict[str, Any]] = [
        {"name": cmd},
        {"runas": u},
        {"onlyif": onlyif},
        {"env": env_entries},
        {"retry": {"attempts": _const()["retry_attempts"], "interval": _const()["retry_interval"]}},
        {"timeout": timeout},
    ]
    if unless_cmd:
        args.append({"unless": unless_cmd})
    if require:
        args.append({"require": _parse_requires(require)})

    return {name: {"cmd.run": args}}


@yaml_output
def hyprpm_add(
    name: str,
    repo_url: str,
    check_plugin: str,
    require: list[str] | None = None,
    timeout: int = 300,
) -> dict[str, Any]:
    h = _host()
    u = h["user"]
    sig_cmd = (
        f"ls -d /run/user/{h['uid']}/hypr/*/.socket.sock 2>/dev/null | "
        f"head -1 | xargs dirname | xargs basename"
    )
    onlyif = f"ss -xl 2>/dev/null | grep -q /run/user/{h['uid']}/hypr/"

    env_entries = {
        "HOME": h["home"],
        "XDG_RUNTIME_DIR": h["runtime_dir"],
    }

    cmd = (
        f"export HYPRLAND_INSTANCE_SIGNATURE=$({sig_cmd}) && "
        f"yes | hyprpm add {repo_url} 2>/dev/null || true"
    )
    unless_cmd = (
        f"(hyprpm list 2>&1 | grep -q '{check_plugin}') || true"
    )

    args: list[dict[str, Any]] = [
        {"name": cmd},
        {"runas": u},
        {"onlyif": onlyif},
        {"unless": unless_cmd},
        {"env": env_entries},
        {"timeout": timeout},
        {"retry": {"attempts": _const()["retry_attempts"], "interval": _const()["retry_interval"]}},
    ]
    if require:
        args.append({"require": _parse_requires(require)})

    return {name: {"cmd.run": args}}


@yaml_output
def hyprpm_enable(name: str, plugin: str, require: list[str] | None = None) -> dict[str, Any]:
    h = _host()
    u = h["user"]
    sig_cmd = (
        f"ls -d /run/user/{h['uid']}/hypr/*/.socket.sock 2>/dev/null | "
        f"head -1 | xargs dirname | xargs basename"
    )
    onlyif = f"ss -xl 2>/dev/null | grep -q /run/user/{h['uid']}/hypr/"

    env_entries = {
        "HOME": h["home"],
        "XDG_RUNTIME_DIR": h["runtime_dir"],
    }

    cmd = (
        f"export HYPRLAND_INSTANCE_SIGNATURE=$({sig_cmd}) && "
        f"hyprpm enable {plugin} 2>/dev/null || true"
    )
    unless_cmd = (
        f"(hyprpm list 2>&1 | grep -A1 '{plugin}' | grep -q 'enabled:.*true') || true"
    )

    args: list[dict[str, Any]] = [
        {"name": cmd},
        {"runas": u},
        {"onlyif": onlyif},
        {"unless": unless_cmd},
        {"env": env_entries},
    ]
    if require:
        args.append({"require": _parse_requires(require)})

    return {name: {"cmd.run": args}}


@yaml_output
def browser_extensions(
    prefix: str,
    profile: str,
    extensions: list[dict[str, Any]],
    user_js_id: str,
    unwanted: list[str] | None = None,
    user: str | None = None,
) -> dict[str, Any]:
    u = user or _host()["user"]
    ext_dir = f"{profile}/extensions"
    out: dict[str, Any] = {}

    ext_dir_id = f"{prefix}_extensions_dir"
    out[ext_dir_id] = {
        "file.directory": [
            {"name": ext_dir},
            {"user": u},
            {"group": u},
            {"makedirs": True},
        ]
    }

    for ext in extensions:
        ext_id = ext.get("id", "")
        slug = ext.get("slug", "")
        xpi = f"{ext_dir}/{ext_id}.xpi"
        slug_safe = slug.replace("-", "_")
        state_id = f"{prefix}_ext_{slug_safe}"
        cmd = (
            f"rm -f '{xpi}.tmp'\n"
            f"if curl --http1.1 --fail --silent --show-error --location "
            f"--ipv4 "
            f"--connect-timeout 10 --max-time 30 "
            f"--retry 3 --retry-delay 3 --retry-max-time 60 --retry-all-errors "
            f"-o '{xpi}.tmp' "
            f"'https://addons.mozilla.org/firefox/downloads/latest/{slug}/latest.xpi'; then\n"
            f"  mv -f '{xpi}.tmp' '{xpi}'\n"
            f"else\n"
            f"  rm -f '{xpi}.tmp'\n"
            f'  echo "WARNING: download of {slug} failed, will retry on next apply" >&2\n'
            f"fi"
        )
        out[state_id] = {
            "cmd.run": [
                {"name": cmd},
                {"creates": xpi},
                {"runas": u},
                {"parallel": True},
                {"require": [{"file": ext_dir_id}]},
            ]
        }

    if unwanted:
        for ext_id_val in unwanted:
            safe_id = (
                ext_id_val.replace("{", "")
                .replace("}", "")
                .replace("-", "_")
                .replace("@", "_")
                .replace(".", "_")
            )
            remove_id = f"{prefix}_remove_{safe_id}"
            out[remove_id] = {
                "file.absent": [
                    {"name": f"{ext_dir}/{ext_id_val}.xpi"},
                ]
            }

    reset_id = f"{prefix}_reset_extensions_json"
    onchanges: list[dict[str, str]] = [{"file": user_js_id}]
    for ext in extensions:
        slug = ext.get("slug", "")
        slug_safe = slug.replace("-", "_")
        onchanges.append({"cmd": f"{prefix}_ext_{slug_safe}"})
    out[reset_id] = {
        "file.absent": [
            {"name": f"{profile}/extensions.json"},
            {"onchanges_any": onchanges},
        ]
    }

    return out
