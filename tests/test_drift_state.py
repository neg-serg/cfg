import drift_state


def test_refresh_expected_snapshot_captures_inventory_files(tmp_path):
    cache_dir = tmp_path / "cache"
    cache_dir.mkdir()
    managed = tmp_path / "managed"
    managed.mkdir()
    file_path = managed / "salt-monitor"
    file_path.write_text("v1")

    host = {"home": str(tmp_path), "runtime_dir": "/run/user/1000", "hostname": "testbox"}
    inventory = {
        "files": [{"id": "salt-monitor", "path": str(file_path), "severity": "critical"}],
        "system_units": [{"name": "sshd.service", "enabled": True, "severity": "critical"}],
        "user_units": [{"name": "salt-monitor.service", "enabled": True, "severity": "critical"}],
    }

    snapshot = drift_state.build_expected_snapshot(host, inventory)

    assert snapshot["files"][0]["path"] == str(file_path)
    assert snapshot["files"][0]["sha256"]
    assert snapshot["system_units"][0]["name"] == "sshd.service"


def test_classify_drift_marks_config_and_runtime_records_separately():
    expected = {
        "generated_at": "2026-04-17T00:00:00+00:00",
        "files": [
            {"id": "salt-monitor", "path": "/tmp/managed", "sha256": "abc", "severity": "critical"}
        ],
        "system_units": [{"name": "sshd.service", "enabled": True, "severity": "critical"}],
        "user_units": [],
    }
    actual = {
        "files": [{"id": "salt-monitor", "path": "/tmp/managed", "exists": True, "sha256": "def"}],
        "system_units": [
            {"name": "sshd.service", "enabled": False, "masked": False, "severity": "critical"}
        ],
        "runtime_alerts": [{"scope": "user", "service": "telethon-bridge", "type": "unhealthy"}],
        "packages": {"unmanaged": ["stray"], "missing": [], "orphans": []},
    }

    payload = drift_state.classify_drift(expected, actual, stale_after_hours=72)

    categories = {(entry["category"], entry["object"]) for entry in payload["records"]}
    assert ("file", "/tmp/managed") in categories
    assert ("unit", "sshd.service") in categories
    assert ("runtime", "telethon-bridge") in categories
    assert payload["status"] == "drifted"


def test_status_is_unknown_when_baseline_is_missing():
    payload = drift_state.classify_drift(
        None, {"packages": {"unmanaged": [], "missing": [], "orphans": []}}
    )

    assert payload["status"] == "unknown"
    assert payload["records"][0]["status"] == "stale_baseline"


def test_status_prefers_config_drift_over_runtime_only_degradation():
    expected = {
        "generated_at": "2026-04-17T00:00:00+00:00",
        "files": [{"id": "managed", "path": "/tmp/a", "sha256": "abc", "severity": "critical"}],
        "system_units": [],
        "user_units": [],
    }
    runtime_only = drift_state.classify_drift(
        expected,
        {
            "files": [{"id": "managed", "path": "/tmp/a", "exists": True, "sha256": "abc"}],
            "runtime_alerts": [{"scope": "system", "service": "grafana", "type": "unhealthy"}],
            "packages": {"unmanaged": [], "missing": [], "orphans": []},
        },
    )
    config_and_runtime = drift_state.classify_drift(
        expected,
        {
            "files": [{"id": "managed", "path": "/tmp/a", "exists": True, "sha256": "def"}],
            "runtime_alerts": [{"scope": "system", "service": "grafana", "type": "unhealthy"}],
            "packages": {"unmanaged": [], "missing": [], "orphans": []},
        },
    )

    assert runtime_only["status"] == "degraded"
    assert config_and_runtime["status"] == "drifted"
