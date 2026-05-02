import importlib.util
import json

import pytest

from tests import REPO_ROOT_PATH


def _load_salt_impact():
    module_path = REPO_ROOT_PATH / "scripts" / "salt_impact.py"
    spec = importlib.util.spec_from_file_location("salt_impact", module_path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_plan_changed_files_maps_top_level_state_directly():
    salt_impact = _load_salt_impact()

    plan = salt_impact.plan_for_changed_files(["states/services.sls"])

    assert plan == {
        "changed_files": ["states/services.sls"],
        "selected_states": ["services"],
        "fallback_reasons": [],
        "final_target": "services",
    }


def test_plan_changed_files_maps_group_targets_directly():
    salt_impact = _load_salt_impact()

    plan = salt_impact.plan_for_changed_files(["states/group/core.sls"])

    assert plan["selected_states"] == ["group/core"]
    assert plan["final_target"] == "group/core"


def test_plan_changed_files_maps_nested_domain_to_owner():
    salt_impact = _load_salt_impact()

    plan = salt_impact.plan_for_changed_files(["states/desktop/system.sls"])

    assert plan["selected_states"] == ["desktop"]
    assert plan["final_target"] == "desktop"


def test_plan_changed_files_falls_back_for_shared_macro():
    salt_impact = _load_salt_impact()

    plan = salt_impact.plan_for_changed_files(["states/_macros_service.jinja"])

    assert plan["selected_states"] == []
    assert plan["final_target"] == "system_description"
    assert plan["fallback_reasons"] == ["states/_macros_service.jinja is a shared macro input"]


def test_plan_changed_files_falls_back_for_multiple_conflicting_targets():
    salt_impact = _load_salt_impact()

    plan = salt_impact.plan_for_changed_files(
        [
            "states/services.sls",
            "states/desktop/system.sls",
        ]
    )

    assert sorted(plan["selected_states"]) == ["desktop", "services"]
    assert plan["final_target"] == "system_description"
    assert plan["fallback_reasons"] == [
        "changed files map to multiple workflow targets: desktop, services"
    ]


def test_main_json_outputs_plan_for_changed_files(monkeypatch, capsys):
    salt_impact = _load_salt_impact()
    monkeypatch.setattr(
        salt_impact,
        "plan_for_changed_files",
        lambda changed_files: {
            "changed_files": list(changed_files),
            "selected_states": ["services"],
            "fallback_reasons": [],
            "final_target": "services",
        },
    )
    monkeypatch.setattr(
        salt_impact.sys,
        "argv",
        ["salt_impact.py", "--files", "states/services.sls", "--json"],
    )

    with pytest.raises(SystemExit) as exc_info:
        salt_impact.main()

    captured = capsys.readouterr()
    assert exc_info.value.code == 0
    assert json.loads(captured.out) == {
        "changed_files": ["states/services.sls"],
        "selected_states": ["services"],
        "fallback_reasons": [],
        "final_target": "services",
    }
    assert captured.err == ""


def test_main_text_explains_fallback(monkeypatch, capsys):
    salt_impact = _load_salt_impact()
    monkeypatch.setattr(
        salt_impact,
        "plan_for_changed_files",
        lambda changed_files: {
            "changed_files": list(changed_files),
            "selected_states": [],
            "fallback_reasons": ["states/data/services.yaml is a shared data input"],
            "final_target": "system_description",
        },
    )
    monkeypatch.setattr(
        salt_impact.sys,
        "argv",
        ["salt_impact.py", "--files", "states/data/services.yaml"],
    )

    with pytest.raises(SystemExit) as exc_info:
        salt_impact.main()

    captured = capsys.readouterr()
    assert exc_info.value.code == 0
    assert "Final target: system_description" in captured.out
    assert "Fallback reasons:" in captured.out
    assert "states/data/services.yaml is a shared data input" in captured.out
    assert captured.err == ""


def test_main_writes_debug_bundle_and_exits_nonzero_on_unexpected_planning_failure(
    monkeypatch, tmp_path
):
    salt_impact = _load_salt_impact()
    debug_dir = tmp_path / "logs" / "debug"

    def _raise_boom(_changed_files):
        raise RuntimeError("boom")

    monkeypatch.setattr(salt_impact, "plan_for_changed_files", _raise_boom)
    monkeypatch.setattr(
        salt_impact.sys,
        "argv",
        ["salt_impact.py", "--files", "states/services.sls"],
    )
    monkeypatch.setenv("SALT_DEBUG_REPORT_DIR", str(debug_dir))

    with pytest.raises(SystemExit) as exc_info:
        salt_impact.main()

    bundles = sorted(debug_dir.glob("*.json"))

    assert exc_info.value.code == 1
    assert len(bundles) == 1
    payload = json.loads(bundles[0].read_text())
    assert payload == {
        "tool": "salt-impact",
        "state": "services",
        "failure_stage": "planning",
        "error": "boom",
    }


def test_plan_empty_files_list_falls_back():
    salt_impact = _load_salt_impact()

    plan = salt_impact.plan_for_changed_files([])

    assert plan["selected_states"] == []
    assert plan["final_target"] == "system_description"
    assert plan["fallback_reasons"] == ["no changed files mapped to a safe workflow target"]


def test_plan_normalizes_duplicate_paths():
    salt_impact = _load_salt_impact()

    plan = salt_impact.plan_for_changed_files(
        ["states/services.sls", "states/services.sls",
         "states/desktop/system.sls", "states/desktop/system.sls"]
    )

    assert plan["selected_states"] == ["desktop", "services"]
    # duplicates should not cause multiple-workflow-target fallback
    assert plan["final_target"] == "system_description"


def test_main_writes_auto_state_bundle_when_args_missing_on_unexpected_failure(
    monkeypatch, tmp_path
):
    salt_impact = _load_salt_impact()
    debug_dir = tmp_path / "logs" / "debug"

    class DummyParser:
        def parse_args(self, _argv):
            return BrokenNamespace()

    class BrokenNamespace:
        files = None
        as_json = False

    monkeypatch.setattr(salt_impact, "_build_parser", lambda: DummyParser())
    monkeypatch.setenv("SALT_DEBUG_REPORT_DIR", str(debug_dir))

    with pytest.raises(SystemExit) as exc_info:
        salt_impact.main()

    bundles = sorted(debug_dir.glob("*.json"))

    assert exc_info.value.code == 1
    assert len(bundles) == 1
    payload = json.loads(bundles[0].read_text())
    assert payload == {
        "tool": "salt-impact",
        "state": "auto",
        "failure_stage": "planning",
        "error": "'NoneType' object is not iterable",
    }
