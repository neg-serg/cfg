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
        return yaml.safe_load(fh)


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
