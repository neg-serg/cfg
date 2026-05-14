import json
import os
import sys

SCRIPTS_DIR = os.path.join(os.path.dirname(__file__), "..", "scripts")
if SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, SCRIPTS_DIR)

from salt_impact import plan_for_changed_files  # noqa: E402


def test_single_sls_file():
    result = plan_for_changed_files(["states/foo.sls"])
    assert result["final_target"] == "foo"
    assert result["selected_states"] == ["foo"]
    assert result["fallback_reasons"] == []


def test_multiple_sls_files():
    result = plan_for_changed_files(["states/foo.sls", "states/bar.sls"])
    assert result["final_target"] == "system_description"
    assert result["selected_states"] == ["bar", "foo"]
    assert len(result["fallback_reasons"]) == 1
    assert "multiple workflow targets" in result["fallback_reasons"][0]


def test_shared_macros_jinja():
    result = plan_for_changed_files(["states/_imports.jinja"])
    assert result["final_target"] == "system_description"
    assert result["selected_states"] == []
    assert result["fallback_reasons"] == ["states/_imports.jinja is a shared imports"]


def test_shared_data_yaml():
    result = plan_for_changed_files(["states/data/hosts.yaml"])
    assert result["final_target"] == "system_description"
    assert result["selected_states"] == []
    assert result["fallback_reasons"] == ["states/data/hosts.yaml is a shared data input"]


def test_noop_paths_ignored():
    result = plan_for_changed_files([
        "scripts/foo.sh",
        "tests/test_thing.py",
        "docs/readme.md",
        "dotfiles/.bashrc",
        "specs/spec.yaml",
        ".specify/templates/foo.yaml",
    ])
    assert result["final_target"] == "none"
    assert result["selected_states"] == []
    assert result["fallback_reasons"] == []


def test_group_state_path():
    result = plan_for_changed_files(["states/group/desktop.sls"])
    assert result["final_target"] == "group/desktop"
    assert result["selected_states"] == ["group/desktop"]
    assert result["fallback_reasons"] == []


def test_empty_file_list():
    result = plan_for_changed_files([])
    assert result["final_target"] == "none"
    assert result["selected_states"] == []
    assert result["fallback_reasons"] == []
    assert result["changed_files"] == []


def test_mixed_noop_and_real_file():
    result = plan_for_changed_files(["scripts/foo.sh", "states/bar.sls"])
    assert result["final_target"] == "bar"
    assert result["selected_states"] == ["bar"]
    assert result["fallback_reasons"] == []


def test_owner_mapped_subdirectory():
    result = plan_for_changed_files(["states/desktop/apps.sls"])
    assert result["final_target"] == "desktop"
    assert result["selected_states"] == ["desktop"]
    assert result["fallback_reasons"] == []

    result2 = plan_for_changed_files(["states/video_ai/pipeline.sls"])
    assert result2["final_target"] == "video_ai"
    assert result2["selected_states"] == ["video_ai"]
    assert result2["fallback_reasons"] == []


def test_json_output_mode():
    result = plan_for_changed_files(["states/foo.sls"])
    dumped = json.dumps(result, indent=2)
    reloaded = json.loads(dumped)
    assert reloaded == result
    assert set(result.keys()) == {
        "changed_files", "selected_states", "fallback_reasons", "final_target",
    }
