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



# workflow removed; state-profiler gate tested in
# test_state_profiler_gate_statuses above.
