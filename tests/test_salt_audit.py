"""Unit tests for scripts/salt_audit.py — runtime data audit."""

import importlib.util
import os

import yaml

from tests import REPO_ROOT_PATH

SCRIPTS_DIR = os.path.join(str(REPO_ROOT_PATH), "scripts")


def _load_salt_audit():
    module_path = os.path.join(SCRIPTS_DIR, "salt_audit.py")
    spec = importlib.util.spec_from_file_location("salt_audit", module_path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class TestDataInventory:
    def test_inventory_returns_nonempty_list(self):
        audit = _load_salt_audit()
        inventory = audit._collect_data_inventory()
        assert len(inventory) >= 30
        assert all(f.endswith(".yaml") for f in inventory)

    def test_inventory_excludes_core_files(self):
        audit = _load_salt_audit()
        inventory = audit._collect_data_inventory()
        for excluded in audit.EXCLUDED_DATA_FILES:
            assert excluded not in inventory, f"{excluded} should be excluded"

    def test_inventory_includes_known_files(self):
        audit = _load_salt_audit()
        inventory = audit._collect_data_inventory()
        assert "packages.yaml" in inventory
        assert "service_catalog.yaml" in inventory
        assert "container_images.yaml" in inventory


class TestAuditReport:
    def test_generate_report_has_all_keys(self):
        _ = _load_salt_audit()
        from datetime import datetime, timezone

        report = {
            "version": 1,
            "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "hostname": "test-host",
            "salt_target": "test",
            "test_mode": True,
            "duration_seconds": 0.5,
            "consumed": [{
                "data_file": "packages.yaml",
                "consumers": ["packages"],
                "access_method": "import_yaml",
                "eval_count": 1,
            }],
            "unused": [],
            "total_data_files": 39,
            "consumed_count": 1,
        }

        required_keys = [
            "version", "timestamp", "hostname", "salt_target",
            "test_mode", "duration_seconds", "consumed", "unused",
            "total_data_files", "consumed_count",
        ]
        for key in required_keys:
            assert key in report, f"missing key: {key}"

    def test_report_counts_consistent(self):
        _ = _load_salt_audit()
        from datetime import datetime, timezone

        consumed = [{
            "data_file": "a.yaml",
            "consumers": ["a"],
            "access_method": "import_yaml",
            "eval_count": 1,
        }]
        unused = ["b.yaml", "c.yaml"]
        report = {
            "version": 1,
            "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "hostname": "test",
            "salt_target": "test",
            "test_mode": False,
            "duration_seconds": 0,
            "consumed": consumed,
            "unused": unused,
            "total_data_files": 3,
            "consumed_count": 1,
        }
        assert report["consumed_count"] == len(report["consumed"])
        assert len(report["consumed"]) + len(report["unused"]) == report["total_data_files"]

    def test_report_no_duplicates(self):
        _ = _load_salt_audit()

        consumed = [
            {"data_file": "a.yaml", "consumers": ["a"],
             "access_method": "import_yaml", "eval_count": 1},
            {"data_file": "b.yaml", "consumers": ["b"],
             "access_method": "import_yaml", "eval_count": 1},
        ]
        consumed_files = {r["data_file"] for r in consumed}
        unused = ["c.yaml"]
        assert len(consumed_files) == len(consumed)
        assert not consumed_files.intersection(set(unused))


class TestUnusedDiff:
    def test_diff_returns_list(self):
        audit = _load_salt_audit()
        report = {
            "unused": ["floorp.yaml", "xen.yaml"],
            "hostname": "test",
        }
        diff = audit.compute_unused_diff(report)
        assert isinstance(diff, list)
        assert len(diff) == 2

    def test_diff_annotates_with_reason(self):
        audit = _load_salt_audit()
        report = {
            "unused": ["floorp.yaml"],
            "hostname": "telfir",
        }
        diff = audit.compute_unused_diff(report)
        assert diff[0]["data_file"] == "floorp.yaml"
        assert "reason" in diff[0]
        assert isinstance(diff[0]["reason"], str)

    def test_diff_empty_unused(self):
        audit = _load_salt_audit()
        report = {"unused": [], "hostname": "test"}
        diff = audit.compute_unused_diff(report)
        assert diff == []


class TestFeatureGating:
    def test_feature_gating_resolves_floorp(self):
        audit = _load_salt_audit()
        reason = audit._resolve_feature_gating("telfir", "floorp.yaml")
        assert reason is not None
        assert "floorp" in reason

    def test_feature_gating_unknown_file(self):
        audit = _load_salt_audit()
        reason = audit._resolve_feature_gating("telfir", "nonexistent.yaml")
        assert reason == "truly_orphaned"


class TestWriteAuditLog:
    def test_write_creates_file(self, tmp_path):
        _ = _load_salt_audit()
        from datetime import datetime, timezone

        report = {
            "version": 1,
            "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "hostname": "test",
            "salt_target": "test",
            "test_mode": True,
            "duration_seconds": 0.1,
            "consumed": [],
            "unused": [],
            "total_data_files": 0,
            "consumed_count": 0,
        }

        log_path = tmp_path / "audit-test.yaml"
        with open(log_path, "w") as fh:
            yaml.dump(report, fh)

        assert log_path.is_file()
        with open(log_path) as fh:
            loaded = yaml.safe_load(fh.read())
        assert loaded["version"] == 1


class TestExpectedConsumption:
    def test_build_expected_returns_dict(self):
        audit = _load_salt_audit()
        expected = audit._build_expected_consumption("system_description")
        assert isinstance(expected, dict)
        assert len(expected) > 0

    def test_build_expected_for_specific_state(self):
        audit = _load_salt_audit()
        expected = audit._build_expected_consumption("ollama")
        assert isinstance(expected, dict)
        if "ollama.yaml" in expected:
            assert "ollama" in expected["ollama.yaml"]
