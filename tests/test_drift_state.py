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


def test_fast_mode_collect_skips_package_scan_and_runtime_alerts(monkeypatch):
    called = []

    def mock_pkg_drift(*args, **kwargs):
        called.append("pkg")
        return {"unmanaged": ["stray"], "missing": [], "orphans": []}

    def mock_load_runtime(*args, **kwargs):
        called.append("runtime")
        return [{"scope": "user", "service": "x", "type": "unhealthy"}]

    monkeypatch.setattr(drift_state, "run_pkg_drift", mock_pkg_drift)
    monkeypatch.setattr(drift_state, "load_runtime_alerts", mock_load_runtime)

    result = drift_state.collect_actual_snapshot(
        "/nonexistent",
        "/nonexistent",
        {"files": [], "system_units": [], "user_units": []},
        mode="fast",
    )

    assert called == [], "run_pkg_drift and load_runtime_alerts should NOT be called in fast mode"
    assert result["packages"] == {"unmanaged": [], "missing": [], "orphans": []}
    assert result["runtime_alerts"] == []


def test_full_mode_collect_includes_package_scan_and_runtime_alerts(monkeypatch):
    called = []

    def mock_pkg_drift(*args, **kwargs):
        called.append("pkg")
        return {"unmanaged": ["stray"], "missing": [], "orphans": []}

    def mock_load_runtime(*args, **kwargs):
        called.append("runtime")
        return [{"scope": "user", "service": "x", "type": "unhealthy"}]

    monkeypatch.setattr(drift_state, "run_pkg_drift", mock_pkg_drift)
    monkeypatch.setattr(drift_state, "load_runtime_alerts", mock_load_runtime)

    result = drift_state.collect_actual_snapshot(
        "/nonexistent",
        "/nonexistent",
        {"files": [], "system_units": [], "user_units": []},
        mode="full",
    )

    assert "pkg" in called, "run_pkg_drift should be called in full mode"
    assert "runtime" in called, "load_runtime_alerts should be called in full mode"
    assert result["packages"] == {"unmanaged": ["stray"], "missing": [], "orphans": []}
    assert result["runtime_alerts"] == [{"scope": "user", "service": "x", "type": "unhealthy"}]


def test_maintenance_lock_suppresses_drift_to_degraded(tmp_path):
    lock_file = tmp_path / "maintenance.lock"
    lock_file.write_text("")

    expected = {
        "files": [{"id": "x", "path": "/tmp/a", "sha256": "abc", "severity": "critical"}],
        "system_units": [],
        "user_units": [],
    }
    actual = {
        "files": [{"id": "x", "path": "/tmp/a", "exists": True, "sha256": "def"}],
        "packages": {"unmanaged": ["stray"], "missing": [], "orphans": []},
        "system_units": [],
        "user_units": [],
        "runtime_alerts": [],
    }

    payload = drift_state.classify_drift(expected, actual, maintenance_lock_path=str(lock_file))

    assert payload["status"] != "drifted", "should not report drifted during maintenance"
    assert all(r["severity"] == "info" for r in payload["records"]), (
        "all records should be info severity during maintenance"
    )


def test_drift_records_include_source_field():
    expected = {
        "generated_at": "2026-04-17T00:00:00+00:00",
        "files": [{"id": "x", "path": "/tmp/a", "sha256": "abc", "severity": "critical"}],
        "system_units": [],
        "user_units": [],
    }
    actual = {
        "files": [{"id": "x", "path": "/tmp/a", "exists": True, "sha256": "def"}],
        "packages": {"unmanaged": [], "missing": ["req-pkg"], "orphans": []},
        "system_units": [
            {"name": "sshd", "enabled": False, "expected_enabled": True, "severity": "critical"}
        ],
        "user_units": [],
        "runtime_alerts": [],
    }

    payload = drift_state.classify_drift(expected, actual)

    for record in payload["records"]:
        assert "source" in record, f"record {record['category']}/{record['object']} missing source"


def test_build_expected_snapshot_includes_git_revision(monkeypatch, tmp_path):
    host = {"home": "/tmp", "runtime_dir": "/run/user/1000", "hostname": "testbox"}
    inventory = {"files": [], "system_units": [], "user_units": []}

    import subprocess as sp

    original_run = sp.run

    def mock_run(cmd, **kwargs):
        if cmd == ["git", "rev-parse", "--short", "HEAD"]:
            return type("Result", (), {"stdout": "abc123\n", "stderr": "", "returncode": 0})()
        return original_run(cmd, **kwargs)

    monkeypatch.setattr(drift_state.subprocess, "run", mock_run)

    snapshot = drift_state.build_expected_snapshot(host, inventory, project_dir=tmp_path)
    assert snapshot["git_revision"] == "abc123"


def test_build_expected_snapshot_includes_salt_target():
    host = {"home": "/tmp", "runtime_dir": "/run/user/1000", "hostname": "testbox"}
    inventory = {"files": [], "system_units": [], "user_units": []}

    snapshot = drift_state.build_expected_snapshot(host, inventory, salt_target="services")
    assert snapshot["salt_target"] == "services"


def test_build_expected_snapshot_skips_git_revision_when_not_a_repo(monkeypatch, tmp_path):
    host = {"home": "/tmp", "runtime_dir": "/run/user/1000", "hostname": "testbox"}
    inventory = {"files": [], "system_units": [], "user_units": []}

    import subprocess as sp

    def mock_run(cmd, **kwargs):
        if cmd[:3] == ["git", "rev-parse", "--short"]:
            res = {"stdout": "", "stderr": "fatal: not a git repo\n", "returncode": 128}
            return type("Result", (), res)()
        return sp.run(cmd, **kwargs)

    monkeypatch.setattr(drift_state.subprocess, "run", mock_run)

    snapshot = drift_state.build_expected_snapshot(host, inventory, project_dir=tmp_path)
    assert "git_revision" not in snapshot


def test_collect_actual_defaults_to_full_mode(monkeypatch):
    called = []

    def mock_pkg_drift(*args, **kwargs):
        called.append("pkg")
        return {"unmanaged": [], "missing": [], "orphans": []}

    monkeypatch.setattr(drift_state, "run_pkg_drift", mock_pkg_drift)
    monkeypatch.setattr(drift_state, "load_runtime_alerts", lambda *a, **kw: [])

    drift_state.collect_actual_snapshot(
        "/nonexistent",
        "/nonexistent",
        {"files": [], "system_units": [], "user_units": []},
    )

    assert "pkg" in called, "default mode should be full (include package scan)"
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


def test_gating_round_trip_expected_matches_actual_returns_ok():
    """Simulates the full gating pipeline: refresh-expected → collect → classify."""
    expected = {
        "generated_at": "2026-04-17T00:00:00+00:00",
        "hostname": "testbox",
        "git_revision": "abc123",
        "salt_target": "services",
        "files": [
            {"id": "cfg", "path": "/tmp/cfg.yaml", "severity": "critical", "sha256": "abc"},
        ],
        "system_units": [
            {"name": "sshd.service", "enabled": True, "severity": "critical"},
        ],
        "user_units": [
            {"name": "salt-monitor.service", "enabled": True, "severity": "info"},
        ],
    }
    actual = {
        "generated_at": "2026-04-17T00:00:00+00:00",
        "packages": {"unmanaged": [], "missing": [], "orphans": []},
        "files": [
            {"id": "cfg", "path": "/tmp/cfg.yaml", "exists": True, "sha256": "abc"},
        ],
        "system_units": [
            {
                "name": "sshd.service",
                "enabled": True,
                "masked": False,
                "load_state": "loaded",
                "active_state": "active",
                "expected_enabled": True,
                "severity": "critical",
            },
        ],
        "user_units": [
            {
                "name": "salt-monitor.service",
                "enabled": True,
                "masked": False,
                "load_state": "loaded",
                "active_state": "active",
                "expected_enabled": True,
                "severity": "info",
            },
        ],
        "runtime_alerts": [],
    }

    payload = drift_state.classify_drift(expected, actual)

    assert payload["status"] == "clean", f"expected clean, got {payload['status']}"
    assert payload["records"] == [], f"expected no records, got {payload['records']}"


def test_gating_round_trip_no_baseline_and_then_refreshed(tmp_path):
    """Simulates first-run (no baseline) then after refresh-expected both succeed."""
    cache_dir = tmp_path / "cache"
    cache_dir.mkdir()
    expected_path = cache_dir / "expected-snapshot.json"

    assert not expected_path.exists()

    host = {"home": "/tmp", "runtime_dir": "/run/user/1000", "hostname": "testbox"}
    inventory = {"files": [], "system_units": [], "user_units": []}

    snapshot = drift_state.build_expected_snapshot(host, inventory)
    drift_state.write_json(expected_path, snapshot)
    assert expected_path.exists()

    payload = drift_state.classify_drift(
        snapshot,
        {
            "packages": {"unmanaged": [], "missing": [], "orphans": []},
            "files": [],
            "system_units": [],
            "user_units": [],
            "runtime_alerts": [],
        },
    )
    assert payload["status"] == "clean"
