#!/usr/bin/env python3
"""Explicit contract checks for Salt inventory data."""

from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))
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
    # Match both old container_service(...) and new salt['container.deploy'](...)
    pattern = re.compile(
        r"(?:container_service|salt\['container\.deploy'\])\("
        r"\s*'(?P<call_name>[^']+)'\s*,\s*catalog\.(?P<catalog_name>[A-Za-z0-9_]+)"
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


def check_container_images_liveness(repo_root: Path = REPO_ROOT) -> list[str]:
    catalog = load_yaml_file(repo_root / "states" / "data" / "service_catalog.yaml")
    images = load_yaml_file(repo_root / "states" / "data" / "container_images.yaml")
    errors = []

    if not isinstance(images, dict):
        return []

    referenced_images = set()
    for service_name, config in catalog.items():
        if not isinstance(config, dict):
            continue
        image_key = config.get("container_image")
        if isinstance(image_key, str) and image_key:
            referenced_images.add(image_key)

    for image_name in images:
        if image_name == "schema_version":
            continue
        if image_name not in referenced_images:
            errors.append(
                f"Container image '{image_name}' is not referenced by any service in"
                " service_catalog.yaml"
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


# --- Data file liveness ---

_CORE_DATA_FILES = {
    "feature_matrix.yaml",
    "feature_registry.yaml",
    "hosts.yaml",
}

DATA_IMPORT_RE = re.compile(r"\{%-?\s*import_yaml\s+['\"](data/[^'\"]+)['\"]\s+as\s+\w+")
CP_FILE_DATA_RE = re.compile(r"salt\.cp\.get_file_str\s*\(\s*['\"]salt://(data/[^'\"]+)['\"]")

J2_DATA_IMPORT_RE = re.compile(r"\{%-?\s*import_yaml\s+['\"]([^'\"]+)['\"]\s+as\s+\w+")


def _collect_data_consumers(repo_root: Path = REPO_ROOT) -> dict[str, set[str]]:
    usage: dict[str, set[str]] = {}
    states_dir = repo_root / "states"

    for sls_path in states_dir.rglob("*.sls"):
        try:
            src = sls_path.read_text()
        except (OSError, IOError):
            continue
        for match in DATA_IMPORT_RE.finditer(src):
            data_rel = match.group(1)
            data_basename = data_rel.split("/")[-1]
            usage.setdefault(data_basename, set()).add(
                str(sls_path.relative_to(repo_root))
            )
        for match in CP_FILE_DATA_RE.finditer(src):
            data_rel = match.group(1)
            data_basename = data_rel.split("/")[-1]
            usage.setdefault(data_basename, set()).add(
                str(sls_path.relative_to(repo_root))
            )

    for config_path in (states_dir / "configs").rglob("*.j2"):
        try:
            src = config_path.read_text()
        except (OSError, IOError):
            continue
        for match in J2_DATA_IMPORT_RE.finditer(src):
            data_rel = match.group(1)
            if data_rel.startswith("data/"):
                data_basename = data_rel.split("/")[-1]
                usage.setdefault(data_basename, set()).add(
                    f"configs/{config_path.relative_to(states_dir / 'configs')}"
                )

    for jinja_path in states_dir.glob("*.jinja"):
        try:
            src = jinja_path.read_text()
        except (OSError, IOError):
            continue
        for match in J2_DATA_IMPORT_RE.finditer(src):
            data_rel = match.group(1)
            if data_rel.startswith("data/"):
                data_basename = data_rel.split("/")[-1]
                usage.setdefault(data_basename, set()).add(
                    str(jinja_path.relative_to(repo_root))
                )

    return usage


# --- Monitored services cross-reference ---


def check_monitored_services_references(repo_root: Path = REPO_ROOT) -> list[str]:
    monitored = load_yaml_file(repo_root / "states" / "data" / "monitored_services.yaml")
    if not isinstance(monitored, dict):
        return []

    known = set(KNOWN_NATIVE_SERVICES)
    known.update(_collect_catalog_service_targets(repo_root))
    known.update(_collect_service_domains_from_services_yaml(repo_root))
    known.update(_collect_known_units(repo_root))

    states_dir = repo_root / "states"
    for sls_path in states_dir.glob("*.sls"):
        known.add(sls_path.stem)
        known.add(sls_path.stem.replace("_", "-"))

    errors = []

    for scope in ("system_services", "user_services", "user_timers"):
        entries = monitored.get(scope, [])
        if not isinstance(entries, list):
            continue
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            name = entry.get("name", "")
            if not isinstance(name, str) or not name:
                continue
            is_optional = entry.get("optional", False)
            normalized = name.replace("-", "_")
            if not is_optional and name not in known and normalized not in known:
                errors.append(
                    f"monitored_services.yaml {scope}.{name}: unknown service"
                )

    return errors


# --- Drift inventory cross-reference ---


def check_drift_inventory_units(repo_root: Path = REPO_ROOT) -> list[str]:
    drift = load_yaml_file(repo_root / "scripts" / "drift_inventory.yaml")
    if not isinstance(drift, dict):
        return []

    known = set(KNOWN_NATIVE_SERVICES)
    known.update(_collect_catalog_service_targets(repo_root))
    known.update(_collect_service_domains_from_services_yaml(repo_root))
    known.update(_collect_known_units(repo_root))
    known.update({
        "salt-monitor.service",
        "salt-monitor-watchdog.timer",
    })

    errors = []

    for scope in ("system_units", "user_units"):
        entries = drift.get(scope, [])
        if not isinstance(entries, list):
            continue
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            name = entry.get("name", "")
            if not isinstance(name, str) or not name:
                continue
            base = name.rsplit(".", 1)[0] if "." in name else name
            if name not in known and base not in known:
                errors.append(
                    f"drift_inventory.yaml {scope}.{name}: unknown unit"
                )

    return errors


# --- Feature defaults sync ---


def check_feature_defaults_sync(repo_root: Path = REPO_ROOT) -> list[str]:
    registry = _load_feature_registry(repo_root)
    hosts_data = load_yaml_file(repo_root / "states" / "data" / "hosts.yaml")

    reg_features = _collect_registry_defaults(registry)
    if not reg_features:
        return []

    hosts_defaults_full = {}
    defaults_features = hosts_data.get("defaults", {}).get("features", {})
    _flatten_defaults(defaults_features, "", hosts_defaults_full)

    errors = []
    for feature, reg_default in sorted(reg_features.items()):
        hosts_default = hosts_defaults_full.get(feature)
        if hosts_default is None:
            continue
        if hosts_default != reg_default:
            errors.append(
                f"Feature '{feature}' default mismatch:"
                f" hosts.yaml={hosts_default}, registry={reg_default}"
            )

    return errors


def _collect_registry_defaults(registry, prefix=""):
    result = {}
    for name, config in registry.get("features", {}).items():
        full = f"{prefix}.{name}" if prefix else name
        if isinstance(config, dict) and "features" in config:
            result.update(_collect_registry_defaults(config, full))
        elif isinstance(config, dict) and "default" in config:
            result[full] = config["default"]
    return result


def _flatten_defaults(features, prefix, result):
    for key, value in features.items():
        full = f"{prefix}.{key}" if prefix else key
        if isinstance(value, dict) and any(isinstance(v, bool) for v in value.values()):
            _flatten_defaults(value, full, result)
        elif isinstance(value, bool):
            result[full] = value


def check_data_file_liveness(repo_root: Path = REPO_ROOT) -> list[str]:
    data_dir = repo_root / "states" / "data"
    if not data_dir.is_dir():
        return []

    consumers = _collect_data_consumers(repo_root)
    if not consumers:
        return []

    errors = []

    for data_path in sorted(data_dir.glob("*.yaml")):
        basename = data_path.name
        if basename in _CORE_DATA_FILES:
            continue
        if basename not in consumers:
            errors.append(
                f"Data file 'states/data/{basename}' has no SLS or config consumers"
            )

    return errors


# --- Services.yaml feature gate validation ---


def check_services_feature_gates(repo_root: Path = REPO_ROOT) -> list[str]:
    services = load_yaml_file(repo_root / "states" / "data" / "services.yaml")
    hosts_data = load_yaml_file(repo_root / "states" / "data" / "hosts.yaml")
    errors = []

    if not isinstance(services, dict) or not isinstance(hosts_data, dict):
        return []

    hosts_features = _collect_nested_feature_names(
        hosts_data.get("defaults", {}).get("features", {})
    )

    if not hosts_features:
        return []

    for section, feature_ns in [("complex", "services"), ("network", "network"), ("dns", "dns")]:
        entries = services.get(section, {})
        if not isinstance(entries, dict):
            continue
        for name in entries:
            gate = f"{feature_ns}.{name}"
            if gate not in hosts_features:
                errors.append(
                    f"services.yaml {section}.{name} is gated by '{gate}'"
                    f" but that feature is not declared in hosts.yaml defaults"
                )

    return errors


# --- Data import existence (reverse liveness) ---


def check_data_imports_exist(repo_root: Path = REPO_ROOT) -> list[str]:
    states_dir = repo_root / "states"
    errors = []

    if not states_dir.is_dir():
        return []

    CP_FILE_DATA_RE = re.compile(r"salt\.cp\.get_file_str\s*\(\s*['\"]salt://(data/[^'\"]+)['\"]")

    for sls_path in sorted(states_dir.rglob("*.sls")):
        try:
            src = sls_path.read_text()
        except (OSError, IOError):
            continue

        for match in DATA_IMPORT_RE.finditer(src):
            data_rel = match.group(1)
            full_path = states_dir / data_rel
            if not full_path.is_file():
                errors.append(
                    f"{sls_path.relative_to(repo_root)} import_yaml"
                    f" '{data_rel}' but file does not exist"
                )

        for match in CP_FILE_DATA_RE.finditer(src):
            data_rel = match.group(1)
            full_path = states_dir / data_rel
            if not full_path.is_file():
                errors.append(
                    f"{sls_path.relative_to(repo_root)} cp.get_file_str"
                    f" '{data_rel}' but file does not exist"
                )

    for jinja_path in sorted(states_dir.rglob("*.jinja")):
        try:
            src = jinja_path.read_text()
        except (OSError, IOError):
            continue

        for match in DATA_IMPORT_RE.finditer(src):
            data_rel = match.group(1)
            full_path = states_dir / data_rel
            if not full_path.is_file():
                errors.append(
                    f"{jinja_path.relative_to(repo_root)} imports"
                    f" '{data_rel}' but file does not exist"
                )

    return errors


# --- SLS feature gate validation against registry ---


_SLS_FEATURE_GATE_RE = re.compile(r"\bhost\.features\.([a-zA-Z_]\w*(?:\.[a-zA-Z_]\w*)*)")


def check_sls_feature_gates_against_registry(repo_root: Path = REPO_ROOT) -> list[str]:
    registry = _load_feature_registry(repo_root)
    registry_features = _collect_feature_names(registry)
    if not registry_features:
        return []

    # Groups are namespace-only, not features themselves
    registry_groups = {
        name for name, config in registry.get("features", {}).items()
        if isinstance(config, dict) and "features" in config
    }

    errors = []
    states_dir = repo_root / "states"

    for sls_path in sorted(states_dir.rglob("*.sls")):
        try:
            src = sls_path.read_text()
        except (OSError, IOError):
            continue

        rel = sls_path.relative_to(repo_root)
        gates_in_file = set()
        for match in _SLS_FEATURE_GATE_RE.finditer(src):
            gate = match.group(1)
            if gate.endswith(".get") or gate == "get":
                continue
            if gate in registry_groups:
                continue
            gates_in_file.add(gate)

        for gate in sorted(gates_in_file):
            if gate not in registry_features:
                errors.append(
                    f"{rel} references host.features.{gate}"
                    f" but '{gate}' is not declared in feature_registry.yaml"
                )

    return errors


# --- Registry gates → SLS existence ---


def check_registry_gates_resolve_to_states(repo_root: Path = REPO_ROOT) -> list[str]:
    registry = _load_feature_registry(repo_root)
    errors = []

    states_dir = repo_root / "states"
    existing_sls = {
        p.stem for p in states_dir.glob("*.sls")
        if not p.name.startswith("_") and not p.name.startswith("group.")
    }
    for p in (states_dir / "group").glob("*.sls"):
        if p.is_file():
            existing_sls.add(f"group.{p.stem}")

    def check_gates(features):
        for name, config in features.items():
            if isinstance(config, dict) and "features" in config:
                check_gates(config["features"])
            elif isinstance(config, dict):
                gates = config.get("gates", [])
                if not isinstance(gates, list):
                    continue
                for gate in gates:
                    if gate not in existing_sls:
                        errors.append(
                            f"feature_registry.yaml '{name}' gates '{gate}'"
                            f" but '{gate}.sls' does not exist in states/"
                        )

    check_gates(registry.get("features", {}))

    return errors


# --- SLS asset references existence ---


_SLS_ASSET_REF_RE = re.compile(r"salt://((?:configs|scripts|units)/[^\s'\"}]+)")


def check_sls_config_refs_exist(repo_root: Path = REPO_ROOT) -> list[str]:
    states_dir = repo_root / "states"
    errors = []

    for sls_path in sorted(states_dir.rglob("*.sls")):
        try:
            src = sls_path.read_text()
        except (OSError, IOError):
            continue

        for match in _SLS_ASSET_REF_RE.finditer(src):
            asset_rel = match.group(1)
            if "{{" in asset_rel or "{%" in asset_rel:
                continue
            # Check states/ dir first (primary file_root), then repo root
            full_path = states_dir / asset_rel
            root_path = repo_root / asset_rel
            if not full_path.is_file() and not root_path.is_file():
                errors.append(
                    f"{sls_path.relative_to(repo_root)} references"
                    f" 'salt://{asset_rel}' but file exists in neither"
                    f" states/ nor repo root"
                )

    return errors


# --- SLS include statement validation ---


_SLS_INCLUDE_RE = re.compile(r"^\s*-\s+(\S+)\s*$", re.MULTILINE)


def check_sls_includes_exist(repo_root: Path = REPO_ROOT) -> list[str]:
    states_dir = repo_root / "states"
    errors = []
    existing = {p.stem for p in states_dir.glob("*.sls")}
    existing.update(
        str(p.relative_to(states_dir)).replace("/", ".").removesuffix(".sls")
        for p in states_dir.rglob("*.sls")
        if "/" in str(p.relative_to(states_dir))
    )

    for sls_path in sorted(states_dir.rglob("*.sls")):
        try:
            src = sls_path.read_text()
        except (OSError, IOError):
            continue

        in_include = False
        for line in src.splitlines():
            stripped = line.strip()
            if stripped == "include:":
                in_include = True
                continue
            if in_include and stripped.startswith("- "):
                name = stripped[2:].strip()
                if name not in existing:
                    errors.append(
                        f"{sls_path.relative_to(repo_root)} includes"
                        f" '{name}' but '{name}.sls' not found"
                    )
                continue
            if in_include and not stripped.startswith("-") and stripped:
                in_include = False

    return errors


# --- Macro file syntax validation ---


def check_macro_files_syntax(repo_root: Path = REPO_ROOT) -> list[str]:
    states_dir = repo_root / "states"
    errors = []

    for macro_path in sorted(states_dir.glob("_macros_*.jinja")):
        try:
            src = macro_path.read_text()
        except (OSError, IOError):
            errors.append(f"Cannot read {macro_path.relative_to(repo_root)}")
            continue

        if "{%" not in src and "{{" not in src:
            continue

        open_blocks = src.count("{%") + src.count("{{") + src.count("{#")
        close_blocks = src.count("%}") + src.count("}}") + src.count("#}")
        if open_blocks != close_blocks:
            errors.append(
                f"{macro_path.relative_to(repo_root)} has unbalanced Jinja"
                f" delimiters ({open_blocks} open vs {close_blocks} close)"
            )

        macros_open = len(re.findall(r"{%-?\s*macro\s+\w+", src))
        macros_close = len(re.findall(r"{%-?\s*endmacro\s*-?%}", src))
        if macros_open != macros_close:
            errors.append(
                f"{macro_path.relative_to(repo_root)} has {macros_open} macro(s)"
                f" but {macros_close} endmacro(s)"
            )

    return errors


# --- Service catalog scope validation ---


def check_service_catalog_scopes(repo_root: Path = REPO_ROOT) -> list[str]:
    catalog = load_yaml_file(repo_root / "states" / "data" / "service_catalog.yaml")
    valid_scopes = {"system", "user"}
    errors = []

    for service_name, config in catalog.items():
        if not isinstance(config, dict):
            continue
        scope = config.get("scope")
        if isinstance(scope, str) and scope not in valid_scopes:
            errors.append(
                f"Service catalog '{service_name}' has invalid scope '{scope}'"
                f" (must be one of {valid_scopes})"
            )
        elif not isinstance(scope, str):
            errors.append(
                f"Service catalog '{service_name}' missing or invalid scope field"
            )

    return errors


# --- Feature matrix uniqueness ---


def check_feature_matrix_unique_names(repo_root: Path = REPO_ROOT) -> list[str]:
    matrix = load_yaml_file(repo_root / "states" / "data" / "feature_matrix.yaml")
    if not isinstance(matrix, list):
        return []

    errors = []
    seen = set()
    for entry in matrix:
        if not isinstance(entry, dict):
            continue
        name = entry.get("name", "")
        if not isinstance(name, str) or not name:
            errors.append("feature_matrix.yaml entry missing valid name")
        elif name in seen:
            errors.append(f"feature_matrix.yaml duplicate scenario name '{name}'")
        else:
            seen.add(name)

    return errors


# --- Data file YAML syntax ---


def check_data_file_yaml_syntax(repo_root: Path = REPO_ROOT) -> list[str]:
    data_dir = repo_root / "states" / "data"
    errors = []

    for yaml_path in sorted(data_dir.glob("*.yaml")):
        try:
            with yaml_path.open() as fh:
                yaml.safe_load(fh.read())
        except yaml.YAMLError as e:
            errors.append(
                f"Data file '{yaml_path.relative_to(repo_root)}' YAML error: {e}"
            )
        except (OSError, IOError):
            errors.append(
                f"Data file '{yaml_path.relative_to(repo_root)}' cannot be read"
            )

    return errors


EXPECTED_DATA_SCHEMA_VERSION = 1


def check_data_schema_versions(repo_root: Path = REPO_ROOT) -> list[str]:
    """Validate all states/data/*.yaml files have the expected schema_version."""
    data_dir = repo_root / "states" / "data"
    warnings = []

    for yaml_path in sorted(data_dir.glob("*.yaml")):
        rel = yaml_path.relative_to(repo_root)
        data = load_yaml_file(yaml_path)

        if not isinstance(data, dict):
            continue

        version = data.get("schema_version")
        if version is None:
            warnings.append(
                f"Data file '{rel}': missing schema_version "
                f"(expected {EXPECTED_DATA_SCHEMA_VERSION})"
            )
        elif version != EXPECTED_DATA_SCHEMA_VERSION:
            warnings.append(
                f"Data file '{rel}': schema_version {version} != "
                f"expected {EXPECTED_DATA_SCHEMA_VERSION}"
            )

    return warnings


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
    errors.extend(check_container_images_liveness(repo_root))
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
    errors.extend(check_data_file_liveness(repo_root))
    errors.extend(check_monitored_services_references(repo_root))
    errors.extend(check_drift_inventory_units(repo_root))
    errors.extend(check_feature_defaults_sync(repo_root))
    errors.extend(check_services_feature_gates(repo_root))
    errors.extend(check_data_imports_exist(repo_root))
    errors.extend(check_sls_feature_gates_against_registry(repo_root))
    errors.extend(check_registry_gates_resolve_to_states(repo_root))
    errors.extend(check_sls_config_refs_exist(repo_root))
    errors.extend(check_sls_includes_exist(repo_root))
    errors.extend(check_macro_files_syntax(repo_root))
    errors.extend(check_service_catalog_scopes(repo_root))
    errors.extend(check_feature_matrix_unique_names(repo_root))
    errors.extend(check_data_file_yaml_syntax(repo_root))
    return errors


def check_all_contracts(repo_root: Path = REPO_ROOT) -> list[str]:
    """Run all checks including schema version validation."""
    errors = check_service_inventory_contracts(repo_root)
    errors.extend(check_data_schema_versions(repo_root))
    return errors


def _get_pretty():
    """Lazy-load pretty printer — returns None if unavailable."""
    try:
        from lib.pretty import pretty
        return pretty
    except ImportError:
        return None


def print_contract_errors(errors: list[str]) -> int:
    pretty = _get_pretty()
    if pretty:
        for error in errors:
            pretty.fail(f"Contract: {error}")
    else:
        for error in errors:
            print(f"\033[31mContract: {error}\033[0m")
    return len(errors)


def print_contract_summary(errors: list[str]) -> int:
    total = len(errors)
    pretty = _get_pretty()
    if pretty:
        if errors:
            for error in errors:
                pretty.fail(f"Contract: {error}")
            pretty.summary_line(0, total, "Contracts")
        else:
            pretty.ok("All data contracts pass — 0 violations")
    else:
        if errors:
            for error in errors:
                print(f"\033[31mContract: {error}\033[0m")
            print(f"\n\033[31m{total} contract violation(s) found\033[0m")
        else:
            print("\033[32mAll data contracts pass — 0 violations\033[0m")
    return total


def print_data_health_summary(repo_root: Path = REPO_ROOT) -> int:
    data_dir = repo_root / "states" / "data"
    consumers = _collect_data_consumers(repo_root)
    registry = _load_feature_registry(repo_root)

    data_files = sorted(data_dir.glob("*.yaml"))
    total_data = len(data_files)
    consumed = sum(1 for f in data_files if f.name in consumers or f.name in _CORE_DATA_FILES)
    orphaned = total_data - consumed

    packages_data = load_yaml_file(repo_root / "states" / "data" / "packages.yaml")
    total_packages = 0
    if isinstance(packages_data, dict):
        total_packages = sum(len(v) for v in packages_data.values() if isinstance(v, list))

    total_features = len(_collect_feature_names(registry))

    catalog = load_yaml_file(repo_root / "states" / "data" / "service_catalog.yaml")
    total_services = len([k for k, v in catalog.items() if isinstance(v, dict)]) if isinstance(catalog, dict) else 0

    errors = check_service_inventory_contracts(repo_root)

    pretty = _get_pretty()
    if pretty:
        pretty.section("Data Health Summary")
        pretty.info(f"Data files:       {total_data:>4}  ({consumed} consumed, {orphaned} orphaned)")
        pretty.info(f"Packages:         {total_packages:>4}  (across packages.yaml)")
        pretty.info(f"Feature flags:    {total_features:>4}  (in feature_registry.yaml)")
        pretty.info(f"Catalog services: {total_services:>4}  (in service_catalog.yaml)")
        if errors:
            pretty.fail(f"Contract errors:  {len(errors):>4}")
            for error in errors:
                pretty.fail(f"  {error}")
        else:
            pretty.ok(f"Contract errors:  {len(errors):>4}")
    else:
        print("=== Data Health Summary ===")
        print(f"Data files:       {total_data:>4}  ({consumed} consumed, {orphaned} orphaned)")
        print(f"Packages:         {total_packages:>4}  (across packages.yaml)")
        print(f"Feature flags:    {total_features:>4}  (in feature_registry.yaml)")
        print(f"Catalog services: {total_services:>4}  (in service_catalog.yaml)")
        print(f"Contract errors:  {len(errors):>4}")
        if errors:
            for error in errors:
                print(f"  \033[31m- {error}\033[0m")
        else:
            print("  \033[32mAll checks pass\033[0m")

    return min(len(errors), 1)


def main() -> int:
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verbose", "-v", action="store_true", help="Show summary even when clean")
    parser.add_argument("--summary", "-s", action="store_true", help="Show data health overview")
    args = parser.parse_args()
    if args.summary:
        return print_data_health_summary()
    errors = check_all_contracts()
    if args.verbose:
        return print_contract_summary(errors)
    return print_contract_errors(errors)


if __name__ == "__main__":
    raise SystemExit(main())
