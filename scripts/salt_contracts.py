#!/usr/bin/env python3
"""Explicit contract checks for Salt inventory data."""

from __future__ import annotations

import re
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = REPO_ROOT / "states" / "data"
UNITS_DIR = REPO_ROOT / "states" / "units"
UNIT_SUFFIXES = (".service", ".timer", ".socket", ".path", ".container")
TEMPLATED_UNIT_SUFFIXES = tuple(f"{suffix}.j2" for suffix in UNIT_SUFFIXES)
USER_SERVICE_ALLOWED_FEATURES = {"mail", "vdirsyncer", "mpd"}
KNOWN_NATIVE_SERVICES = {
    "NetworkManager",
    "NetworkManager.service",
    "avahi-daemon",
    "avahi-daemon.service",
    "cronie",
    "cronie.service",
    "greetd",
    "greetd.service",
    "gpg-agent.socket",
    "mpd",
    "mpd.service",
    "sshd",
    "sshd.service",
    "ssh-agent.socket",
    "systemd-tmpfiles-setup.service",
    "tailscaled",
    "tailscaled.service",
    "ydotool.service",
}


def load_yaml_file(path: Path):
    with path.open() as fh:
        return yaml.safe_load(fh.read()) or {}


def _has_invalid_user_service_features(features) -> bool:
    if not isinstance(features, list):
        return True
    return any(
        not isinstance(feature, str) or feature not in USER_SERVICE_ALLOWED_FEATURES
        for feature in features
    )


def _user_service_group_entries(user_services: dict, group_name: str, errors: list[str]) -> list:
    entries = user_services.get(group_name, [])
    if isinstance(entries, list):
        return entries
    errors.append(f"user_services.yaml {group_name} must be a list, got {type(entries).__name__}")
    return []


def _unit_aliases(unit_name: str) -> set[str]:
    aliases = {unit_name}
    if any(unit_name.endswith(suffix) for suffix in UNIT_SUFFIXES):
        aliases.add(unit_name.rsplit(".", 1)[0])
    else:
        aliases.add(f"{unit_name}.service")
    return aliases


def _collect_known_units(repo_root: Path) -> set[str]:
    known = set()
    units_dir = repo_root / "states" / "units"
    if not units_dir.is_dir():
        return known

    for path in units_dir.rglob("*"):
        if not path.is_file():
            continue
        name = path.name
        for suffix in UNIT_SUFFIXES:
            if name.endswith(suffix):
                known.add(name)
                known.add(name[: -len(suffix)])
        for suffix in TEMPLATED_UNIT_SUFFIXES:
            if name.endswith(suffix):
                unit_name = name[: -len(".j2")]
                known.add(unit_name)
                known.add(unit_name[: -len(suffix.removesuffix(".j2"))])
    return known


def _collect_container_service_deployments(repo_root: Path) -> dict[str, str]:
    deployments = {}
    pattern = re.compile(
        r"container_service\(\s*'(?P<call_name>[^']+)'\s*,\s*catalog\.(?P<catalog_name>[A-Za-z0-9_]+)"
        r"(?P<body>.*?)\)\s*}}",
        re.DOTALL,
    )
    quadlet_pattern = re.compile(r"quadlet_unit_name\s*=\s*'(?P<quadlet_name>[^']+)'")

    for sls_path in (repo_root / "states").glob("*.sls"):
        source = sls_path.read_text()
        for match in pattern.finditer(source):
            quadlet_match = quadlet_pattern.search(match.group("body"))
            deployments[match.group("catalog_name")] = (
                quadlet_match.group("quadlet_name") if quadlet_match else match.group("call_name")
            )

    return deployments


def _collect_catalog_service_names(repo_root: Path) -> set[str]:
    known = set()
    catalog = load_yaml_file(repo_root / "states" / "data" / "service_catalog.yaml")
    for name, config in catalog.items():
        if isinstance(config, dict):
            known.add(name)
    return known


def _collect_catalog_service_targets(repo_root: Path) -> set[str]:
    known = set()
    catalog = load_yaml_file(repo_root / "states" / "data" / "service_catalog.yaml")
    for name, config in catalog.items():
        if not isinstance(config, dict):
            continue
        known.add(name)
        unit = config.get("unit")
        if isinstance(unit, str) and unit:
            known.update(_unit_aliases(unit))
    return known


def _collect_service_domains_from_services_yaml(repo_root: Path) -> set[str]:
    known = set()
    services = load_yaml_file(repo_root / "states" / "data" / "services.yaml")
    for section in ("simple", "complex", "network", "dns"):
        entries = services.get(section, {})
        if not isinstance(entries, dict):
            continue
        for name, config in entries.items():
            known.add(name)
            if not isinstance(config, dict):
                continue
            service = config.get("service")
            if isinstance(service, str) and service:
                known.update(_unit_aliases(service))
            manual_start = config.get("manual_start")
            if isinstance(manual_start, dict):
                manual_service = manual_start.get("service")
                if isinstance(manual_service, str) and manual_service:
                    known.update(_unit_aliases(manual_service))
            ensure_running = config.get("ensure_running")
            if isinstance(ensure_running, dict):
                running_service = ensure_running.get("service")
                if isinstance(running_service, str) and running_service:
                    known.update(_unit_aliases(running_service))

    return known


def _is_known_service_target(target: str, known_targets: set[str]) -> bool:
    return not _unit_aliases(target).isdisjoint(known_targets)


def _collect_allowed_service_targets(repo_root: Path) -> set[str]:
    known = set(KNOWN_NATIVE_SERVICES)
    known.update(_collect_catalog_service_targets(repo_root))
    known.update(_collect_known_units(repo_root))
    return known


def _collect_known_service_domains(repo_root: Path) -> set[str]:
    known = set(KNOWN_NATIVE_SERVICES)
    known.update(_collect_catalog_service_names(repo_root))
    known.update(_collect_service_domains_from_services_yaml(repo_root))
    known.update(_collect_known_units(repo_root))
    return known


def _collect_managed_resource_domains(repo_root: Path) -> set[str]:
    known = set(KNOWN_NATIVE_SERVICES)
    known.update(_collect_catalog_service_names(repo_root))
    known.update(_collect_service_domains_from_services_yaml(repo_root))

    return known


def check_service_catalog_container_images(repo_root: Path = REPO_ROOT) -> list[str]:
    catalog = load_yaml_file(repo_root / "states" / "data" / "service_catalog.yaml")
    container_images = load_yaml_file(repo_root / "states" / "data" / "container_images.yaml")
    errors = []

    for service_name, config in catalog.items():
        if not isinstance(config, dict):
            continue
        image_key = config.get("container_image")
        if image_key and image_key not in container_images:
            errors.append(
                f"Service catalog '{service_name}' references missing container image '{image_key}'"
            )
        if image_key and not any(
            field in config for field in ("containerized", "bind_mounts", "env_file", "gpu")
        ):
            errors.append(
                f"Service catalog '{service_name}' sets container_image but lacks "
                "repo container-service fields"
            )

    return errors


def check_service_catalog_packages(repo_root: Path = REPO_ROOT) -> list[str]:
    catalog = load_yaml_file(repo_root / "states" / "data" / "service_catalog.yaml")
    errors = []

    for service_name, config in catalog.items():
        if not isinstance(config, dict):
            continue
        packages = config.get("packages")
        if packages is None:
            continue
        if not isinstance(packages, str) or not packages.strip():
            errors.append(
                f"Service catalog '{service_name}' has invalid packages value "
                f"{packages!r} (expected non-empty string or null)"
            )

    return errors


def check_service_catalog_units(repo_root: Path = REPO_ROOT) -> list[str]:
    catalog = load_yaml_file(repo_root / "states" / "data" / "service_catalog.yaml")
    known_units = _collect_known_units(repo_root)
    known_services = set(KNOWN_NATIVE_SERVICES)
    known_services.update(_collect_service_domains_from_services_yaml(repo_root))
    container_deployments = _collect_container_service_deployments(repo_root)
    errors = []

    for service_name, config in catalog.items():
        if not isinstance(config, dict):
            continue
        unit = config.get("unit")
        if not isinstance(unit, str) or not unit:
            continue
        containerized = bool(config.get("container_image"))
        aliases = _unit_aliases(unit)
        if containerized and service_name in container_deployments:
            quadlet_name = container_deployments[service_name]
            scope_dir = "user" if config.get("scope") == "user" else ""
            quadlet_path = repo_root / "states" / "units"
            if scope_dir:
                quadlet_path = quadlet_path / scope_dir
            if (quadlet_path / f"{quadlet_name}.container").is_file():
                deployed_unit = quadlet_name.removesuffix("-container")
                deployed_aliases = _unit_aliases(deployed_unit)
                if not aliases.isdisjoint(deployed_aliases):
                    continue
                if aliases.isdisjoint(known_units) and aliases.isdisjoint(known_services):
                    errors.append(
                        f"Service catalog '{service_name}' references unknown unit '{unit}'"
                    )
                else:
                    errors.append(
                        f"Service catalog '{service_name}' unit '{unit}' does not match "
                        f"deployed container service '{deployed_unit}'"
                    )
                continue

        if aliases.isdisjoint(known_units) and aliases.isdisjoint(known_services):
            errors.append(f"Service catalog '{service_name}' references unknown unit '{unit}'")

    return errors


def check_managed_resource_services(repo_root: Path = REPO_ROOT) -> list[str]:
    managed_resources = load_yaml_file(repo_root / "states" / "data" / "managed_resources.yaml")
    known_services = _collect_managed_resource_domains(repo_root)
    errors = []

    for identity_name, config in managed_resources.get("managed_service_identities", {}).items():
        if not isinstance(config, dict):
            continue
        if identity_name not in known_services:
            errors.append(
                "Managed resource identity "
                f"'{identity_name}' references unknown service '{identity_name}'"
            )

    for resource_name, config in managed_resources.get("managed_service_paths", {}).items():
        if not isinstance(config, dict):
            continue
        service = config.get("service")
        if isinstance(service, str) and service and service not in known_services:
            errors.append(
                f"Managed resource path '{resource_name}' references unknown service '{service}'"
            )

    return errors


def check_managed_resources_schema(repo_root: Path = REPO_ROOT) -> list[str]:
    managed_resources = load_yaml_file(repo_root / "states" / "data" / "managed_resources.yaml")
    errors = []

    for resource_name, config in managed_resources.get("managed_service_paths", {}).items():
        if not isinstance(config, dict):
            continue
        path_type = config.get("type")
        if not isinstance(path_type, str) or not path_type:
            errors.append(f"managed_service_paths entry '{resource_name}' missing valid type")
        mode = config.get("mode")
        if not isinstance(mode, str) or not mode:
            errors.append(f"managed_service_paths entry '{resource_name}' missing valid mode")

    return errors


def check_user_service_unit_files(repo_root: Path = REPO_ROOT) -> list[str]:
    user_services = load_yaml_file(repo_root / "states" / "data" / "user_services.yaml")
    errors = []

    for entry in user_services.get("unit_files", []):
        if not isinstance(entry, dict):
            continue
        filename = entry.get("filename")
        if not isinstance(filename, str) or not filename:
            continue
        user_unit_path = repo_root / "states" / "units" / "user" / filename
        if not user_unit_path.is_file():
            errors.append(f"User service unit '{filename}' does not exist under states/units/user")

    return errors


def check_user_services_schema(repo_root: Path = REPO_ROOT) -> list[str]:
    user_services = load_yaml_file(repo_root / "states" / "data" / "user_services.yaml")
    if not isinstance(user_services, dict):
        return [f"user_services.yaml must be a mapping, got {type(user_services).__name__}"]

    errors = []
    seen_ids = set()

    for entry in _user_service_group_entries(user_services, "unit_files", errors):
        if not isinstance(entry, dict):
            errors.append(f"unit_files entry must be mapping, got {type(entry).__name__}")
            continue

        entry_id = entry.get("id")
        if not isinstance(entry_id, str) or not entry_id:
            errors.append(f"unit_files entry missing valid id: {entry!r}")
        elif entry_id in seen_ids:
            errors.append(f"duplicate unit_files id: {entry_id}")
        else:
            seen_ids.add(entry_id)

        filename = entry.get("filename")
        if not isinstance(filename, str) or not filename:
            errors.append(f"unit_files entry missing valid filename: {entry!r}")

        if "features" in entry:
            features = entry.get("features")
            if _has_invalid_user_service_features(features):
                errors.append(f"unit_files entry has invalid features: {entry!r}")

    for group_name in ("enable_services", "enable_now_timers"):
        for entry in _user_service_group_entries(user_services, group_name, errors):
            if not isinstance(entry, dict):
                errors.append(f"{group_name} entry must be mapping, got {type(entry).__name__}")
                continue

            name = entry.get("name")
            if not isinstance(name, str) or not name:
                errors.append(f"{group_name} entry missing valid name: {entry!r}")

            if "features" in entry:
                features = entry.get("features")
                if _has_invalid_user_service_features(features):
                    errors.append(f"{group_name} entry has invalid features: {entry!r}")

    return errors


def check_services_yaml_service_references(repo_root: Path = REPO_ROOT) -> list[str]:
    services = load_yaml_file(repo_root / "states" / "data" / "services.yaml")
    known_targets = _collect_allowed_service_targets(repo_root)
    errors = []

    for section in ("simple", "complex", "network", "dns"):
        entries = services.get(section, {})
        if not isinstance(entries, dict):
            continue
        for name, config in entries.items():
            if not isinstance(config, dict):
                continue

            references = [("service", config.get("service"))]

            manual_start = config.get("manual_start")
            if isinstance(manual_start, dict):
                references.append(("manual_start.service", manual_start.get("service")))

            ensure_running = config.get("ensure_running")
            if isinstance(ensure_running, dict):
                references.append(("ensure_running.service", ensure_running.get("service")))

            for field_path, target in references:
                if not isinstance(target, str) or not target:
                    continue
                if not _is_known_service_target(target, known_targets):
                    errors.append(
                        f"services.yaml {section}.{name} {field_path} references unknown "
                        f"service '{target}'"
                    )

    return errors


def check_service_inventory_contracts(repo_root: Path = REPO_ROOT) -> list[str]:
    errors = []
    errors.extend(check_service_catalog_packages(repo_root))
    errors.extend(check_service_catalog_container_images(repo_root))
    errors.extend(check_service_catalog_units(repo_root))
    errors.extend(check_services_yaml_service_references(repo_root))
    errors.extend(check_managed_resource_services(repo_root))
    errors.extend(check_managed_resources_schema(repo_root))
    errors.extend(check_user_services_schema(repo_root))
    errors.extend(check_user_service_unit_files(repo_root))
    return errors


def print_contract_errors(errors: list[str]) -> int:
    for error in errors:
        print(f"\033[31mContract: {error}\033[0m")
    return len(errors)


def main() -> int:
    return print_contract_errors(check_service_inventory_contracts())


if __name__ == "__main__":
    raise SystemExit(main())
