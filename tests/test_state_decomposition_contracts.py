"""Contract tests for decomposed state layout and recursive tooling coverage."""

import importlib.util
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def _load_module(name: str, relative_path: str):
    module_path = REPO_ROOT / relative_path
    spec = importlib.util.spec_from_file_location(name, module_path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_repo_discovery_preserves_nested_state_names_and_entrypoint_classification(monkeypatch):
    monkeypatch.chdir(REPO_ROOT)
    salt_source_model = _load_module("salt_source_model", "scripts/salt_source_model.py")

    records = salt_source_model.discover_state_files()
    by_relpath = {record.relpath: record for record in records}

    assert by_relpath["states/desktop.sls"].state_name == "desktop"
    assert by_relpath["states/desktop.sls"].top_level_entrypoint is True
    assert by_relpath["states/desktop/system.sls"].state_name == "desktop.system"
    assert by_relpath["states/desktop/system.sls"].top_level_entrypoint is False
    assert by_relpath["states/video_ai/base.sls"].state_name == "video_ai.base"
    assert by_relpath["states/video_ai/base.sls"].top_level_entrypoint is False


def test_repo_root_states_include_expected_thematic_children(monkeypatch):
    monkeypatch.chdir(REPO_ROOT)
    index_salt = _load_module("index_salt", "scripts/index-salt.py")

    state_results = index_salt.render_states(["states/desktop.sls", "states/video_ai.sls"])
    graph, _, _ = index_salt.build_state_graph(state_results)

    assert set(graph["desktop"]) >= {
        "desktop.system",
        "desktop.packages",
        "desktop.hyprland",
        "desktop.user",
    }
    assert set(graph["video_ai"]) >= {
        "video_ai.base",
        "video_ai.models",
        "video_ai.workflows",
        "video_ai.runners",
    }
