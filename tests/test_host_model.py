"""Unit tests for scripts/host_model.py — shared host model builder."""

# scripts/ is on sys.path via conftest.py
import sys
from pathlib import Path

import host_model  # noqa: E402, I001
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "states" / "_modules"))


# --- recursive_merge ---


def test_recursive_merge_basic():
    base = {"a": 1, "b": {"x": 10, "y": 20}, "c": [1, 2]}
    override = {"a": 2, "b": {"y": 99, "z": 30}, "c": [3]}
    result = host_model.recursive_merge(base, override)
    assert result["a"] == 2
    assert result["b"] == {"x": 10, "y": 99, "z": 30}
    assert result["c"] == [3]  # lists override, not merge


def test_recursive_merge_empty():
    base = {"a": 1, "b": {"x": 10}}
    result = host_model.recursive_merge(base, {})
    assert result == base
    assert result is not base  # must be a copy


def test_recursive_merge_does_not_mutate_base():
    base = {"a": 1, "b": {"x": 10}}
    override = {"b": {"x": 99}}
    host_model.recursive_merge(base, override)
    assert base["b"]["x"] == 10  # base unchanged


# --- enable_all_features ---


def test_enable_all_features():
    config = {
        "user": "neg",
        "features": {
            "steam": False,
            "monitoring": {"loki": False, "sysstat": True},
            "mpd": True,
        },
    }
    result = host_model.enable_all_features(config)
    assert result["features"]["steam"] is True
    assert result["features"]["monitoring"]["loki"] is True
    assert result["features"]["monitoring"]["sysstat"] is True
    assert result["features"]["mpd"] is True
    assert result["user"] == "neg"  # non-features unchanged


def test_enable_all_features_preserves_non_bool():
    config = {"features": {"name": "test", "count": 42, "enabled": False}}
    result = host_model.enable_all_features(config)
    assert result["features"]["name"] == "test"
    assert result["features"]["count"] == 42
    assert result["features"]["enabled"] is True


# --- build_lint_host ---


def test_build_lint_host_derived_fields():
    host = host_model.build_lint_host()
    assert "runtime_dir" in host
    assert host["runtime_dir"] == f"/run/user/{host['uid']}"
    assert host["pkg_list"] == "/var/cache/salt/pacman_installed.txt"
    assert host["project_dir"] == host["home"] + "/src/cfg"


def test_build_lint_host_all_features_enabled():
    host = host_model.build_lint_host()
    features = host.get("features", {})

    def check_no_false(d, path="features"):
        for k, v in d.items():
            if isinstance(v, dict):
                check_no_false(v, f"{path}.{k}")
            elif v is False:
                pytest.fail(f"{path}.{k} is False — should be True in lint host")

    check_no_false(features)


def test_build_lint_host_has_hostname():
    host = host_model.build_lint_host()
    assert host["hostname"] == "lint-check"


# --- load_hosts_yaml ---


def test_load_hosts_yaml():
    data = host_model.load_hosts_yaml()
    assert isinstance(data, dict)
    assert "defaults" in data
    assert "hosts" in data
    assert "aliases" in data


# --- check_host_config ---


def test_check_host_config_valid():
    errors = host_model.check_host_config()
    assert errors == 0


def test_check_host_config_unknown_key(capsys):
    data = host_model.load_hosts_yaml()
    defaults = data.get("defaults", {})
    fake_config = {"typo_key": "oops"}
    errors = host_model.check_unknown_keys(fake_config, defaults, "test-host")
    assert errors == 1
    captured = capsys.readouterr()
    assert "unknown key" in captured.out
    assert "typo_key" in captured.out


# --- alias resolution ---


def test_alias_resolution():
    data = host_model.load_hosts_yaml()
    host_via_alias = host_model.build_host("cachyos", data)
    host_direct = host_model.build_host("telfir", data)
    # Both should resolve to telfir's config
    assert host_via_alias["hostname"] == host_direct["hostname"]


def test_unknown_host_returns_defaults():
    data = host_model.load_hosts_yaml()
    host = host_model.build_host("nonexistent-host", data)
    # Should return defaults with derived fields
    assert "runtime_dir" in host
    assert "pkg_list" in host
    assert host["user"] == data["defaults"]["user"]


# --- edge cases ---


def test_derived_fields_recomputed_after_override():
    """Edge case: if override contains runtime_dir, it should be recomputed."""
    data = host_model.load_hosts_yaml()
    data = data.copy()
    data["hosts"] = {"test-host": {"runtime_dir": "/bogus"}}
    host = host_model.build_host("test-host", data)
    # Derived field should be recomputed from uid, not taken from override
    assert host["runtime_dir"] == f"/run/user/{host['uid']}"


def test_load_feature_matrix():
    matrix = host_model.load_feature_matrix()
    assert isinstance(matrix, list)
    assert len(matrix) > 0
    for entry in matrix:
        assert "name" in entry


# --- US2: host config assembly pipeline ---


def test_full_assembly_pipeline():
    """Build a real host config and verify defaults + overrides + derived fields."""
    data = host_model.load_hosts_yaml()
    host = host_model.build_host("telfir", data)
    # Defaults should be present
    assert host["user"] == data["defaults"]["user"]
    assert host["home"] == f"/home/{data['defaults']['user']}"
    # Telfir-specific overrides should be applied
    assert "display" in host
    assert "floorp_profile" in host
    assert "zen_profile" in host
    # Derived fields should be computed
    assert host["runtime_dir"] == f"/run/user/{host['uid']}"
    assert host["project_dir"] == host["home"] + "/src/cfg"


def test_alias_produces_identical_config():
    """Alias (cachyos→telfir) must produce an identical config dict."""
    data = host_model.load_hosts_yaml()
    via_alias = host_model.build_host("cachyos", data)
    direct = host_model.build_host("telfir", data)
    assert via_alias == direct


def test_derived_fields_from_custom_uid():
    """Override uid → derived runtime_dir should reflect the new uid."""
    data = host_model.load_hosts_yaml()
    data = data.copy()
    data["hosts"] = {"custom-uid-host": {"uid": 9999}}
    host = host_model.build_host("custom-uid-host", data)
    assert host["runtime_dir"] == "/run/user/9999"


def test_feature_flag_override_preserves_siblings():
    """Overriding one feature flag preserves sibling flags from defaults."""
    data = host_model.load_hosts_yaml()
    defaults_features = data["defaults"].get("features", {})
    data = data.copy()
    data["hosts"] = {"flag-test": {"features": {"steam": False}}}
    host = host_model.build_host("flag-test", data)
    assert host["features"]["steam"] is False
    # Other feature flags from defaults should still be present
    for key in defaults_features:
        if key != "steam":
            assert key in host["features"], f"Feature '{key}' missing after override"


def test_host_defaults_include_dual_browser_fields():
    data = host_model.load_hosts_yaml()
    defaults = data["defaults"]
    assert "floorp_profile" in defaults
    assert "zen_profile" in defaults
    assert defaults["floorp_profile"] == ""
    assert defaults["zen_profile"] == ""


def test_telfir_has_primary_and_secondary_browser_bindings():
    data = host_model.load_hosts_yaml()
    host = host_model.build_host("telfir", data)
    assert host["zen_profile"] == "qnkh60k3.Default (release)"
    assert host["floorp_profile"] == "c85pjaxk.default-default"
    assert host["features"]["floorp"] is False


def test_telfir_enables_telethon_bridge_stack():
    data = host_model.load_hosts_yaml()
    host = host_model.build_host("telfir", data)

    assert host["features"]["telethon_bridge"] is True


# --- US4: deep merge edge cases ---


def test_merge_three_level_nesting():
    """3-level nested dicts merge recursively."""
    base = {"a": {"b": {"c": 1}}}
    override = {"a": {"b": {"d": 2}}}
    result = host_model.recursive_merge(base, override)
    assert result == {"a": {"b": {"c": 1, "d": 2}}}


def test_merge_list_replaces_entirely():
    """Lists are replaced, not appended."""
    base = {"k": [1, 2, 3]}
    override = {"k": [4, 5]}
    result = host_model.recursive_merge(base, override)
    assert result["k"] == [4, 5]


def test_merge_scalar_replaces_dict():
    """Scalar override replaces a dict base value."""
    base = {"k": {"nested": True}}
    override = {"k": "string"}
    result = host_model.recursive_merge(base, override)
    assert result["k"] == "string"


def test_merge_dict_replaces_scalar():
    """Dict override replaces a scalar base value."""
    base = {"k": "string"}
    override = {"k": {"nested": True}}
    result = host_model.recursive_merge(base, override)
    assert result["k"] == {"nested": True}


def test_merge_empty_dict_preserves_base():
    """Empty dict override does not clobber base nested dict."""
    base = {"a": {"x": 1}}
    override = {"a": {}}
    result = host_model.recursive_merge(base, override)
    assert result == {"a": {"x": 1}}


def test_merge_none_override():
    """None override replaces base value."""
    base = {"k": "val"}
    override = {"k": None}
    result = host_model.recursive_merge(base, override)
    assert result["k"] is None


def test_merge_none_in_nested_dict():
    """None value in nested override replaces base nested value."""
    base = {"a": {"b": "val"}}
    override = {"a": {"b": None}}
    result = host_model.recursive_merge(base, override)
    assert result["a"]["b"] is None


def test_merge_false_overrides_true():
    """Boolean False is a value and should override True."""
    base = {"enabled": True}
    override = {"enabled": False}
    result = host_model.recursive_merge(base, override)
    assert result["enabled"] is False


def test_merge_true_overrides_false():
    """Boolean True overrides False."""
    base = {"enabled": False}
    override = {"enabled": True}
    result = host_model.recursive_merge(base, override)
    assert result["enabled"] is True


def test_merge_empty_string_override():
    """Empty string override replaces base string."""
    base = {"name": "hello"}
    override = {"name": ""}
    result = host_model.recursive_merge(base, override)
    assert result["name"] == ""


def test_merge_new_key_introduced():
    """Override can introduce keys not present in base."""
    base = {"a": 1}
    override = {"b": 2}
    result = host_model.recursive_merge(base, override)
    assert result == {"a": 1, "b": 2}


def test_merge_new_nested_key():
    """Override can introduce nested keys not in base."""
    base = {"features": {"steam": True}}
    override = {"features": {"new_feat": False}}
    result = host_model.recursive_merge(base, override)
    assert result["features"]["steam"] is True
    assert result["features"]["new_feat"] is False


def test_merge_zero_override():
    """Zero value overrides non-zero."""
    base = {"count": 5}
    override = {"count": 0}
    result = host_model.recursive_merge(base, override)
    assert result["count"] == 0


def test_merge_deep_nesting_new_path():
    """Deep nesting where intermediate keys exist only in override."""
    base = {"a": {"x": 1}}
    override = {"a": {"y": {"z": 2}}}
    result = host_model.recursive_merge(base, override)
    assert result["a"]["x"] == 1
    assert result["a"]["y"]["z"] == 2


def test_merge_base_not_mutated_after_nested_merge():
    """Verify base dict is never mutated by nested merges."""
    base = {"a": {"b": {"c": 1}}}
    override = {"a": {"b": {"d": 2}}}
    result = host_model.recursive_merge(base, override)
    assert base["a"]["b"] == {"c": 1}  # unchanged
    assert result["a"]["b"] == {"c": 1, "d": 2}


def test_merge_list_within_dict():
    """Lists within nested dicts are replaced, not merged."""
    base = {"a": {"items": [1, 2, 3]}}
    override = {"a": {"items": [4, 5]}}
    result = host_model.recursive_merge(base, override)
    assert result["a"]["items"] == [4, 5]


# --- check_features_against_registry ---


def test_check_features_against_registry_passes():
    errors = host_model.check_features_against_registry()
    assert errors == 0


def test_registry_feature_names_are_well_formed():
    features = host_model._collect_registry_features(host_model.load_feature_registry())
    assert "monitoring.loki" in features
    assert "monitoring.sysstat" in features
    assert "dns.unbound" in features
    assert "steam" in features
    assert "ollama" in features
    assert "amnezia" in features
    # Groups should NOT appear as feature names
    assert "monitoring" not in features
    assert "dns" not in features
    assert "services" not in features
    assert "network" not in features
    assert "user_services" not in features


def test_registry_features_match_hosts_defaults():
    registry_features = host_model._collect_registry_features(host_model.load_feature_registry())
    hosts_data = host_model.load_hosts_yaml()
    hosts_features = host_model._collect_hosts_features(
        hosts_data.get("defaults", {}).get("features", {})
    )
    missing = registry_features - hosts_features
    extra = hosts_features - registry_features
    assert not missing, f"registry features not in hosts.yaml defaults: {missing}"
    assert not extra, f"hosts.yaml defaults features not in registry: {extra}"


# --- Derived field validation for all feature matrix scenarios ---


def test_all_feature_matrix_hosts_have_valid_derived_fields():
    matrix = host_model.load_feature_matrix()
    assert len(matrix) > 0

    for entry in matrix:
        name = entry.get("name", "?")
        overrides = entry.get("overrides", {})

        host = host_model.build_host(name, host_model.load_hosts_yaml())

        assert isinstance(host.get("home"), str) and host["home"], (
            f"matrix '{name}': missing home"
        )
        assert host["home"] == f"/home/{host['user']}", (
            f"matrix '{name}': home mismatch: {host['home']}"
        )
        assert isinstance(host.get("runtime_dir"), str) and host["runtime_dir"], (
            f"matrix '{name}': missing runtime_dir"
        )
        assert host["runtime_dir"] == f"/run/user/{host['uid']}", (
            f"matrix '{name}': runtime_dir mismatch"
        )
        assert host.get("pkg_list") == "/var/cache/salt/pacman_installed.txt", (
            f"matrix '{name}': pkg_list mismatch"
        )
        assert host.get("project_dir") == host["home"] + "/src/cfg", (
            f"matrix '{name}': project_dir mismatch"
        )
        assert isinstance(host.get("features"), dict), (
            f"matrix '{name}': missing features dict"
        )


def test_host_config_validation_passes_for_all_matrix_hosts():
    errors = host_model.check_host_config()
    assert errors == 0


def test_feature_registry_validation_passes():
    errors = host_model.check_features_against_registry()
    assert errors == 0


# --- host_config.jinja ↔ host_model.py contract ---


def test_host_config_jinja_imports_valid_yaml():
    import re
    import yaml

    host_config_path = host_model.HOSTS_YAML_PATH.replace("data/", "").replace(".yaml", "")
    # host_config.jinja is at states/host_config.jinja
    jinja_path = "states/host_config.jinja"
    try:
        with open(jinja_path) as f:
            content = f.read()
    except FileNotFoundError:
        pytest.skip("host_config.jinja not found")

    import_yaml_re = re.compile(r"import_yaml\s+['\"]([^'\"]+)['\"]")
    refs = import_yaml_re.findall(content)

    for ref in refs:
        path = f"states/{ref}"
        try:
            with open(path) as f:
                yaml.safe_load(f)
        except FileNotFoundError:
            pytest.fail(f"host_config.jinja imports '{ref}' but file not found at {path}")
        except yaml.YAMLError as e:
            pytest.fail(f"host_config.jinja imports '{ref}' but YAML is invalid: {e}")


def test_host_config_jinja_has_merge_logic():
    try:
        with open("states/host_config.jinja") as f:
            content = f.read()
    except FileNotFoundError:
        pytest.skip("host_config.jinja not found")

    # Verify core structural elements exist
    assert "import_yaml" in content, "host_config.jinja must import YAML data"
    assert "hosts_data" in content, "host_config.jinja must reference hosts_data"
    assert "defaults" in content, "host_config.jinja must handle defaults"
    assert "aliases" in content, "host_config.jinja must handle aliases"
    assert "grains" in content or "hostname" in content, "host_config.jinja must resolve hostname"


def test_build_lint_host_enables_all_registry_features():
    reg = host_model.load_feature_registry()
    host = host_model.build_lint_host()

    registry_features = host_model._collect_registry_features(reg)

    def find_false(features, prefix=""):
        falses = []
        for k, v in features.items():
            full = f"{prefix}.{k}" if prefix else k
            if isinstance(v, dict):
                falses.extend(find_false(v, full))
            elif v is False:
                if full in registry_features:
                    falses.append(full)
        return falses

    still_false = find_false(host.get("features", {}))
    assert not still_false, (
        f"lint host has {len(still_false)} features still False: {still_false}"
    )


def test_lint_host_has_all_registry_feature_keys():
    """lint host must have every feature key from the registry, even if False."""
    reg = host_model.load_feature_registry()
    host = host_model.build_lint_host()
    host_features = host.get("features", {})

    registry_features = host_model._collect_registry_features(reg)

    missing_from_host = set()
    for full_name in sorted(registry_features):
        parts = full_name.split(".")
        obj = host_features
        found = True
        for part in parts:
            if isinstance(obj, dict) and part in obj:
                obj = obj[part]
            else:
                found = False
                break
        if not found:
            missing_from_host.add(full_name)

    assert not missing_from_host, (
        f"lint host missing {len(missing_from_host)} registry feature keys:"
        f" {missing_from_host}"
    )


def test_telfir_host_contract():
    """Validate the telfir host config against known expected values.
    This serves as a contract: both host_config.jinja and host_model.py
    must produce these values for telfir."""
    data = host_model.load_hosts_yaml()
    host = host_model.build_host("telfir", data)

    # Top-level fields from defaults
    assert host["user"] == "neg"
    assert host["home"] == "/home/neg"
    assert host["uid"] == 1000
    assert host["mnt_zero"] == "/mnt/zero"
    assert host["mnt_one"] == "/mnt/one"
    assert host["cpu_vendor"] == "amd"
    assert host["kvm_module"] == "kvm_amd"
    assert host["timezone"] == "Europe/Moscow"
    assert host["locale"] == "en_US.UTF-8"

    # Telfir-specific overrides
    assert host["display"] == "3840x2160@240"
    assert host["primary_output"] == "DP-2"
    assert host["greetd_scale"] == 2
    assert host["hostname"] == "telfir"
    assert "ec_sys" in host["extra_modules"]

    # Derived fields
    assert host["runtime_dir"] == "/run/user/1000"
    assert host["pkg_list"] == "/var/cache/salt/pacman_installed.txt"
    assert host["project_dir"] == "/home/neg/src/cfg"

    # Feature flags (telfir overrides)
    feats = host["features"]
    assert feats["fancontrol"] is True
    assert feats["monitoring"]["loki"] is True
    assert feats["monitoring"]["promtail"] is True
    assert feats["monitoring"]["grafana"] is False  # overridden
    assert feats["monitoring"]["alertmanager"] is True
    assert feats["services"]["transmission"] is True
    assert feats["user_services"]["mail"] is False  # overridden
    assert feats["user_services"]["vdirsyncer"] is False  # overridden
    assert feats["network"]["tailscale"] is False  # overridden
    assert feats["network"]["zapret2"] is False  # overridden
    assert feats["network"]["ipv6"] is True
    assert feats["floorp"] is False
    assert feats["opencode"] is True
    assert feats["telethon_bridge"] is True
    assert feats["managed_bots"] is True
    assert feats["music_analysis"] is True
    assert feats["tidal"] is True
    assert feats["nanoclaw"] is True

    # Defaults that should be preserved (not overridden by telfir)
    assert feats["steam"] is True
    assert feats["mpd"] is True
    assert feats["ollama"] is True
    assert feats["llama_embed"] is True
    assert feats["kanata"] is True
    assert feats["flatpak"] is True
    assert feats["video_ai"] is True
    assert feats["xen_vr"] is False
    assert feats["sudo_ssh_agent"] is False


def test_feature_registry_is_jinja_importable():
    """Verify feature_registry.yaml can be loaded by Jinja import_yaml."""
    import yaml

    with open("states/data/feature_registry.yaml") as f:
        data = yaml.safe_load(f)

    assert isinstance(data, dict), "registry must be a YAML mapping"
    assert "version" in data, "registry must have version"
    assert "features" in data, "registry must have features key"
    assert isinstance(data["features"], dict), "features must be a mapping"

    # Verify all features have 'default' (required for Jinja consumption)
    def check_defaults(features, path=""):
        for name, config in features.items():
            full = f"{path}.{name}" if path else name
            if isinstance(config, dict) and "features" in config:
                check_defaults(config["features"], full)
            elif isinstance(config, dict):
                assert "default" in config, f"'{full}' missing default"
                assert isinstance(config["default"], bool), f"'{full}' default must be bool"

    check_defaults(data["features"])


def test_registry_macro_file_exists_and_valid():
    """Check that feature registry functions are available via Python modules."""
    try:
        from _modules.host_features import feature_enabled, feature_default
    except ImportError:
        pytest.skip("_modules.host_features not available")

    assert callable(feature_enabled), "feature_enabled must be callable"
    assert callable(feature_default), "feature_default must be callable"
    assert feature_default("mpd") is True, "mpd default must be True"

    # Verify the imported YAML is valid
    with open("states/data/feature_registry.yaml") as f:
        yaml.safe_load(f)
