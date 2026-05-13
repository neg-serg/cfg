"""Schema validation for data YAML files (packages.yaml, versions.yaml, hosts.yaml).

Uses imperative assertion‑based checks — no jsonschema dependency.
"""

import pytest
import yaml

from tests import REPO_ROOT_PATH

_DATA = REPO_ROOT_PATH / "states" / "data"


# ── Helpers ─────────────────────────────────────────────────────────────

def _load(name):
    with open(_DATA / name) as fh:
        data = yaml.safe_load(fh)
    if isinstance(data, dict):
        data.pop("schema_version", None)
    return data


def _assert_is_list_of_strings(items):
    assert isinstance(items, list), f"expected list, got {type(items).__name__}"
    for i, item in enumerate(items):
        assert isinstance(item, str) and item, f"item {i}: expected non‑empty string, got {item!r}"


def _assert_is_dict_of_strings(d):
    assert isinstance(d, dict), f"expected dict, got {type(d).__name__}"
    for k, v in d.items():
        assert isinstance(k, str) and k, f"key {k!r}: expected non‑empty string"
        assert isinstance(v, str), f"value for {k!r}: expected string, got {type(v).__name__}"


# ── packages.yaml ────────────────────────────────────────────────────────

@pytest.fixture(scope="module")
def packages():
    return _load("packages.yaml")



def test_packages_no_empty_categories(packages):
    for cat, pkgs in packages.items():
        assert isinstance(pkgs, list), f"category {cat}: expected list"
        assert len(pkgs) > 0, f"category {cat}: empty package list"


def test_packages_items_are_strings(packages):
    for cat, pkgs in packages.items():
        for pkg in pkgs:
            assert isinstance(pkg, str) and pkg, f"{cat}: non‑empty string expected, got {pkg!r}"


def test_packages_known_categories(packages):
    expected = {"base", "desktop", "dev", "network", "audio", "media",
                "fonts", "gaming", "system", "other", "aur"}
    for cat in packages:
        assert cat in expected, f"unknown category: {cat}"


# ── versions.yaml ────────────────────────────────────────────────────────

@pytest.fixture(scope="module")
def versions():
    return _load("versions.yaml")



def test_versions_values_are_strings(versions):
    for key, val in versions.items():
        assert isinstance(val, str) and val, f"{key}: expected non‑empty string"



# ── hosts.yaml ───────────────────────────────────────────────────────────

@pytest.fixture(scope="module")
def hosts():
    return _load("hosts.yaml")


def test_hosts_has_top_level_keys(hosts):
    for key in ("defaults", "hosts", "aliases"):
        assert key in hosts, f"missing top‑level key: {key}"


def test_hosts_defaults_has_required_fields(hosts):
    required = {"user", "uid", "timezone", "locale", "features"}
    for field in required:
        assert field in hosts["defaults"], f"missing defaults field: {field}"





def test_hosts_defaults_features_have_expected_keys(hosts):
    feats = hosts["defaults"]["features"]
    expected = {"monitoring", "services", "network", "user_services"}
    for key in expected:
        assert key in feats, f"missing features key: {key}"


def test_hosts_entries_have_hostnames(hosts):
    for hostname, config in hosts.get("hosts", {}).items():
        assert isinstance(hostname, str) and hostname
        assert isinstance(config, dict), f"{hostname}: expected dict config"


def test_hosts_aliases_are_strings(hosts):
    for alias, target in hosts.get("aliases", {}).items():
        assert isinstance(alias, str) and alias
        assert isinstance(target, str) and target, f"alias {alias}: expected string target"


# ── feature_registry.yaml ─────────────────────────────────────────────────


@pytest.fixture(scope="module")
def feature_registry():
    return _load("feature_registry.yaml")


def test_feature_registry_has_version_and_features(feature_registry):
    assert isinstance(feature_registry, dict)
    assert "version" in feature_registry
    assert "features" in feature_registry
    assert isinstance(feature_registry["features"], dict)


def test_feature_registry_all_entries_have_default(feature_registry):
    for name, config in feature_registry["features"].items():
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
                assert "description" in sub_config, f"feature '{name}.{sub_name}' missing description"
        else:
            assert "default" in config, f"feature '{name}' missing default"
            assert isinstance(config["default"], bool), f"feature '{name}' default must be bool"
            assert "description" in config, f"feature '{name}' missing description"


# ── container_images.yaml ──────────────────────────────────────────────


@pytest.fixture(scope="module")
def container_images():
    return _load("container_images.yaml")


def test_container_images_all_have_registry_and_image(container_images):
    for name, cfg in container_images.items():
        assert isinstance(cfg, dict), f"{name}: expected dict"
        assert "registry" in cfg, f"{name}: missing registry"
        assert "image" in cfg, f"{name}: missing image"
        assert isinstance(cfg["registry"], str) and cfg["registry"], f"{name}: registry must be non-empty string"
        assert isinstance(cfg["image"], str) and cfg["image"], f"{name}: image must be non-empty string"


def test_container_images_remote_have_digest(container_images):
    for name, cfg in container_images.items():
        if cfg.get("registry") != "localhost":
            digest = cfg.get("digest")
            assert digest is not None, f"{name}: remote image must have a digest"
            assert isinstance(digest, str), f"{name}: digest must be string"
            assert digest.startswith("sha256:"), f"{name}: digest must start with sha256:"
            assert len(digest) == 71, f"{name}: digest must be sha256:<64 hex> (got {len(digest)} chars)"


def test_container_images_localhost_digest_is_null(container_images):
    for name, cfg in container_images.items():
        if cfg.get("registry") == "localhost":
            assert cfg.get("digest") is None, f"{name}: localhost image must have null digest"


# ── services.yaml ──────────────────────────────────────────────────────


@pytest.fixture(scope="module")
def services_data():
    return _load("services.yaml")


def test_services_has_expected_sections(services_data):
    for section in ("simple", "complex", "network", "dns"):
        assert section in services_data, f"services.yaml missing section: {section}"


def test_services_simple_entries(services_data):
    for name, cfg in services_data.get("simple", {}).items():
        assert isinstance(cfg, dict), f"simple.{name}: expected dict"
        assert "packages" in cfg, f"simple.{name}: missing packages"
        assert "service" in cfg, f"simple.{name}: missing service"


def test_services_complex_entries_have_valid_keys(services_data):
    known = {
        "packages", "package_manager", "service", "unit", "unit_override",
        "ensure_running", "manual_start", "scripts", "config_templates",
        "dirs", "logrotate", "healthcheck", "has_escape_hatch",
        "cleanup", "setup_commands",
    }
    for name, cfg in services_data.get("complex", {}).items():
        assert isinstance(cfg, dict), f"complex.{name}: expected dict"
        for key in cfg:
            assert key in known, f"complex.{name}: unknown key '{key}'"
