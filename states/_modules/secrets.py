"""Salt execution module: secure secret resolution via gopass.

Replaces gopass_secret(), tg_secret(), proxypilot_key() from _macros_common.jinja.
Caches resolved secrets in module-level dict to avoid repeated gopass calls.
"""

from __future__ import annotations

from typing import Any

_SECRET_CACHE: dict[str, str] = {}
_GOPASS_CHECKED: bool = False
_GOPASS_AVAILABLE: bool = False


def _host() -> dict[str, Any]:
    try:
        return __salt__["common.get_host"]()
    except (NameError, KeyError):
        try:
            from _modules.common import get_host
            return get_host()
        except Exception:
            return {"user": "root", "home": "/root", "pkg_list": "/var/cache/salt/pacman_installed.txt"}


def gopass_secret(key: str, fallback_cmd: str = "true",
                  runas: str | None = None) -> str:
    """Resolve a secret from gopass, with optional shell fallback.

    Caches results across calls within the same render session.
    On first call, probes gopass availability; if unreachable,
    subsequent calls skip gopass and use fallback directly.
    """
    global _GOPASS_CHECKED, _GOPASS_AVAILABLE

    h = _host()
    u = runas or h["user"]
    home = h["home"]

    cached = _SECRET_CACHE.get(key)
    if cached is not None:
        return cached

    import subprocess

    try_gopass = (not _GOPASS_CHECKED) or _GOPASS_AVAILABLE
    if try_gopass:
        try:
            result = subprocess.run(
                [
                    "sudo", "-u", u,
                    "env",
                    f"HOME={home}",
                    f"PASSWORD_STORE_DIR={home}/.local/share/pass",
                    f"GNUPGHOME={home}/.local/share/gnupg",
                    f"XDG_RUNTIME_DIR=/run/user/$(id -u)",
                    "gopass", "show", "-o", key,
                ],
                capture_output=True, text=True, timeout=10,
            )
            if not _GOPASS_CHECKED:
                _GOPASS_CHECKED = True
                _GOPASS_AVAILABLE = (result.returncode == 0)

            if result.returncode == 0:
                val = result.stdout.strip()
                _SECRET_CACHE[key] = val
                return val
        except Exception:
            if not _GOPASS_CHECKED:
                _GOPASS_CHECKED = True
                _GOPASS_AVAILABLE = False

    # Fallback
    try:
        fallback_result = subprocess.run(
            ["sudo", "-u", u, "bash", "-c", fallback_cmd],
            capture_output=True, text=True, timeout=10,
        )
        val = fallback_result.stdout.strip()
    except Exception:
        val = ""

    _SECRET_CACHE[key] = val
    return val


def proxypilot_key() -> str:
    h = _host()
    home = h["home"]
    fallback = (
        f"awk '/^api-keys:/{{getline; sub(/^[[:space:]]*-[[:space:]]*\"?/, \"\"); "
        f"sub(/\"?[[:space:]]*$/, \"\"); print; exit}}' "
        f"{home}/.config/proxypilot/config.yaml 2>/dev/null || true"
    )
    return gopass_secret("api/proxypilot-local", fallback)


def tg_secret(gopass_key: str, cred_file: str,
              cred_base: str | None = None) -> str:
    h = _host()
    home = h["home"]
    base = cred_base or f"{home}/.nanoclaw/credentials"
    fallback = f"cat {base}/{cred_file} 2>/dev/null || true"
    return gopass_secret(gopass_key, fallback)


__func_alias__ = {
    "get": "gopass_secret",
}
