"""Unit tests for states/data schema and consistency contracts.

Validates cross-file references, schema constraints, and data-specific invariants
across repository-managed YAML data files under states/data/.
"""

import importlib.util
import os
import re

import pytest
import yaml

from tests import REPO_ROOT_STR

DATA_DIR = os.path.join(REPO_ROOT_STR, "states", "data")


def _load_salt_contracts():
    module_path = os.path.join(REPO_ROOT_STR, "scripts", "salt_contracts.py")
    spec = importlib.util.spec_from_file_location("salt_contracts", module_path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_yaml(filename):
    """Load a YAML data file from states/data/, returning parsed content."""
    path = os.path.join(DATA_DIR, filename)
    with open(path) as fh:
        return yaml.safe_load(fh.read())


def flatten_packages(packages_data):
    """Collect all package names from packages.yaml across all categories."""
    names = set()
    for category, pkgs in packages_data.items():
        if not isinstance(pkgs, list):
            continue
        for entry in pkgs:
            # Strip inline comments: "pkg-name  # description" → "pkg-name"
            name = str(entry).split("#")[0].strip()
            if name:
                names.add(name)
    return names


def extract_version_entries(installers_data):
    """Find installer entries whose URLs contain ${VER}, return entry names."""
    ver_re = re.compile(r"\$\{VER\}")
    entries = []
    for macro_type, tools in installers_data.items():
        if not isinstance(tools, dict):
            continue
        for name, config in tools.items():
            if not isinstance(config, dict):
                continue
            for _key, val in config.items():
                if isinstance(val, str) and ver_re.search(val):
                    entries.append(name)
                    break
    return entries


# --- US1: Version key cross-references ---


def test_installer_version_keys_exist():
    """Every installer entry using ${VER} must have a matching versions.yaml key."""
    installers = load_yaml("installers.yaml")
    versions = load_yaml("versions.yaml")
    entries_with_ver = extract_version_entries(installers)

    missing = []
    for name in entries_with_ver:
        # Normalize: tool-name → tool_name (versions.yaml convention)
        ver_key = name.replace("-", "_")
        if ver_key not in versions:
            missing.append(f"{name} (expected key: {ver_key})")

    assert not missing, f"Installer entries reference missing version keys: {missing}"


# --- US1: Catalog package field validation ---


def test_catalog_packages_are_valid():
    """Every packages field in service_catalog.yaml must be a non-empty string."""
    catalog = load_yaml("service_catalog.yaml")

    invalid = []
    for svc_name, svc_config in catalog.items():
        if not isinstance(svc_config, dict):
            continue
        pkgs_field = svc_config.get("packages")
        if pkgs_field is None:
            continue  # packages is optional (e.g., ollama installed externally)
        if not isinstance(pkgs_field, str) or not pkgs_field.strip():
            invalid.append(f"{svc_name}: packages must be non-empty string, got {pkgs_field!r}")

    assert not invalid, f"Invalid catalog package fields: {invalid}"


def test_avahi_package_list_does_not_reference_missing_repo_package():
    """Avahi package list should only include packages available in repos."""
    services = load_yaml("services.yaml")
    avahi = services.get("dns", {}).get("avahi", {})

    assert "avahi-tools" not in avahi.get("packages", "")


# --- US1: Monitored services cross-references ---


def _collect_known_services():
    """Collect all service names from catalog, services.yaml, and base OS."""
    unit_suffixes = (".service", ".timer", ".socket", ".path", ".container")
    templated_unit_suffixes = tuple(f"{suffix}.j2" for suffix in unit_suffixes)
    known = set()
    catalog = load_yaml("service_catalog.yaml")
    for name, config in catalog.items():
        if isinstance(config, dict):
            known.add(name)
            unit = config.get("unit", "")
            if unit:
                known.add(unit)
                if "." not in unit:
                    known.add(f"{unit}.service")

    services = load_yaml("services.yaml")
    simple = services.get("simple", {})
    if isinstance(simple, dict):
        for name, config in simple.items():
            known.add(name)
            if isinstance(config, dict):
                svc = config.get("service", "")
                if svc:
                    known.add(svc)
                    if "." not in svc:
                        known.add(f"{svc}.service")

    # Services managed by dedicated .sls files or the OS (not in catalog).
    # These are always present and intentionally outside the catalog.
    states_dir = os.path.join(os.path.dirname(DATA_DIR))
    for sls in os.listdir(states_dir):
        if sls.endswith(".sls"):
            known.add(sls[:-4])  # e.g., "mpd.sls" → "mpd"
            known.add(sls[:-4].replace("_", "-"))  # "monitoring_alerts" → "monitoring-alerts"

    # Base OS services (always present, never Salt-managed)
    known.update(
        {
            "sshd",
            "sshd.service",
            "NetworkManager",
            "NetworkManager.service",
            "cronie",
            "cronie.service",
        }
    )

    # Unit files deployed by Salt can live directly under states/units/ or in scope dirs.
    units_dir = os.path.join(states_dir, "units")
    unit_paths = [units_dir]
    unit_paths.extend(os.path.join(units_dir, scope_dir) for scope_dir in ("user", "system"))
    for unit_path in unit_paths:
        if os.path.isdir(unit_path):
            for unit_file in os.listdir(unit_path):
                for suffix in unit_suffixes:
                    if unit_file.endswith(suffix):
                        known.add(unit_file)
                        known.add(unit_file[: -len(suffix)])
                for suffix in templated_unit_suffixes:
                    if unit_file.endswith(suffix):
                        unit_name = unit_file[: -len(".j2")]
                        known.add(unit_name)
                        known.add(unit_name[: -len(suffix.removesuffix(".j2"))])

    return known


@pytest.mark.parametrize("scope", ["system_services", "user_services"])
def test_monitored_services_resolvable(scope):
    """Non-optional monitored services must trace to catalog, services, or .sls."""
    monitored = load_yaml("monitored_services.yaml")
    known = _collect_known_services()

    entries = monitored.get(scope, [])
    if not isinstance(entries, list):
        return

    missing = []
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        name = entry.get("name", "")
        is_optional = entry.get("optional", False)
        normalized = name.replace("-", "_")
        if not is_optional and name not in known and normalized not in known:
            missing.append(name)

    assert not missing, f"Monitored {scope} reference unknown services: {missing}"


def test_user_services_schema_is_valid():
    """user_services.yaml entries must satisfy the shared contract checker."""
    salt_contracts = _load_salt_contracts()

    errors = salt_contracts.check_user_services_schema()

    assert errors == []


def test_user_services_inventory_does_not_manage_gpu_unstick_units():
    inventory = load_yaml("user_services.yaml")

    unit_files = {entry["filename"] for entry in inventory["unit_files"]}
    enable_now_timers = {entry["name"] for entry in inventory["enable_now_timers"]}

    assert "gpu-unstick.service" not in unit_files
    assert "gpu-unstick.timer" not in unit_files
    assert "gpu-unstick.timer" not in enable_now_timers


def _assert_drift_inventory_schema(inventory):
    assert set(inventory) >= {"files", "system_units", "user_units"}

    files = inventory["files"]
    assert isinstance(files, list) and files
    file_ids = set()
    for entry in files:
        assert isinstance(entry["id"], str) and entry["id"]
        assert entry["id"] not in file_ids
        file_ids.add(entry["id"])
        assert isinstance(entry["path"], str) and entry["path"]
        assert entry["severity"] in {"critical", "warning", "info"}
        assert isinstance(entry.get("capture_after_apply", True), bool)

    for scope in ("system_units", "user_units"):
        entries = inventory[scope]
        assert isinstance(entries, list) and entries
        for entry in entries:
            assert isinstance(entry["name"], str) and entry["name"].endswith((".service", ".timer"))
            assert isinstance(entry["enabled"], bool)
            assert entry["severity"] in {"critical", "warning", "info"}
            assert isinstance(entry.get("optional", False), bool)


def test_drift_inventory_schema_is_valid():
    inventory = load_yaml("drift_inventory.yaml")

    _assert_drift_inventory_schema(inventory)


def test_drift_inventory_schema_rejects_non_boolean_flags():
    inventory = {
        "files": [
            {
                "id": "salt-monitor-script",
                "path": "{{ home }}/.local/bin/salt-monitor",
                "severity": "critical",
                "capture_after_apply": 1,
            }
        ],
        "system_units": [
            {"name": "sshd.service", "enabled": 1, "severity": "critical", "optional": 0}
        ],
        "user_units": [{"name": "salt-monitor.service", "enabled": True, "severity": "critical"}],
    }

    with pytest.raises(AssertionError):
        _assert_drift_inventory_schema(inventory)


def test_drift_inventory_paths_and_units_resolve_to_known_targets():
    inventory = load_yaml("drift_inventory.yaml")
    known = _collect_known_services()

    for entry in inventory["files"]:
        path = entry["path"]
        assert path.startswith("/") or path.startswith("{{ home }}/")

    for scope in ("system_units", "user_units"):
        for entry in inventory[scope]:
            unit = entry["name"]
            base = unit.rsplit(".", 1)[0]
            assert base in known or unit in {"salt-monitor.service", "salt-monitor-watchdog.timer"}


def test_collect_known_services_includes_root_level_units():
    known = _collect_known_services()

    assert "xray.service" in known
    assert "transmission-container.container" in known
    assert "salt-daemon.service" in known


def _assert_vpn_split_router_schema(data):
    settings = data["settings"]
    for setting in (
        "probe_timeout_seconds",
        "probe_interval_seconds",
        "seed_vpn_failure_threshold",
        "observed_vpn_failure_threshold",
        "direct_ttl_seconds",
        "vpn_ttl_seconds",
        "observed_stale_after_seconds",
    ):
        assert isinstance(settings[setting], (int, float))
        assert not isinstance(settings[setting], bool)
    assert settings["probe_timeout_seconds"] > 0
    assert settings["probe_interval_seconds"] > 0
    assert settings["seed_vpn_failure_threshold"] >= 1
    assert settings["observed_vpn_failure_threshold"] >= 1
    assert settings["direct_ttl_seconds"] > 0
    assert settings["vpn_ttl_seconds"] > 0
    assert settings["observed_stale_after_seconds"] > settings["vpn_ttl_seconds"]

    seed_domains = data["seed_domains"]
    assert isinstance(seed_domains, list) and seed_domains
    assert all(isinstance(domain, str) and "." in domain for domain in seed_domains)


def test_vpn_split_router_schema_is_valid():
    data = load_yaml("vpn_split_router.yaml")

    _assert_vpn_split_router_schema(data)


@pytest.mark.parametrize(
    "setting",
    [
        "probe_timeout_seconds",
        "probe_interval_seconds",
        "seed_vpn_failure_threshold",
        "observed_vpn_failure_threshold",
        "direct_ttl_seconds",
        "vpn_ttl_seconds",
        "observed_stale_after_seconds",
    ],
)
def test_vpn_split_router_schema_rejects_boolean_settings(setting):
    data = load_yaml("vpn_split_router.yaml")
    data["settings"][setting] = True

    with pytest.raises(AssertionError):
        _assert_vpn_split_router_schema(data)


def test_vpn_split_router_seed_domains_are_unique():
    data = load_yaml("vpn_split_router.yaml")

    seed_domains = data["seed_domains"]
    assert len(seed_domains) == len(set(seed_domains))


# --- Feature registry contracts ---


def test_feature_registry_schema_is_valid():
    registry = load_yaml("feature_registry.yaml")

    assert isinstance(registry, dict)
    assert "version" in registry
    assert "features" in registry
    assert isinstance(registry["features"], dict)

    for name, config in registry["features"].items():
        assert isinstance(config, dict), f"feature_registry '{name}' must be dict"
        if "features" in config:
            assert "description" in config, f"group '{name}' missing description"
            assert isinstance(config["features"], dict), f"group '{name}' features must be dict"
            for sub_name, sub_config in config["features"].items():
                assert isinstance(sub_config, dict), f"feature '{name}.{sub_name}' must be dict"
                assert "default" in sub_config, f"feature '{name}.{sub_name}' missing default"
                assert isinstance(sub_config["default"], bool), (
                    f"feature '{name}.{sub_name}' default must be bool"
                )
        else:
            assert "default" in config, f"feature '{name}' missing default"
            assert isinstance(config["default"], bool), f"feature '{name}' default must be bool"


def test_feature_registry_features_match_hosts_yaml():
    registry = load_yaml("feature_registry.yaml")
    hosts = load_yaml("hosts.yaml")

    registry_features = set()
    for name, config in registry["features"].items():
        if isinstance(config, dict) and "features" in config:
            for sub_name in config["features"]:
                registry_features.add(f"{name}.{sub_name}")
        elif isinstance(config, dict):
            registry_features.add(name)

    hosts_features = load_yaml("hosts.yaml").get("defaults", {}).get("features", {})

    def _collect_names(d, prefix=""):
        names = set()
        for k, v in d.items():
            full = f"{prefix}.{k}" if prefix else k
            if isinstance(v, dict) and any(isinstance(x, bool) for x in v.values()):
                names.update(_collect_names(v, full))
            elif isinstance(v, bool):
                names.add(full)
        return names

    hosts_feature_set = _collect_names(hosts_features)

    missing_from_registry = hosts_feature_set - registry_features
    assert not missing_from_registry, (
        f"hosts.yaml features not in feature_registry: {missing_from_registry}"
    )

    missing_from_hosts = registry_features - hosts_feature_set
    assert not missing_from_hosts, (
        f"feature_registry features not in hosts.yaml: {missing_from_hosts}"
    )


def test_feature_matrix_entries_are_valid():
    matrix = load_yaml("feature_matrix.yaml")
    registry = load_yaml("feature_registry.yaml")

    assert isinstance(matrix, list)

    registry_features = set()
    for name, config in registry["features"].items():
        if isinstance(config, dict) and "features" in config:
            for sub_name in config["features"]:
                registry_features.add(f"{name}.{sub_name}")
        elif isinstance(config, dict):
            registry_features.add(name)

    names_seen = set()

    def _collect_names(d, prefix=""):
        names = set()
        for k, v in d.items():
            full = f"{prefix}.{k}" if prefix else k
            if isinstance(v, dict) and any(isinstance(x, bool) for x in v.values()):
                names.update(_collect_names(v, full))
            elif isinstance(v, bool):
                names.add(full)
        return names

    for entry in matrix:
        assert "name" in entry, "feature_matrix entry missing name"
        assert "description" in entry, f"entry '{entry.get('name', '?')}' missing description"
        assert entry["name"] not in names_seen, f"duplicate name: {entry['name']}"
        names_seen.add(entry["name"])

        overrides = entry.get("overrides", {}).get("features", {})
        matrix_features = _collect_names(overrides)
        unknown = matrix_features - registry_features
        assert not unknown, (
            f"feature_matrix '{entry['name']}' unknown features: {unknown}"
        )


def test_feature_matrix_has_all_features_scenario():
    matrix = load_yaml("feature_matrix.yaml")

    names = [entry["name"] for entry in matrix if isinstance(entry, dict)]
    assert "matrix-all-features" in names, (
        "feature_matrix.yaml missing 'matrix-all-features' scenario"
    )


def test_user_service_features_from_registry():
    registry = load_yaml("feature_registry.yaml")
    user_services = load_yaml("user_services.yaml")

    user_features = registry.get("features", {}).get("user_services", {}).get("features", {})
    allowed = {f for f, c in user_features.items() if isinstance(c, dict)}

    for entry in user_services.get("unit_files", []):
        if not isinstance(entry, dict):
            continue
        features = entry.get("features")
        if not isinstance(features, list):
            continue
        for f in features:
            assert isinstance(f, str), f"unit_files feature must be string, got {type(f).__name__}"
            assert f in allowed, f"unit_files feature '{f}' not in user_services registry"

    for group in ("enable_services", "enable_now_timers"):
        for entry in user_services.get(group, []):
            if not isinstance(entry, dict):
                continue
            features = entry.get("features")
            if not isinstance(features, list):
                continue
            for f in features:
                assert isinstance(f, str), f"{group} feature must be string, got {type(f).__name__}"
                assert f in allowed, f"{group} feature '{f}' not in user_services registry"


# --- Config template references ---


def test_services_config_templates_exist():
    services = load_yaml("services.yaml")
    import os

    configs_dir = os.path.join(os.path.dirname(DATA_DIR), "configs")
    missing = []

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
                    rel = source.removeprefix("salt://")
                    full_path = os.path.join(os.path.dirname(DATA_DIR), rel)
                    if not os.path.isfile(full_path):
                        missing.append(f"{section}.{name}: {source}")

    assert not missing, f"services.yaml config templates not found: {missing}"


# --- Data file liveness ---


def test_data_file_liveness_contracts_pass():
    from pathlib import Path

    salt_contracts = _load_salt_contracts()

    errors = salt_contracts.check_data_file_liveness(Path(REPO_ROOT_STR))
    assert errors == []
