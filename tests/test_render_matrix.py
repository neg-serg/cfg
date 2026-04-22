"""Tests for render-matrix state discovery."""

import importlib.util
import json
from types import SimpleNamespace

from tests import REPO_ROOT_PATH


def _load_render_matrix():
    module_path = REPO_ROOT_PATH / "scripts" / "render-matrix.py"
    spec = importlib.util.spec_from_file_location("render_matrix", module_path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_render_all_states_uses_source_model_top_level_entrypoints(monkeypatch):
    render_matrix = _load_render_matrix()
    records = [
        SimpleNamespace(
            relpath="states/entry.sls",
            state_name="entry",
            top_level_entrypoint=True,
            imported_yaml=[],
        ),
        SimpleNamespace(
            relpath="states/nested/child.sls",
            state_name="nested.child",
            top_level_entrypoint=False,
            imported_yaml=[],
        ),
    ]
    captured = []

    monkeypatch.setattr(render_matrix, "load_matrix", lambda: [{"name": "demo"}])
    monkeypatch.setattr(render_matrix, "_make_render_env", lambda: object())
    monkeypatch.setattr(render_matrix, "_discover_render_state_records", lambda: [records[0]])

    def _render_for_scenario(_env, _scenario_name, sls_files):
        captured.append(list(sls_files))
        return []

    monkeypatch.setattr(render_matrix, "render_for_scenario", _render_for_scenario)

    results = render_matrix.render_all_states()

    assert captured == [["states/entry.sls"]]
    assert results == [
        {
            "file": "states/entry.sls",
            "state": "entry",
            "scenario": "demo",
            "entrypoint": True,
            "success": True,
            "error": None,
            "error_stage": None,
            "imported_yaml": [],
        }
    ]


def test_render_all_states_includes_source_model_metadata(monkeypatch):
    render_matrix = _load_render_matrix()
    records = [
        SimpleNamespace(
            relpath="states/entry.sls",
            state_name="entry",
            top_level_entrypoint=True,
            imported_yaml=["states/data/example.yaml"],
        ),
    ]

    monkeypatch.setattr(render_matrix, "load_matrix", lambda: [{"name": "demo"}])
    monkeypatch.setattr(render_matrix, "_make_render_env", lambda: object())
    monkeypatch.setattr(render_matrix, "_discover_render_state_records", lambda: records)
    monkeypatch.setattr(
        render_matrix,
        "render_for_scenario",
        lambda _env, _scenario_name, _sls_files: [("states/entry.sls", RuntimeError("boom"))],
    )

    results = render_matrix.render_all_states()

    assert results == [
        {
            "file": "states/entry.sls",
            "state": "entry",
            "scenario": "demo",
            "entrypoint": True,
            "success": False,
            "error": "boom",
            "error_stage": "render",
            "imported_yaml": ["states/data/example.yaml"],
        }
    ]


def test_main_json_outputs_render_results(monkeypatch, capsys):
    render_matrix = _load_render_matrix()
    payload = [
        {
            "file": "states/entry.sls",
            "state": "entry",
            "scenario": "demo",
            "entrypoint": True,
            "success": True,
            "error": None,
            "error_stage": None,
            "imported_yaml": [],
        }
    ]

    monkeypatch.setattr(render_matrix, "render_all_states", lambda: payload)

    render_matrix.main(["--json"])

    assert json.loads(capsys.readouterr().out) == payload
