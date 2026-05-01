"""Contract tests for service helper guardrails and performance gate wiring."""

import importlib.util

from tests import REPO_ROOT_PATH


def _load_state_profiler():
    module_path = REPO_ROOT_PATH / "scripts" / "state-profiler.py"
    spec = importlib.util.spec_from_file_location("state_profiler_module", module_path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_services_macro_exposes_config_replace_helper():
    source = (REPO_ROOT_PATH / "states" / "_macros_service.jinja").read_text()

    assert "macro container_service" in source
    assert "service.dead:" in source
    assert "service.running:" in source


def test_services_sls_no_longer_has_transmission_escape_hatch():
    source = (REPO_ROOT_PATH / "states" / "services.sls").read_text()

    # Transmission migrated to Quadlet — escape hatch (ACLs + config replacement) removed
    assert "transmission_acl_setup" not in source
    assert "transmission_settings" not in source
    assert "config_replace_with_service_control" not in source


def test_state_profiler_gate_statuses():
    state_profiler = _load_state_profiler()

    assert state_profiler.evaluate_compare_gate([], min_sample_count=1)[0] == "INCONCLUSIVE"
    assert (
        state_profiler.evaluate_compare_gate(
            [{"state_id": "fast", "regression": False}], min_sample_count=1
        )[0]
        == "PASS"
    )
    assert (
        state_profiler.evaluate_compare_gate(
            [{"state_id": "slow", "regression": True}], min_sample_count=1
        )[0]
        == "FAIL"
    )


def test_state_profiler_compare_rows_honor_threshold(tmp_path):
    state_profiler = _load_state_profiler()
    baseline = tmp_path / "baseline.log"
    candidate = tmp_path / "candidate.log"
    baseline.write_text(
        "Name: fast_state - Function: test.nop - Duration: 100 ms\n"
        "Name: slow_state - Function: test.nop - Duration: 100 ms\n"
    )
    candidate.write_text(
        "Name: fast_state - Function: test.nop - Duration: 110 ms\n"
        "Name: slow_state - Function: test.nop - Duration: 140 ms\n"
    )

    rows = state_profiler.build_compare_rows(baseline, candidate, max_regression_pct=20.0)
    by_state = {row["state_id"]: row for row in rows}

    assert by_state["fast_state"]["regression"] is False
    assert by_state["slow_state"]["regression"] is True


def test_state_profiler_build_state_metadata_uses_canonical_discovery(monkeypatch):
    state_profiler = _load_state_profiler()

    class _Record:
        def __init__(self, relpath, state_name, source_text):
            self.relpath = relpath
            self.state_name = state_name
            self.source_text = source_text

    discovered = [
        _Record(
            "states/root.sls",
            "root",
            "include:\n  - nested.child\nroot-id:\n  test.nop: []\n",
        ),
        _Record(
            "states/nested/child.sls",
            "nested.child",
            "nested-id:\n  test.nop: []\n",
        ),
    ]
    render_calls = []

    monkeypatch.setattr(
        state_profiler,
        "discover_state_files",
        lambda states_dir="states": discovered,
    )
    monkeypatch.setattr(
        state_profiler._index_module,
        "render_states",
        lambda sls_files: (
            render_calls.append(list(sls_files))
            or [
                ("states/root.sls", ["root-id"], ["nested.child"], [], []),
                ("states/nested/child.sls", ["nested-id"], [], [], []),
            ]
        ),
    )
    monkeypatch.setattr(
        state_profiler._index_module,
        "build_state_graph",
        lambda state_results: ({"root": ["nested.child"], "nested.child": []}, {}, {}),
    )

    state_files, include_paths, text_map, file_contents = state_profiler.build_state_metadata(
        "root"
    )

    assert render_calls == [["states/root.sls", "states/nested/child.sls"]]
    assert include_paths["nested.child"] == ["root", "nested.child"]
    assert text_map["nested-id"] == "nested.child"
    assert file_contents["nested.child"].startswith("nested-id:")


# workflow removed; state-profiler gate tested in
# test_state_profiler_gate_statuses above.
