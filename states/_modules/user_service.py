"""Salt execution module: user-scoped service lifecycle.

Replaces _macros_service_user.jinja.
Each function returns a dict of Salt state data for offline rendering;
when called inside Salt runtime, delegates to __states__.
"""

from __future__ import annotations

from typing import Any

from _yaml_out import yaml_output


def _host() -> dict[str, Any]:
    try:
        import __salt__  # type: ignore[import-untyped]
        return __salt__["common.get_host"]()
    except (ImportError, KeyError):
        try:
            from _modules.common import get_host
            return get_host()
        except Exception:
            return {"user": "root", "home": "/root", "runtime_dir": "/run/user/1000", "pkg_list": "/var/cache/salt/pacman_installed.txt", "systemd_unit_dir": "/etc/systemd/system/", "systemd_user_unit_dir": "/root/.config/systemd/user/"}


def _sysctl_env() -> dict[str, str]:
    h = _host()
    return {
        "XDG_RUNTIME_DIR": h["runtime_dir"],
        "DBUS_SESSION_BUS_ADDRESS": f"unix:path={h['runtime_dir']}/bus",
    }


def _user_env_prefix() -> str:
    """Shell prefix that sets user-session env vars for systemctl --user."""
    h = _host()
    return (f"XDG_RUNTIME_DIR={h['runtime_dir']} "
            f"DBUS_SESSION_BUS_ADDRESS=unix:path={h['runtime_dir']}/bus")


def _user_service_file_dict(name: str, filename: str, source: str | None = None,
                            template: str | None = None,
                            context: dict[str, Any] | None = None,
                            user: str | None = None,
                            home: str | None = None) -> dict[str, Any]:
    u = user or _host()["user"]
    h = home or _host()["home"]
    _user_dir = _host().get("systemd_user_unit_dir", f"{h}/.config/systemd/user/")
    src = source or f"salt://units/user/{filename}"

    fargs: list[dict[str, Any]] = [
        {"name": f"{_user_dir}{filename}"},
        {"source": src},
        {"user": u}, {"group": u},
        {"mode": "0644"}, {"makedirs": True},
    ]
    if template:
        fargs.append({"template": template})
    if context:
        fargs.append({"context": context})

    return {
        name: {"file.managed": fargs},
        f"{name}_daemon_reload": {
            "cmd.run": [
                {"name": "systemctl --user daemon-reload"},
                {"onlyif": _user_env_prefix() + " systemctl --user show-environment >/dev/null 2>&1"},
                {"runas": u},
                {"env": _sysctl_env()},
                {"onchanges": [{"file": name}]},
            ]
        },
    }


@yaml_output
def user_service_file(name: str, filename: str, source: str | None = None,
                      template: str | None = None,
                      context: dict[str, Any] | None = None,
                      user: str | None = None,
                      home: str | None = None) -> dict[str, Any]:
    return _user_service_file_dict(name, filename, source=source, template=template,
                                   context=context, user=user, home=home)


@yaml_output
def user_unit_override(name: str, service: str, source: str | None = None,
                      contents: str | None = None,
                      filename: str = "override.conf",
                      requires: list[str] | None = None,
                      user: str | None = None,
                      home: str | None = None) -> dict[str, Any]:
    u = user or _host()["user"]
    h = home or _host()["home"]
    _user_dir = _host().get("systemd_user_unit_dir", f"{h}/.config/systemd/user/")
    fargs: list[dict[str, Any]] = [
        {"name": f"{_user_dir}{service}.d/{filename}"},
        {"user": u}, {"group": u},
        {"mode": "0644"}, {"makedirs": True},
    ]
    if contents is not None:
        fargs.append({"contents": contents})
    elif source:
        fargs.append({"source": source})
    if requires:
        fargs.append({"require": [r for r in requires]})
    ret: dict[str, Any] = {
        name: {"file.managed": fargs},
        f"{name}_daemon_reload": {
            "cmd.run": [
                {"name": "systemctl --user daemon-reload"},
                {"onlyif": _user_env_prefix() + " systemctl --user show-environment >/dev/null 2>&1"},
                {"runas": u},
                {"env": _sysctl_env()},
                {"onchanges": [{"file": name}]},
            ]
        },
    }
    return ret


def _user_service_enable_dict(name: str, services: list[str] | None = None,
                              start_now: list[str] | None = None,
                              daemon_reload: bool = False,
                              check: str = "enabled",
                              onlyif: str | None = None,
                              requires: list[str] | None = None,
                              user: str | None = None) -> dict[str, Any]:
    u = user or _host()["user"]
    svc_list = services or []
    now_list = start_now or []
    all_units = svc_list + now_list
    h = _host()

    if not all_units and not daemon_reload:
        shell_cmd = "/usr/bin/true"
    else:
        parts = ["set -euo pipefail"]
        parts.append(f"export XDG_RUNTIME_DIR={h['runtime_dir']} "
                     f"DBUS_SESSION_BUS_ADDRESS=unix:path={h['runtime_dir']}/bus")
        if daemon_reload:
            parts.append("systemctl --user daemon-reload")
        for svc in svc_list:
            parts.append(
                f"systemctl --user is-{check} '{svc}' >/dev/null 2>&1 "
                f"|| systemctl --user enable '{svc}'"
            )
        for svc in now_list:
            parts.append(
                f"systemctl --user is-active '{svc}' >/dev/null 2>&1 "
                f"|| systemctl --user enable --now '{svc}'"
            )
        shell_cmd = "\n".join(parts)

    unless_cmd = None
    if all_units:
        checks = [f"export XDG_RUNTIME_DIR={h['runtime_dir']}"]
        checks.append(
            f"export DBUS_SESSION_BUS_ADDRESS=unix:path={h['runtime_dir']}/bus"
        )
        for svc in svc_list:
            checks.append(
                f"systemctl --user is-{check} '{svc}' >/dev/null 2>&1"
            )
        for svc in now_list:
            checks.append(
                f"systemctl --user is-enabled '{svc}' >/dev/null 2>&1"
            )
        unless_cmd = " && ".join(checks)

    args: list[dict[str, Any]] = [
        {"name": shell_cmd},
        {"shell": "/bin/bash"}, {"runas": u},
        {"env": _sysctl_env()},
    ]
    if unless_cmd:
        args.append({"unless": unless_cmd})
    if onlyif:
        args.append({"onlyif": onlyif})
    if requires:
        args.append({"require": [r for r in requires]})

    return {name: {"cmd.run": args}}


@yaml_output
def user_service_enable(name: str, services: list[str] | None = None,
                        start_now: list[str] | None = None,
                        daemon_reload: bool = False,
                        check: str = "enabled",
                        onlyif: str | None = None,
                        requires: list[str] | None = None,
                        user: str | None = None) -> dict[str, Any]:
    return _user_service_enable_dict(name, services=services, start_now=start_now,
                                      daemon_reload=daemon_reload, check=check,
                                      onlyif=onlyif, requires=requires, user=user)


@yaml_output
def user_service_with_unit(name: str, filename: str, source: str | None = None,
                           services: list[str] | None = None,
                           start_now: list[str] | None = None,
                           requires: list[str] | None = None,
                           user: str | None = None,
                           home: str | None = None) -> dict[str, Any]:
    svc_list = services if services is not None else [filename]
    file_id = f"{name}_service"
    ret = _user_service_file_dict(file_id, filename, source=source, user=user, home=home)
    reqs = [f"file: {file_id}", f"cmd: {file_id}_daemon_reload"]
    if requires:
        reqs.extend(requires)
    ret.update(_user_service_enable_dict(
        f"{name}_enabled", services=svc_list, start_now=start_now or [],
        requires=reqs, user=user,
    ))
    return ret


@yaml_output
def user_service_restart(name: str, service: str, onlyif: str | None = None,
                         requires: list[str] | None = None,
                         onchanges: list[str] | None = None,
                         user: str | None = None) -> dict[str, Any]:
    u = user or _host()["user"]
    _h = _host()
    args: list[dict[str, Any]] = [
        {"name": (f"XDG_RUNTIME_DIR={_h['runtime_dir']} "
                  f"DBUS_SESSION_BUS_ADDRESS=unix:path={_h['runtime_dir']}/bus "
                  f"systemctl --user restart {service}")},
        {"runas": u},
    ]
    if onlyif:
        args.append({"onlyif": onlyif})
    if requires:
        args.append({"require": [r for r in requires]})
    if onchanges:
        args.append({"onchanges": [c for c in onchanges]})
    return {name: {"cmd.run": args}}


@yaml_output
def user_service_disable(name: str, units: list[str],
                         user: str | None = None) -> dict[str, Any]:
    u = user or _host()["user"]
    h = _host()
    unless_parts = [
        f"export XDG_RUNTIME_DIR={h['runtime_dir']}",
        f"export DBUS_SESSION_BUS_ADDRESS=unix:path={h['runtime_dir']}/bus",
    ]
    for unit in units:
        unless_parts.append(
            f"systemctl --user is-enabled '{unit}' >/dev/null 2>&1 && exit 0"
        )
    unless_parts.append("exit 1")

    return {
        name: {
            "cmd.run": [
                {"name": (f"XDG_RUNTIME_DIR={h['runtime_dir']} "
                          f"DBUS_SESSION_BUS_ADDRESS=unix:path={h['runtime_dir']}/bus "
                          f"systemctl --user disable --now {' '.join(units)} 2>/dev/null || true")},
                {"runas": u},
                {"onlyif": "\n".join(unless_parts)},
            ]
        }
    }


@yaml_output
def user_linger(name: str, user: str | None = None,
                require: list[str] | None = None) -> dict[str, Any]:
    u = user or _host()["user"]
    args: list[dict[str, Any]] = [
        {"name": f"loginctl enable-linger {u}"},
        {"unless": f"loginctl show-user {u} 2>/dev/null | grep -q '^Linger=yes'"},
    ]
    if require:
        args.append({"require": [r for r in require]})
    return {name: {"cmd.run": args}}
