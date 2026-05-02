"""Tests for index-salt shared source model integration."""

import importlib.util
import sys

import yaml

from tests import REPO_ROOT_PATH, SCRIPTS_DIR


def _load_index_salt():
    module_path = REPO_ROOT_PATH / "scripts" / "index-salt.py"
    spec = importlib.util.spec_from_file_location("index_salt", module_path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_index_salt_imports_via_spec_without_scripts_on_sys_path(monkeypatch):
    monkeypatch.setattr(sys, "path", [entry for entry in sys.path if entry != SCRIPTS_DIR])
    sys.modules.pop("salt_source_model", None)

    index_salt = _load_index_salt()

    assert index_salt.render_states


def test_nested_state_outputs_keep_canonical_dotted_names(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    index_salt = _load_index_salt()

    state_results = [
        (
            "states/desktop/system.sls",
            ["desktop-system-state"],
            ["desktop.packages"],
            [("desktop-system-state", "pkg: desktop-base")],
            ["desktop"],
        ),
        ("states/system_description.sls", ["root-state"], ["desktop.system"], [], []),
    ]

    states_md = index_salt.generate_states_md(state_results)
    graph, reverse, guards_map = index_salt.build_state_graph(state_results)

    assert "## desktop.system" in states_md
    assert "\n## system\n" not in states_md
    assert graph["desktop.system"] == ["desktop.packages"]
    assert reverse["desktop.system"] == ["system_description"]
    assert guards_map["desktop.system"] == ["desktop"]


def test_write_knowledge_base_keeps_canonical_dotted_state_names(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    memory_dir = tmp_path / "memory"
    memory_dir.mkdir()
    index_salt = _load_index_salt()
    monkeypatch.setattr(index_salt, "MEMORY_DIR", str(memory_dir))

    index_salt.write_knowledge_base(
        [],
        [
            (
                "states/desktop/system.sls",
                ["desktop-system-state"],
                ["desktop.packages"],
                [],
                [],
            )
        ],
        [],
    )

    knowledge_base = yaml.safe_load((memory_dir / "salt-knowledge.yaml").read_text())

    states = [s for s in knowledge_base.get("states", [])]
    assert any(s["name"] == "desktop.system" for s in states)
    assert all(s["name"] != "system" for s in states)
