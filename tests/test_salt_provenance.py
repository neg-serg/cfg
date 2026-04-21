"""Tests for Salt provenance lookups."""

import importlib.util
import json

import pytest

from tests import REPO_ROOT_PATH


def _load_salt_provenance():
    module_path = REPO_ROOT_PATH / "scripts" / "salt_provenance.py"
    spec = importlib.util.spec_from_file_location("salt_provenance", module_path)
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
        lambda sls_files: calls.update({"render_states": list(sls_files)}) or [
            (
                "states/monitoring_loki.sls",
                ["loki_config", "loki_native_unit_absent"],
                ["services"],
                [("loki_config", "pkg: loki")],
                ["monitoring.loki"],
            )
        ],
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
            "{% import_yaml 'data/service_catalog.yaml' as catalog %}\n"
            "{{ catalog.loki.enabled }}\n"
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


def test_main_json_outputs_matches_for_supported_lookup_kinds(monkeypatch, capsys):
    salt_provenance = _load_salt_provenance()
    monkeypatch.setattr(
        salt_provenance,
        "build_reverse_index",
        lambda: _make_index(salt_provenance),
    )

    monkeypatch.setattr(
        salt_provenance.sys,
        "argv",
        ["salt_provenance.py", "--state-id", "loki_config", "--json"],
    )

    with pytest.raises(SystemExit) as exc_info:
        salt_provenance.main()

    captured = capsys.readouterr()
    assert exc_info.value.code == 0
    assert json.loads(captured.out) == {
        "query": {"kind": "state_id", "value": "loki_config"},
        "matches": [
            {
                "feature_guards": ["monitoring.loki"],
                "imported_yaml": ["data/service_catalog.yaml"],
                "includes": ["services"],
                "relpath": "states/monitoring_loki.sls",
                "state_ids": ["loki_config", "loki_native_unit_absent"],
                "state_name": "monitoring_loki",
                "top_level_entrypoint": True,
                "workflow_apply_target": True,
            }
        ],
    }
    assert captured.err == ""


def test_main_json_reports_not_found_with_controlled_exit(monkeypatch, capsys):
    salt_provenance = _load_salt_provenance()
    monkeypatch.setattr(
        salt_provenance,
        "build_reverse_index",
        lambda: _make_index(salt_provenance),
    )

    monkeypatch.setattr(
        salt_provenance.sys,
        "argv",
        ["salt_provenance.py", "--data-key", "service_catalog.missing", "--json"],
    )

    with pytest.raises(SystemExit) as exc_info:
        salt_provenance.main()

    captured = capsys.readouterr()
    assert exc_info.value.code == 1
    assert json.loads(captured.out) == {
        "query": {"kind": "data_key", "value": "service_catalog.missing"},
        "matches": [],
    }
    assert captured.err == ""


def test_justfile_exposes_provenance_shortcuts():
    justfile_source = (REPO_ROOT_PATH / "Justfile").read_text()

    assert 'provenance STATE:' in justfile_source
    assert '.venv/bin/python3 scripts/salt_provenance.py --state "{{STATE}}"' in justfile_source
    assert 'provenance-id STATE_ID:' in justfile_source
    assert (
        '.venv/bin/python3 scripts/salt_provenance.py --state-id "{{STATE_ID}}"'
        in justfile_source
    )
