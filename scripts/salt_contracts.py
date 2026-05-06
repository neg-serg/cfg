#!/usr/bin/env python3
"""Explicit contract checks for Salt inventory data."""

from __future__ import annotations

import re
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = REPO_ROOT / "states" / "data"
UNITS_DIR = REPO_ROOT / "states" / "units"
CONFIGS_DIR = REPO_ROOT / "states" / "configs"
UNIT_SUFFIXES = (".service", ".timer", ".socket", ".path", ".container")
TEMPLATED_UNIT_SUFFIXES = tuple(f"{suffix}.j2" for suffix in UNIT_SUFFIXES)
KNOWN_NATIVE_USER_UNITS = {
    "gpg-agent.socket",
    "ssh-agent.socket",
    "systemd-tmpfiles-setup.service",
    "ydotool.service",
}
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
    try:
        with path.open() as fh:
            return yaml.safe_load(fh.read()) or {}
    except FileNotFoundError:
        return {}


def _load_feature_registry(repo_root: Path = REPO_ROOT):
    return load_yaml_file(repo_root / "states" / "data" / "feature_registry.yaml")


def _collect_allowed_user_service_features(repo_root: Path = REPO_ROOT) -> set[str]:
    FALLBACK_FEATURES = {"mail", "vdirsyncer", "mpd"}
    registry = _load_feature_registry(repo_root)
    user_services = registry.get("features", {}).get("user_services", {}).get("features", {})
    if isinstance(user_services, dict) and user_services:
        return {f for f, c in user_services.items() if isinstance(c, dict)}
    return FALLBACK_FEATURES


def _has_invalid_user_service_features(features, allowed: set[str] | None = None) -> bool:
    if allowed is None:
        allowed = _collect_allowed_user_service_features()
    if not isinstance(features, list):
        return True
    return any(
        not isinstance(feature, str) or feature not in allowed
        for feature in features
    )


def _user_service_group_entries(user_services: dict, group_name: str, errors: list[str]) -> list:
    entries = user_services.get(group_name, [])
    if isinstance(entries, list):
        return entries
    errors.append(f"user_services.yaml {group_name} must be a list, got {type(entries).__name__}")
    return []


def _collect_user_service_enable_targets(user_services: dict) -> set[str]:
    known = set(KNOWN_NATIVE_USER_UNITS)

    unit_files = user_services.get("unit_files", [])
    if not isinstance(unit_files, list):
        return known

    for entry in unit_files:
        if not isinstance(entry, dict):
            continue
        filename = entry.get("filename")
        if isinstance(filename, str) and filename:
            known.update(_unit_aliases(filename))

    return known


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


def check_managed_resources_identities_schema(repo_root: Path = REPO_ROOT) -> list[str]:
    managed_resources = load_yaml_file(repo_root / "states" / "data" / "managed_resources.yaml")
    errors = []
    required_fields = ["user", "group", "home"]

    for identity_name, config in managed_resources.get("managed_service_identities", {}).items():
        if not isinstance(config, dict):
            errors.append(f"managed_service_identities entry '{identity_name}' must be a mapping")
            continue
        for field in required_fields:
            value = config.get(field)
            if not isinstance(value, str) or not value:
                errors.append(
                    f"managed_service_identities entry '{identity_name}' missing valid {field}"
                )

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
    known_enable_targets = _collect_user_service_enable_targets(user_services)
    allowed_features = _collect_allowed_user_service_features(repo_root)

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
            if _has_invalid_user_service_features(features, allowed_features):
                errors.append(f"unit_files entry has invalid features: {entry!r}")

    for group_name in ("enable_services", "enable_now_timers"):
        for entry in _user_service_group_entries(user_services, group_name, errors):
            if not isinstance(entry, dict):
                errors.append(f"{group_name} entry must be mapping, got {type(entry).__name__}")
                continue

            name = entry.get("name")
            if not isinstance(name, str) or not name:
                errors.append(f"{group_name} entry missing valid name: {entry!r}")
            elif (
                "features" not in entry
                or not _has_invalid_user_service_features(entry.get("features"), allowed_features)
            ) and not _is_known_service_target(name, known_enable_targets):
                errors.append(f"{group_name} entry references unknown user unit '{name}'")

            if "features" in entry:
                features = entry.get("features")
                if _has_invalid_user_service_features(features, allowed_features):
                    errors.append(f"{group_name} entry has invalid features: {entry!r}")

    return errors


# --- Feature registry contracts ---


def _collect_feature_names(registry: dict, prefix: str = "") -> set[str]:
    features = set()
    for name, config in registry.get("features", {}).items():
        full_name = f"{prefix}{name}"
        if isinstance(config, dict) and "features" in config:
            features.update(_collect_feature_names(config, f"{full_name}."))
        else:
            features.add(full_name)
    return features


def _collect_hosts_features(hosts_data: dict) -> set[str]:
    defaults = hosts_data.get("defaults", {}).get("features", {})
    if not isinstance(defaults, dict):
        return set()
    return _collect_feature_names({"features": defaults})


def _collect_nested_feature_names(features: dict, prefix: str = "") -> set[str]:
    names = set()
    for key, value in features.items():
        full_name = f"{prefix}.{key}" if prefix else key
        if isinstance(value, dict) and any(
            isinstance(v, bool) for v in value.values()
        ):
            names.update(_collect_nested_feature_names(value, full_name))
        elif isinstance(value, bool):
            names.add(full_name)
    return names


def check_features_against_registry(repo_root: Path = REPO_ROOT) -> list[str]:
    registry = _load_feature_registry(repo_root)
    hosts_data = load_yaml_file(repo_root / "states" / "data" / "hosts.yaml")
    errors = []

    registry_features = _collect_feature_names(registry)
    if not registry_features:
        return []

    hosts_features = _collect_nested_feature_names(
        hosts_data.get("defaults", {}).get("features", {})
    )

    for feature in hosts_features:
        if feature not in registry_features:
            errors.append(
                f"hosts.yaml feature '{feature}' not declared in feature_registry.yaml"
            )

    for hostname, config in hosts_data.get("hosts", {}).items():
        if not isinstance(config, dict):
            continue
        host_features = _collect_nested_feature_names(config.get("features", {}))
        for feature in host_features:
            if feature not in registry_features:
                errors.append(
                    f"hosts.yaml host '{hostname}' feature '{feature}' not in feature_registry"
                )

    return errors


def check_feature_matrix_against_registry(repo_root: Path = REPO_ROOT) -> list[str]:
    registry = _load_feature_registry(repo_root)
    feature_matrix = load_yaml_file(repo_root / "states" / "data" / "feature_matrix.yaml")
    errors = []

    registry_features = _collect_feature_names(registry)
    if not registry_features:
        return []

    if not isinstance(feature_matrix, list):
        if feature_matrix == {}:
            return []
        return ["feature_matrix.yaml must be a list"]

    for entry in feature_matrix:
        if not isinstance(entry, dict):
            continue
        name = entry.get("name", "<unknown>")
        overrides = entry.get("overrides", {}).get("features", {})
        matrix_features = _collect_nested_feature_names(overrides)
        for feature in matrix_features:
            if feature not in registry_features:
                errors.append(
                    f"feature_matrix.yaml '{name}' references unknown feature '{feature}'"
                )

    return errors


# --- Catalog packages cross-reference ---


def check_catalog_packages_in_packages_yaml(repo_root: Path = REPO_ROOT) -> list[str]:
    catalog = load_yaml_file(repo_root / "states" / "data" / "service_catalog.yaml")
    errors = []

    all_packages = set()

    # Collect from packages.yaml (all categories including aur)
    packages_data = load_yaml_file(repo_root / "states" / "data" / "packages.yaml")
    if isinstance(packages_data, dict):
        for category, pkgs in packages_data.items():
            if not isinstance(pkgs, list):
                continue
            for entry in pkgs:
                name = str(entry).split("#")[0].strip()
                if name:
                    all_packages.add(name)

    if not all_packages:
        return []

    # Collect from installers.yaml (pip, cargo, go, curl_bin, etc.)
    installers = load_yaml_file(repo_root / "states" / "data" / "installers.yaml")
    if isinstance(installers, dict):
        for macro_type, tools in installers.items():
            if not isinstance(tools, dict):
                continue
            for name in tools:
                all_packages.add(name)

    # Collect from custom_pkgs.yaml (custom PKGBUILDs)
    custom_pkgs = load_yaml_file(repo_root / "states" / "data" / "custom_pkgs.yaml")
    if isinstance(custom_pkgs, dict):
        pkgbuild = custom_pkgs.get("pkgbuild", {})
        if isinstance(pkgbuild, dict):
            for name in pkgbuild:
                all_packages.add(name)

    for service_name, config in catalog.items():
        if not isinstance(config, dict):
            continue
        packages = config.get("packages")
        if not isinstance(packages, str) or not packages.strip():
            continue
        for pkg in packages.split():
            if pkg not in all_packages:
                errors.append(
                    f"Service catalog '{service_name}' references package '{pkg}'"
                    " not found in packages.yaml, installers.yaml, or custom_pkgs.yaml"
                )

    return errors


# --- Config template references ---


def check_services_config_templates(repo_root: Path = REPO_ROOT) -> list[str]:
    services = load_yaml_file(repo_root / "states" / "data" / "services.yaml")
    if not isinstance(services, dict) or not services:
        return []
    errors = []

    for section in ("simple", "complex", "network", "dns"):
        entries = services.get(section, {})
        if not isinstance(entries, dict):
            continue
        for name, config in entries.items():
            if not isinstance(config, dict):
                continue
            templates = config.get("config_templates", [])
            if not isinstance(templates, list):
                continue
            for tmpl in templates:
                if not isinstance(tmpl, dict):
                    continue
                source = tmpl.get("source", "")
                if not isinstance(source, str) or not source:
                    continue
                if source.startswith("salt://"):
                    rel_path = source.removeprefix("salt://")
                    config_path = repo_root / "states" / rel_path
                    if not config_path.is_file():
                        errors.append(
                            f"services.yaml {section}.{name} config_template source"
                            f" '{source}' not found at '{rel_path}'"
                        )

    return errors


# --- Aggregate ---


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
    errors.extend(check_managed_resources_identities_schema(repo_root))
    errors.extend(check_user_services_schema(repo_root))
    errors.extend(check_user_service_unit_files(repo_root))
    errors.extend(check_features_against_registry(repo_root))
    errors.extend(check_feature_matrix_against_registry(repo_root))
    errors.extend(check_catalog_packages_in_packages_yaml(repo_root))
    errors.extend(check_services_config_templates(repo_root))
    return errors


def print_contract_errors(errors: list[str]) -> int:
    for error in errors:
        print(f"\033[31mContract: {error}\033[0m")
    return len(errors)


def main() -> int:
    return print_contract_errors(check_service_inventory_contracts())


if __name__ == "__main__":
    raise SystemExit(main())
