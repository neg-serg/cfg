"""Tests for Salt provenance lookups."""

import importlib.util
import json
import stat
import textwrap
from pathlib import Path
from types import SimpleNamespace

import pytest

from tests import REPO_ROOT_PATH


def _write_executable(path: Path, content: str) -> None:
    path.write_text(textwrap.dedent(content).lstrip())
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


def _load_salt_provenance():
    module_path = REPO_ROOT_PATH / "scripts" / "salt_provenance.py"
    spec = importlib.util.spec_from_file_location("salt_provenance", module_path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _load_render_matrix():
    module_path = REPO_ROOT_PATH / "scripts" / "render-matrix.py"
    spec = importlib.util.spec_from_file_location("render_matrix", module_path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _load_salt_debug_report():
    module_path = REPO_ROOT_PATH / "scripts" / "salt_debug_report.py"
    spec = importlib.util.spec_from_file_location("salt_debug_report", module_path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _make_index(provenance):
    record = provenance.StateProvenanceRecord(
        state_name="monitoring_loki",
        relpath="states/monitoring_loki.sls",
        top_level_entrypoint=True,
        workflow_apply_target=True,
        state_ids=["loki_config", "loki_native_unit_absent"],
        includes=["services"],
        requires=[("loki_config", "pkg: loki")],
        feature_guards=["monitoring.loki"],
        imported_yaml=["data/service_catalog.yaml"],
    )
    return provenance.ReverseIndex(
        states_by_name={record.state_name: record},
        states_by_id={"loki_config": [record]},
        data_files={
            "states/data/service_catalog.yaml": {
                "consumers": [record],
                "keys": ["service_catalog.loki", "service_catalog.promtail"],
            }
        },
    )


def test_build_reverse_index_reuses_existing_discovery_render_and_data_usage(monkeypatch):
    salt_provenance = _load_salt_provenance()
    state_record = salt_provenance._source_model_module.StateFileRecord(
        relpath="states/monitoring_loki.sls",
        state_name="monitoring_loki",
        top_level_entrypoint=True,
        workflow_apply_target=True,
        source_text="{% import_yaml 'data/service_catalog.yaml' as catalog %}",
    )
    calls = {}

    monkeypatch.setattr(
        salt_provenance._source_model_module,
        "discover_state_files",
        lambda _states_dir="states": [state_record],
    )
    monkeypatch.setattr(
        salt_provenance._index_module,
        "render_states",
        lambda sls_files: (
            calls.update({"render_states": list(sls_files)})
            or [
                (
                    "states/monitoring_loki.sls",
                    ["loki_config", "loki_native_unit_absent"],
                    ["services"],
                    [("loki_config", "pkg: loki")],
                    ["monitoring.loki"],
                )
            ]
        ),
    )
    monkeypatch.setattr(
        salt_provenance._index_module,
        "collect_data_usage",
        lambda: {"states/data/service_catalog.yaml": ["monitoring_loki.sls"]},
    )

    reverse_index = salt_provenance.build_reverse_index()

    assert calls["render_states"] == ["states/monitoring_loki.sls"]
    assert reverse_index.states_by_name["monitoring_loki"].imported_yaml == [
        "data/service_catalog.yaml"
    ]
    assert reverse_index.lookup_state("monitoring_loki").state_ids == [
        "loki_config",
        "loki_native_unit_absent",
    ]
    assert [record.state_name for record in reverse_index.lookup_state_id("loki_config")] == [
        "monitoring_loki"
    ]
    data_file_match = reverse_index.lookup_data_file("states/data/service_catalog.yaml")
    assert data_file_match["data_file"] == "states/data/service_catalog.yaml"
    assert [record.state_name for record in data_file_match["consumers"]] == ["monitoring_loki"]
    data_key_match = reverse_index.lookup_data_key("service_catalog.loki")
    assert data_key_match["data_file"] == "states/data/service_catalog.yaml"
    assert [record.state_name for record in data_key_match["consumers"]] == ["monitoring_loki"]


def test_lookup_data_key_prefers_source_level_matches_over_file_level_consumers(monkeypatch):
    salt_provenance = _load_salt_provenance()
    loki_record = salt_provenance._source_model_module.StateFileRecord(
        relpath="states/monitoring_loki.sls",
        state_name="monitoring_loki",
        top_level_entrypoint=True,
        workflow_apply_target=True,
        source_text=(
            "{% import_yaml 'data/service_catalog.yaml' as catalog %}\n{{ catalog.loki.enabled }}\n"
        ),
    )
    promtail_record = salt_provenance._source_model_module.StateFileRecord(
        relpath="states/monitoring_promtail.sls",
        state_name="monitoring_promtail",
        top_level_entrypoint=True,
        workflow_apply_target=True,
        source_text=(
            "{% import_yaml 'data/service_catalog.yaml' as catalog %}\n"
            "{{ catalog.promtail.enabled }}\n"
        ),
    )

    monkeypatch.setattr(
        salt_provenance._source_model_module,
        "discover_state_files",
        lambda _states_dir="states": [loki_record, promtail_record],
    )
    monkeypatch.setattr(
        salt_provenance._index_module,
        "render_states",
        lambda sls_files: [
            ("states/monitoring_loki.sls", ["loki_config"], [], [], []),
            ("states/monitoring_promtail.sls", ["promtail_config"], [], [], []),
        ],
    )
    monkeypatch.setattr(
        salt_provenance._index_module,
        "collect_data_usage",
        lambda: {
            "states/data/service_catalog.yaml": [
                "monitoring_loki.sls",
                "monitoring_promtail.sls",
            ]
        },
    )

    reverse_index = salt_provenance.build_reverse_index()

    data_key_match = reverse_index.lookup_data_key("service_catalog.loki")

    assert data_key_match["data_file"] == "states/data/service_catalog.yaml"
    assert [record.state_name for record in data_key_match["consumers"]] == ["monitoring_loki"]


def test_main_json_outputs_macro_matches_and_not_found_exit(monkeypatch, capsys):
    salt_provenance = _load_salt_provenance()
    macro_consumer = salt_provenance.StateProvenanceRecord(
        state_name="monitoring_loki",
        relpath="states/monitoring_loki.sls",
        top_level_entrypoint=True,
        workflow_apply_target=True,
        state_ids=["loki_config"],
        includes=[],
        requires=[],
        feature_guards=[],
        imported_yaml=[],
    )
    reverse_index = salt_provenance.ReverseIndex(
        states_by_name={macro_consumer.state_name: macro_consumer},
        states_by_id={},
        data_files={},
    )
    reverse_index.macro_calls = {"ensure_service": [macro_consumer]}
    monkeypatch.setattr(salt_provenance, "build_reverse_index", lambda: reverse_index)

    monkeypatch.setattr(
        salt_provenance.sys,
        "argv",
        ["salt_provenance.py", "--macro", "ensure_service", "--json"],
    )

    with pytest.raises(SystemExit) as exc_info:
        salt_provenance.main()

    captured = capsys.readouterr()
    assert exc_info.value.code == 0
    assert json.loads(captured.out) == {
        "query": {"kind": "macro", "value": "ensure_service"},
        "matches": [
            {
                "feature_guards": [],
                "imported_yaml": [],
                "includes": [],
                "relpath": "states/monitoring_loki.sls",
                "state_ids": ["loki_config"],
                "state_name": "monitoring_loki",
                "top_level_entrypoint": True,
                "workflow_apply_target": True,
            }
        ],
    }
    assert captured.err == ""

    monkeypatch.setattr(
        salt_provenance.sys,
        "argv",
        ["salt_provenance.py", "--macro", "missing_macro", "--json"],
    )

    with pytest.raises(SystemExit) as exc_info:
        salt_provenance.main()

    captured = capsys.readouterr()
    assert exc_info.value.code == 1
    assert json.loads(captured.out) == {
        "query": {"kind": "macro", "value": "missing_macro"},
        "matches": [],
    }
    assert captured.err == ""


def test_build_reverse_index_supports_macro_lookup_from_source_text(monkeypatch):
    salt_provenance = _load_salt_provenance()
    macro_record = salt_provenance._source_model_module.StateFileRecord(
        relpath="states/monitoring_loki.sls",
        state_name="monitoring_loki",
        top_level_entrypoint=True,
        workflow_apply_target=True,
        source_text=(
            "{{ ensure_service(service.get('name')) }}\n"
            "{% for name, value in grains.items() %}{{ name }}={{ value }}{% endfor %}\n"
        ),
    )

    monkeypatch.setattr(
        salt_provenance._source_model_module,
        "discover_state_files",
        lambda _states_dir="states": [macro_record],
    )
    monkeypatch.setattr(
        salt_provenance._index_module,
        "render_states",
        lambda sls_files: [("states/monitoring_loki.sls", ["loki_config"], [], [], [])],
    )
    monkeypatch.setattr(salt_provenance._index_module, "collect_data_usage", lambda: {})
    monkeypatch.setattr(
        salt_provenance._index_module,
        "parse_macros",
        lambda jinja_files: [("ensure_service", "name", "states/_macros_service.jinja", "")],
    )

    reverse_index = salt_provenance.build_reverse_index()

    assert [record.state_name for record in reverse_index.lookup_macro("ensure_service")] == [
        "monitoring_loki"
    ]
    assert reverse_index.lookup_macro("get") == []
    assert reverse_index.lookup_macro("items") == []


def test_main_writes_default_debug_bundle_on_unexpected_lookup_failure(monkeypatch, tmp_path):
    salt_provenance = _load_salt_provenance()
    monkeypatch.chdir(tmp_path)
    monkeypatch.delenv("SALT_DEBUG_REPORT_DIR", raising=False)
    monkeypatch.setattr(
        salt_provenance,
        "build_reverse_index",
        lambda: (_ for _ in ()).throw(RuntimeError("index exploded")),
    )
    monkeypatch.setattr(
        salt_provenance.sys,
        "argv",
        ["salt_provenance.py", "--state", "monitoring_loki", "--json"],
    )

    with pytest.raises(SystemExit) as exc_info:
        salt_provenance.main()

    bundles = sorted((tmp_path / "logs" / "debug").glob("*.json"))

    assert exc_info.value.code == 1
    assert len(bundles) == 1
    assert json.loads(bundles[0].read_text()) == {
        "tool": "salt-provenance",
        "state": "monitoring_loki",
        "failure_stage": "lookup",
        "error": "index exploded",
    }


def test_main_writes_override_debug_bundle_on_unexpected_query_failure(monkeypatch, tmp_path):
    salt_provenance = _load_salt_provenance()
    debug_dir = tmp_path / "custom-debug"

    reverse_index = _make_index(salt_provenance)

    def _boom(_data_key):
        raise RuntimeError("lookup exploded")

    monkeypatch.setattr(reverse_index, "lookup_data_key", _boom)
    monkeypatch.setattr(salt_provenance, "build_reverse_index", lambda: reverse_index)
    monkeypatch.setenv("SALT_DEBUG_REPORT_DIR", str(debug_dir))
    monkeypatch.setattr(
        salt_provenance.sys,
        "argv",
        ["salt_provenance.py", "--data-key", "service_catalog.loki", "--json"],
    )

    with pytest.raises(SystemExit) as exc_info:
        salt_provenance.main()

    bundles = sorted(debug_dir.glob("*.json"))

    assert exc_info.value.code == 1
    assert len(bundles) == 1
    assert json.loads(bundles[0].read_text()) == {
        "tool": "salt-provenance",
        "data_key": "service_catalog.loki",
        "failure_stage": "lookup",
        "error": "lookup exploded",
    }


def test_render_matrix_failure_writes_debug_bundle(monkeypatch, tmp_path):
    render_matrix = _load_render_matrix()
    debug_dir = tmp_path / "logs" / "debug"
    records = [
        SimpleNamespace(
            relpath="states/entry.sls",
            state_name="entry",
            top_level_entrypoint=True,
            imported_yaml=["data/example.yaml"],
            feature_guards=["demo.enabled"],
        )
    ]

    monkeypatch.setattr(render_matrix, "load_matrix", lambda: [{"name": "demo"}])
    monkeypatch.setattr(render_matrix, "_make_render_env", lambda: object())
    monkeypatch.setattr(render_matrix, "_discover_render_state_records", lambda: records)
    monkeypatch.setattr(
        render_matrix,
        "render_for_scenario",
        lambda _env, _scenario_name, _sls_files: [("states/entry.sls", RuntimeError("boom"))],
    )
    monkeypatch.setenv("SALT_DEBUG_REPORT_DIR", str(debug_dir))

    results = render_matrix.render_all_states()
    bundles = sorted(debug_dir.glob("*.json"))

    assert results[0]["success"] is False
    assert len(bundles) == 1

    payload = json.loads(bundles[0].read_text())

    assert payload["tool"] == "render-matrix"
    assert payload["state"] == "entry"
    assert payload["scenario"] == "demo"
    assert payload["entrypoint"] is True
    assert payload["include_chain"] == []
    assert payload["imported_yaml"] == ["data/example.yaml"]
    assert payload["feature_guards"] == ["demo.enabled"]
    assert payload["failure_stage"] == "render"
    assert payload["error"] == "boom"


def test_salt_debug_report_main_outputs_matching_bundles(monkeypatch, tmp_path, capsys):
    salt_debug_report = _load_salt_debug_report()
    debug_dir = tmp_path / "logs" / "debug"
    debug_dir.mkdir(parents=True)
    bundle = {
        "tool": "render-matrix",
        "state": "entry",
        "scenario": "demo",
        "error": "boom",
    }
    other_bundle = {
        "tool": "render-matrix",
        "state": "other",
        "scenario": "demo",
        "error": "other boom",
    }
    (debug_dir / "20260421T010101000000Z-render-matrix-entry-demo.json").write_text(
        json.dumps(bundle)
    )
    (debug_dir / "20260421T010102000000Z-render-matrix-other-demo.json").write_text(
        json.dumps(other_bundle)
    )

    monkeypatch.setenv("SALT_DEBUG_REPORT_DIR", str(debug_dir))
    monkeypatch.setattr(
        salt_debug_report.sys,
        "argv",
        ["salt_debug_report.py", "--state", "entry", "--scenario", "demo"],
    )

    with pytest.raises(SystemExit) as exc_info:
        salt_debug_report.main()

    captured = capsys.readouterr()
    assert exc_info.value.code == 0
    assert json.loads(captured.out) == [bundle]
    assert captured.err == ""


def test_salt_debug_report_main_returns_empty_list_and_exit_1_for_no_matches(
    monkeypatch, tmp_path, capsys
):
    salt_debug_report = _load_salt_debug_report()
    debug_dir = tmp_path / "logs" / "debug"
    debug_dir.mkdir(parents=True)
    bundle = {
        "tool": "render-matrix",
        "state": "entry",
        "scenario": "demo",
        "error": "boom",
    }
    (debug_dir / "20260421T010101000000Z-render-matrix-entry-demo.json").write_text(
        json.dumps(bundle)
    )

    monkeypatch.setenv("SALT_DEBUG_REPORT_DIR", str(debug_dir))
    monkeypatch.setattr(
        salt_debug_report.sys,
        "argv",
        ["salt_debug_report.py", "--state", "missing"],
    )

    with pytest.raises(SystemExit) as exc_info:
        salt_debug_report.main()

    captured = capsys.readouterr()
    assert exc_info.value.code == 1
    assert json.loads(captured.out) == []
    assert captured.err == ""


def test_salt_debug_report_main_outputs_semantic_scenario_diff(monkeypatch, tmp_path, capsys):
    salt_debug_report = _load_salt_debug_report()
    debug_dir = tmp_path / "logs" / "debug"
    debug_dir.mkdir(parents=True)
    bundle = {
        "tool": "render-matrix",
        "state": "entry",
        "scenario": "lint-full",
        "failure_stage": "render",
        "error": "boom",
    }
    (debug_dir / "20260421T010101000000Z-render-matrix-entry-lint-full.json").write_text(
        json.dumps(bundle)
    )

    monkeypatch.setenv("SALT_DEBUG_REPORT_DIR", str(debug_dir))
    monkeypatch.setattr(
        salt_debug_report.sys,
        "argv",
        [
            "salt_debug_report.py",
            "--state",
            "entry",
            "--scenario",
            "lint-full",
            "--compare-scenario",
            "lint-desktop",
        ],
    )

    with pytest.raises(SystemExit) as exc_info:
        salt_debug_report.main()

    captured = capsys.readouterr()
    assert exc_info.value.code == 0
    assert json.loads(captured.out) == {
        "state": "entry",
        "scenario": "lint-full",
        "compare_scenario": "lint-desktop",
        "scenario_bundle_present": True,
        "compare_scenario_bundle_present": False,
        "scenario_has_failure": True,
        "compare_scenario_has_failure": False,
        "bundle_presence_changed": True,
        "failure_changed": True,
    }
    assert captured.err == ""
