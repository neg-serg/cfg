"""Salt execution module: container_service replacement (YAML output).

Returns YAML string for {{ }} injection from Jinja templates.
Delegates to _states/container.py for the core logic.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

try:
    from _yaml_out import to_yaml as _to_yaml
except ImportError:

    def _to_yaml(obj: Any) -> str:
        try:
            import yaml

            return yaml.dump(obj, default_flow_style=False, allow_unicode=True)
        except Exception:
            return str(obj)


from _modules.common import _parse_requires


def _load_yaml(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    try:
        import yaml

        data = yaml.safe_load(path.read_text())
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def _get_data_dir() -> Path:
    return Path(__file__).resolve().parent.parent / "data"


def _tilde_expand(raw_path: str, home: str) -> str:
    if raw_path == "~":
        return home
    if isinstance(raw_path, str) and raw_path.startswith("~/"):
        return home + "/" + raw_path[2:]
    return raw_path


def deploy(
    name: str,
    catalog_entry: dict[str, Any] | None = None,
    image_registry: dict[str, Any] | None = None,
    user_scope: bool = False,
    requires: list[str] | None = None,
    watch: list[str] | None = None,
    quadlet_unit_name: str | None = None,
) -> str:
    """Return YAML string with all container states. Compatible with _macros_container.jinja."""

    catalog = catalog_entry
    if catalog is None:
        all_cat = _load_yaml(_get_data_dir() / "service_catalog.yaml")
        catalog = all_cat.get(name, {})

    registry = image_registry
    if registry is None:
        registry = _load_yaml(_get_data_dir() / "container_images.yaml")

    if not isinstance(catalog, dict):
        return ""

    if not isinstance(registry, dict):
        return ""

    try:
        host = __salt__["common.get_host"]()
    except (NameError, KeyError):
        try:
            from _modules.common import get_host

            host = get_host()
        except Exception:
            host = {}
    home = host.get("home") or "/root"
    host_user = host.get("user") or "root"
    runtime_dir = host.get("runtime_dir") or "/run/user/1000"

    quadlet_name = quadlet_unit_name if quadlet_unit_name is not None else name

    # --- Preconditions ---
    image_key = catalog.get("container_image")
    if not image_key or image_key not in registry:
        return (
            f"# PRECONDITION FAILED: container_service({name}): image_key '{image_key}' not found\n"
        )

    img = registry[image_key]
    digest = img.get("digest")
    img_registry = img.get("registry", "")
    is_localhost = img_registry == "localhost"
    catalog_scope = catalog.get("scope", "system")
    gpu = catalog.get("gpu", "none")

    digest_ok = (is_localhost and digest is None) or (
        isinstance(digest, str) and digest.startswith("sha256:") and len(digest) == 71
    )
    scope_ok = (user_scope and catalog_scope == "user") or (
        not user_scope and catalog_scope == "system"
    )
    gpu_ok = not (gpu == "amdgpu" and user_scope)

    if not digest_ok:
        return f"# PRECONDITION FAILED: container_service({name}): bad digest\n"
    if not scope_ok:
        return f"# PRECONDITION FAILED: container_service({name}): scope mismatch\n"
    if not gpu_ok:
        return (
            f"# PRECONDITION FAILED: container_service({name}): gpu=amdgpu requires system scope\n"
        )

    # --- Image ---
    if is_localhost:
        full_image = f"localhost/{img['image']}"
    else:
        full_image = f"{img_registry}/{img['image']}@{digest}"

    manual_start = catalog.get("manual_start", False)
    retry = {"attempts": 3, "interval": 10}

    # --- Quadlet ---
    if user_scope:
        quadlet_path = f"{home}/.config/containers/systemd/{quadlet_name}.container"
        quadlet_source = f"salt://units/user/{quadlet_name}.container"
    else:
        quadlet_path = f"/etc/containers/systemd/{quadlet_name}.container"
        quadlet_source = f"salt://units/{quadlet_name}.container"

    expanded_mounts = []
    for bm in catalog.get("bind_mounts", []):
        expanded_mounts.append(
            {
                "host": _tilde_expand(bm["host"], home),
                "container": bm["container"],
                "mode": bm["mode"],
            }
        )

    # --- Build YAML ---
    result: dict[str, Any] = {}

    # Quadlet unit file
    fdata: list[dict[str, Any]] = [
        {"name": quadlet_path},
        {"source": quadlet_source},
        {"template": "jinja"},
        {"mode": "0644"},
        {"makedirs": True},
        {
            "context": {
                "catalog_entry": catalog,
                "image": full_image,
                "expanded_mounts": expanded_mounts,
                "user_scope": user_scope,
            }
        },
    ]
    if user_scope:
        fdata.append({"user": host_user})
        fdata.append({"group": host_user})
    result[f"{name}_container"] = {"file.managed": fdata}

    # Image pull
    if not is_localhost:
        pdata: list[dict[str, Any]] = [
            {"name": f"podman pull {full_image}"},
            {"unless": f"podman image exists {full_image}"},
            {"retry": retry},
        ]
        if user_scope:
            pdata.append({"runas": host_user})
        if requires:
            pdata.append({"require": _parse_requires(requires)})
        result[f"{name}_image_pull"] = {"cmd.run": pdata}

    # Daemon reload
    onlyif = (
        f"XDG_RUNTIME_DIR={runtime_dir} DBUS_SESSION_BUS_ADDRESS=unix:path={runtime_dir}/bus "
        f"systemctl --user show-environment >/dev/null 2>&1"
        if user_scope
        else "test -e /run/systemd/system || test -e /etc/systemd/system"
    )
    reload: list[dict[str, Any]] = [
        {"name": f"systemctl {'--user ' if user_scope else ''}daemon-reload"},
        {"onlyif": onlyif},
        {"onchanges": [{"file": f"{name}_container"}]},
    ]
    if user_scope:
        reload.append({"runas": host_user})
    result[f"{name}_daemon_reload"] = {"cmd.run": reload}

    _user_env = (
        {"XDG_RUNTIME_DIR": runtime_dir, "DBUS_SESSION_BUS_ADDRESS": f"unix:path={runtime_dir}/bus"}
        if user_scope
        else None
    )

    def _sc(cmd):
        return f"{'--user ' if user_scope else ''}{cmd}"

    # Enable + Running + Healthcheck (skip if manual start)
    if not manual_start:
        enable: list[dict[str, Any]] = [
            {
                "name": (
                    f"systemctl {_sc('')}is-enabled "
                    f"{quadlet_name}.service >/dev/null 2>&1 || "
                    f"systemctl {_sc('')}enable {quadlet_name}.service"
                )
            },
            {"unless": f"systemctl {_sc('')}is-enabled {quadlet_name}.service >/dev/null 2>&1"},
        ]
        enable_req = [{"cmd": f"{name}_daemon_reload"}]
        if not is_localhost:
            enable_req.insert(0, {"cmd": f"{name}_image_pull"})
        enable.append({"require": enable_req})
        if user_scope:
            enable.append({"runas": host_user})
            enable.append({"env": _user_env})
        result[f"{name}_enabled"] = {"cmd.run": enable}

        reset: list[dict[str, Any]] = [
            {"name": f"systemctl {_sc('')}reset-failed {quadlet_name} 2>/dev/null; true"},
            {"onlyif": f"systemctl {_sc('')}is-failed {quadlet_name}"},
            {"require": [{"cmd": f"{name}_enabled"}]},
        ]
        if user_scope:
            reset.append({"runas": host_user})
            reset.append({"env": _user_env})
        result[f"{name}_reset_failed"] = {"cmd.run": reset}

        running: list[dict[str, Any]] = [
            {
                "name": (
                    f"systemctl {_sc('')}is-active {quadlet_name}.service "
                    f">/dev/null 2>&1 || systemctl {_sc('')}start {quadlet_name}.service"
                )
            },
            {"unless": f"systemctl {_sc('')}is-active {quadlet_name}.service >/dev/null 2>&1"},
            {"watch": [{"file": f"{name}_container"}, *(watch or [])]},
            {"require": [{"cmd": f"{name}_enabled"}, {"cmd": f"{name}_reset_failed"}]},
        ]
        if user_scope:
            running.append({"runas": host_user})
            running.append({"env": _user_env})
        result[f"{name}_running"] = {"cmd.run": running}

    return _to_yaml(result)
