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


def test_plan_changed_files_maps_video_ai_nested_domain_to_owner():
    salt_impact = _load_salt_impact()

    plan = salt_impact.plan_for_changed_files(["states/video_ai/invokeai.sls"])

    assert plan["selected_states"] == ["video_ai"]
    assert plan["final_target"] == "video_ai"


def test_plan_changed_files_falls_back_for_shared_macro():
    salt_impact = _load_salt_impact()

    plan = salt_impact.plan_for_changed_files(["states/_macros_service.jinja"])

    assert plan["selected_states"] == []
    assert plan["final_target"] == "system_description"
    assert plan["fallback_reasons"] == [
        "states/_macros_service.jinja is a shared macro input"
    ]


def test_plan_changed_files_falls_back_for_multiple_conflicting_targets():
    salt_impact = _load_salt_impact()

    plan = salt_impact.plan_for_changed_files([
        "states/services.sls",
        "states/desktop/system.sls",
    ])

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


def test_main_text_includes_selected_states_section_when_empty(monkeypatch, capsys):
    salt_impact = _load_salt_impact()
    monkeypatch.setattr(
        salt_impact,
        "plan_for_changed_files",
        lambda changed_files: {
            "changed_files": list(changed_files),
            "selected_states": [],
            "fallback_reasons": ["states/_imports.jinja has no safe workflow target mapping"],
            "final_target": "system_description",
        },
    )
    monkeypatch.setattr(
        salt_impact.sys,
        "argv",
        ["salt_impact.py", "--files", "states/_imports.jinja"],
    )

    with pytest.raises(SystemExit):
        salt_impact.main()

    captured = capsys.readouterr()
    assert "Selected states:\n- none\nFallback reasons:" in captured.out


def test_main_text_includes_fallback_section_when_empty(monkeypatch, capsys):
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
        ["salt_impact.py", "--files", "states/services.sls"],
    )

    with pytest.raises(SystemExit):
        salt_impact.main()

    captured = capsys.readouterr()
    assert "Selected states:\n- services\nFallback reasons:\n- none" in captured.out


def test_plan_changed_files_falls_back_for_unknown_state_owned_file():
    salt_impact = _load_salt_impact()

    plan = salt_impact.plan_for_changed_files(["states/_imports.jinja"])

    assert plan["selected_states"] == []
    assert plan["final_target"] == "system_description"
    assert plan["fallback_reasons"] == [
        "states/_imports.jinja has no safe workflow target mapping"
    ]
