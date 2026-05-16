"""Salt execution module: package managers (paru, pkgbuild, flatpak).

Replaces _macros_pkg.jinja.
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
            except KeyError:
                _home = f"/home/{_user}" if _user != "root" else "/root"
            return {
                "user": _user,
                "home": _home,
                "pkg_list": "/var/cache/salt/pacman_installed.txt",
            }


def _const() -> dict[str, Any]:
    try:
        from common import get_constants

        return get_constants()
    except Exception:
        h = _host()
        return {
            "retry_attempts": 3,
            "retry_interval": 10,
            "ver_dir": f"{h.get('home', '/root')}/.cache/salt-versions",
        }


def _paru_install_dict(
    name: str,
    pkg: str,
    check: str | None = None,
    requires: list[str] | None = None,
    version: str = "",
) -> dict[str, Any]:
    """Internal version — returns dict for simple_service to extend."""
    h = _host()
    u = h["user"]
    _ver_dir = f"{h.get('home', '/root')}/.cache/salt-versions"
    _check_all = check == "__ALL__" or (check is None and " " in pkg)
    requires_list = [{"cmd": "pacman_db_warmup"}]
    if requires:
        requires_list.extend(_parse_requires(requires))

    if version:
        cmd = (
            f"set -uo pipefail\n"
            f"if test -f {_ver_dir}/{name}@{version}; then "
            f"echo '{{\"changed\": false, \"comment\": \"all packages already installed\"}}'; exit 0; fi\n"
            f"output=$(sudo -u {u} sh -c 'yes \"\" | paru -S --noconfirm --needed {pkg}' 2>&1 || true)\n"
            f"echo \"$output\" >&2\n"
            f"if echo \"$output\" | grep -qi 'nothing to do'; then\n"
            f"    echo '{{\"changed\": false, \"comment\": \"all packages already installed\"}}'\n"
            f"else\n"
            f"    echo '{{\"changed\": true}}'\n"
            f"    mkdir -p {_ver_dir} && rm -f {_ver_dir}/{name} {_ver_dir}/{name}@* && "
            f"touch {_ver_dir}/{name}@{version}\n"
            f"fi"
        )
        return {
            f"install_{name.replace('-', '_')}": {
                "cmd.run": [
                    {"name": cmd},
                    {"shell": "/bin/bash"},
                    {"stateful": True},
                    {"unless": f"test -f {_ver_dir}/{name}@{version}"},
                    {"require": requires_list},
                ]
            }
        }

    if _check_all:
        cmd_lines = [
            "set -uo pipefail",
            f"if test -f {_ver_dir}/{name}@installed && test {_ver_dir}/{name}@installed -nt {h['pkg_list']}; then "
            'echo \'{"changed": false, "comment": "stamp ok, skipping"}\'; exit 0; fi',
            f"output=$(sudo -u {u} sh -c 'yes \"\" | paru -S --noconfirm --needed {pkg} || true' 2>&1)",
            'echo "$output" >&2',
            'if echo "$output" | grep -qi \'nothing to do\'; then',
            f'  mkdir -p {_ver_dir} && touch {_ver_dir}/{name}@installed',
            '  echo \'{"changed": false, "comment": "all packages already installed"}\'',
            'else',
            '  echo \'{"changed": true}\'',
            'fi',
        ]
        return {
            f"install_{name.replace('-', '_')}": {
                "cmd.run": [
                    {"name": "\n".join(cmd_lines)},
                    {"shell": "/bin/bash"},
                    {"stateful": True},
                    {"unless": f"test -f {_ver_dir}/{name}@installed && "
                               f"test {_ver_dir}/{name}@installed -nt {h['pkg_list']}"},
                    {"require": requires_list},
                ]
            }
        }

    return {
        f"install_{name.replace('-', '_')}": {
            "cmd.run": [
                {
                    "name": (
                        f"if grep -qxF '{check or pkg}' {h['pkg_list']}; then exit 0; fi\n"
                        f"output=$(sudo -u {u} paru -S --noconfirm --needed {pkg} 2>&1); "
                        f'echo "$output" >&2; '
                        f"if echo \"$output\" | grep -qi 'nothing to do'; then "
                        f"echo '{{\"changed\": false, \"comment\": \"all packages already installed\"}}'; "
                        f"else echo '{{\"changed\": true}}'; fi"
                    )
                },
                {"shell": "/bin/bash"},
                {"unless": f"grep -qxF '{check or pkg}' {h['pkg_list']}"},
                {"require": requires_list},
                {"stateful": True},
            ]
        }
    }


@yaml_output
def paru_install(
    name: str,
    pkg: str,
    check: str | None = None,
    requires: list[str] | None = None,
    version: str = "",
) -> dict[str, Any]:
    return _paru_install_dict(name, pkg, check=check, requires=requires, version=version)


@yaml_output
def simple_service(
    name: str,
    pkgs: str,
    service: str | None = None,
    check: str | None = None,
    requires: list[str] | None = None,
) -> dict[str, Any]:
    safe = name.replace("-", "_")
    ret = _paru_install_dict(name, pkgs, check=check)
    ret[f"{name}_enabled"] = {
        "service.enabled": [
            {"name": service or name},
            {"require": _parse_requires([{"cmd": f"install_{safe}"}] + (requires or []))},
        ]
    }
    return ret


@yaml_output
def pkgbuild_install(
    name: str,
    source: str,
    user: str | None = None,
    build_base: str = "/tmp/pkgbuild",
    timeout: int = 600,
    check: str | None = None,
    replace_check: str | None = None,
    conflicts: list[str] | None = None,
    extra_sources: list[dict[str, str]] | None = None,
) -> dict[str, Any]:
    h = _host()
    u = user or h["user"]
    safe = name.replace("-", "_")

    pkg_guard = f'grep -qxF "{check or name}" {h["pkg_list"]}'
    if replace_check:
        pkg_guard += f" && {replace_check}"

    ret: dict[str, Any] = {
        f"{safe}_pkgbuild": {
            "file.recurse": [
                {"name": f"{build_base}/{name}"},
                {"source": source},
                {"makedirs": True},
                {"user": u},
                {"group": u},
                {"unless": pkg_guard},
            ]
        }
    }

    # Extra sources
    if extra_sources:
        for i, es in enumerate(extra_sources):
            ret[f"{safe}_source_{i}"] = {
                "file.recurse": [
                    {"name": es["dest"]},
                    {"source": es["source"]},
                    {"makedirs": True},
                    {"user": u},
                    {"group": u},
                    {"unless": pkg_guard},
                ]
            }

    build_req = [{"file": f"{safe}_pkgbuild"}]
    if extra_sources:
        for i in range(len(extra_sources)):
            build_req.append({"file": f"{safe}_source_{i}"})
    build_req.append({"cmd": "pacman_db_warmup"})

    extra_source_dirs = " ".join(es["dest"] for es in (extra_sources or []))

    script_lines = ["set -eo pipefail"]
    if replace_check:
        script_lines.append(
            f"if pacman -Q {name} &>/dev/null && ! {replace_check}; then\n"
            f"    pacman -Rdd --noconfirm {name}\nfi"
        )
    for conflict in conflicts or []:
        script_lines.append(
            f"if pacman -Q {conflict} &>/dev/null; then\n    pacman -Rdd --noconfirm {conflict}\nfi"
        )
    script_lines.extend(
        [
            f"su - {u} -c 'cd {build_base}/{name} && rm -rf src pkg && makepkg -sf --noconfirm'",
            f"pkgs=$(ls {build_base}/{name}/*.pkg.tar.zst 2>/dev/null | grep -v -- '-debug-')",
            'if [ -n "$pkgs" ]; then pacman -U --noconfirm --needed $pkgs 2>/dev/null || true; fi',
            f"rm -rf {build_base}/{name}{' ' + extra_source_dirs if extra_source_dirs else ''}",
        ]
    )

    ret[f"build_{safe}"] = {
        "cmd.run": [
            {"name": "\n".join(script_lines)},
            {"shell": "/bin/bash"},
            {"timeout": timeout},
            {"unless": pkg_guard},
            {"require": build_req},
        ]
    }
    return ret


@yaml_output
def flatpak_install(app_id: str, user: str | None = None) -> dict[str, Any]:
    h = _host()
    u = user or h["user"]
    _home = h.get("home") or f"/home/{u}"
    c = _const()
    safe = app_id.replace(".", "_").replace("-", "_")
    unless_cmd = f"flatpak info --user {app_id} >/dev/null 2>&1"
    proxy = "socks5h://127.0.0.1:10808"
    return {
        f"install_flatpak_{safe}": {
            "cmd.run": [
                {"name": f"https_proxy={proxy} flatpak install -y --user flathub {app_id}"},
                {"runas": u},
                {"env": {"HOME": _home}},
                {"unless": f"https_proxy={proxy} {unless_cmd}"},
                {"retry": {"attempts": c["retry_attempts"], "interval": c["retry_interval"]}},
                {"require": [{"cmd": "flatpak_flathub_refs"}]},
            ]
        }
    }
