"""Salt custom state module: containerized service deployment.

Replaces _macros_container.jinja container_service() macro.

Usage in .sls:
    ollama_container:
      container.managed:
        - name: ollama
        - user_scope: False
        - requires:
            - file: ollama_models_dir
        - watch:
            - file: ollama_config

Data is loaded from service_catalog.yaml and container_images.yaml internally.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

try:
    from salt.exceptions import SaltInvocationError
except ImportError:

    class SaltInvocationError(Exception):
        pass


try:
    from common import _parse_requires
except ImportError:

    def _parse_requires(requires):
        if not requires:
            return []
        parsed = []
        for r in requires:
            if isinstance(r, str) and ": " in r:
                typ, rid = r.split(": ", 1)
                parsed.append({typ: rid})
            elif isinstance(r, dict):
                parsed.append(r)
            else:
                parsed.append(r)
        return parsed


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


def _load_catalog() -> dict[str, Any]:
    return _load_yaml(_get_data_dir() / "service_catalog.yaml")


def _load_image_registry() -> dict[str, Any]:
    return _load_yaml(_get_data_dir() / "container_images.yaml")


def _tilde_expand(raw_path: str, home: str) -> str:
    if raw_path == "~":
        return home
    if isinstance(raw_path, str) and raw_path.startswith("~/"):
        return home + "/" + raw_path[2:]
    return raw_path


def managed(
    name: str,
    catalog_entry: dict[str, Any] | None = None,
    image_registry: dict[str, Any] | None = None,
    user_scope: bool = False,
    requires: list[str] | None = None,
    watch: list[str] | None = None,
    quadlet_unit_name: str | None = None,
    **kwargs: Any,
) -> dict[str, Any]:
    """Deploy a containerized service via Podman Quadlet.

    Returns a Salt state result dict.  When called from Salt, this is the
    `container.managed` state.  When called standalone, returns the state
    data structure for test inspection.
    """
    catalog = catalog_entry
    if catalog is None:
        all_catalog = _load_catalog()
        catalog = all_catalog.get(name)

    registry = image_registry
    if registry is None:
        registry = _load_image_registry()

    if not isinstance(catalog, dict):
        return {
            "name": name,
            "result": False,
            "changes": {},
            "comment": f"container.managed: {name} not found in service_catalog.yaml",
        }

    if not isinstance(registry, dict):
        return {
            "name": name,
            "result": False,
            "changes": {},
            "comment": "container.managed: container_images.yaml not loaded",
        }

    # Resolve host for home directory
    try:
        from common import get_host

        host = get_host()
        home = host.get("home", "/root")
        host_user = host.get("user", "root")
    except Exception:
        home = "/root"
        host_user = "root"

    quadlet_name = quadlet_unit_name if quadlet_unit_name is not None else name

    # Preconditions
    image_key = catalog.get("container_image")
    if not image_key or image_key not in registry:
        return {
            "name": name,
            "result": False,
            "changes": {},
            "comment": (
                f"container.managed({name}): image_key '{image_key}' "
                f"not found in container_images.yaml"
            ),
        }

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
        return {
            "name": name,
            "result": False,
            "changes": {},
            "comment": f"container.managed({name}): invalid digest '{digest}'",
        }
    if not scope_ok:
        return {
            "name": name,
            "result": False,
            "changes": {},
            "comment": (
                f"container.managed({name}): scope mismatch "
                f"(user_scope={user_scope}, catalog={catalog_scope})"
            ),
        }
    if not gpu_ok:
        return {
            "name": name,
            "result": False,
            "changes": {},
            "comment": f"container.managed({name}): gpu=amdgpu requires system scope",
        }

    # Resolve image reference
    if is_localhost:
        full_image = f"localhost/{img['image']}"
    else:
        full_image = f"{img_registry}/{img['image']}@{digest}"

    # Quadlet paths
    if user_scope:
        quadlet_path = f"{home}/.config/containers/systemd/{quadlet_name}.container"
        quadlet_source = f"salt://units/user/{quadlet_name}.container"
    else:
        quadlet_path = f"/etc/containers/systemd/{quadlet_name}.container"
        quadlet_source = f"salt://units/{quadlet_name}.container"

    # Expand bind mounts
    expanded_mounts = []
    for bm in catalog.get("bind_mounts", []):
        expanded_mounts.append(
            {
                "host": _tilde_expand(bm["host"], home),
                "container": bm["container"],
                "mode": bm["mode"],
            }
        )

    retry_attempts = 3
    retry_interval = 10

    try:
        from common import get_constants

        c = get_constants()
        retry_attempts = c["retry_attempts"]
        retry_interval = c["retry_interval"]
    except Exception:
        pass

    # Try to use Salt's __states__ if available
    try:
        _states = __states__  # type: ignore[name-defined]  # noqa: F821
    except NameError:
        _states = None

    # When Salt runtime is available, delegate to __states__
    if _states is not None:
        ret = {"name": name, "result": True, "changes": {}, "comment": ""}

        # Quadlet unit file
        fargs = {
            "name": quadlet_path,
            "source": quadlet_source,
            "template": "jinja",
            "mode": "0644",
            "makedirs": True,
            "context": {
                "catalog_entry": catalog,
                "image": full_image,
                "expanded_mounts": expanded_mounts,
                "user_scope": user_scope,
            },
        }
        if user_scope:
            fargs["user"] = host_user
            fargs["group"] = host_user
        ret["changes"][f"{name}_container"] = _states["file.managed"](**fargs)

        # Image pull
        if not is_localhost:
            pargs = {
                "name": f"podman pull {full_image}",
                "unless": f"podman image exists {full_image}",
                "retry": {"attempts": retry_attempts, "interval": retry_interval},
            }
            if user_scope:
                pargs["runas"] = host_user
            parsed_requires = [{"file": f"{name}_container"}]
            if requires:
                parsed_requires.extend(_parse_requires(requires))
            pargs["require"] = parsed_requires
            ret["changes"][f"{name}_image_pull"] = _states["cmd.run"](**pargs)

        return ret

    # Fallback: return structure for offline rendering (lint-jinja mock)
    # The mock renderer renders this as a YAML string

    result: dict[str, Any] = {"name": name, "result": True, "changes": {}, "comment": ""}
    result[f"{name}_container"] = {
        "file.managed": [
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
    }

    if not is_localhost:
        img_pull_data = [
            {"name": f"podman pull {full_image}"},
            {"unless": f"podman image exists {full_image}"},
            {"retry": {"attempts": retry_attempts, "interval": retry_interval}},
        ]
        parsed_requires = [{"file": f"{name}_container"}]
        if requires:
            parsed_requires.extend(_parse_requires(requires))
        img_pull_data.append({"require": parsed_requires})
        result[f"{name}_image_pull"] = {"cmd.run": img_pull_data}

    return result
