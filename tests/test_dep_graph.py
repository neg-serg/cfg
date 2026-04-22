"""Tests for dep-graph requisite edge extraction."""

import importlib.util
import json

from tests import REPO_ROOT_PATH


def _load_dep_graph():
    module_path = REPO_ROOT_PATH / "scripts" / "dep-graph.py"
    spec = importlib.util.spec_from_file_location("dep_graph", module_path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_collect_edges_converts_tuple_requisites_into_requisite_edges():
    dep_graph = _load_dep_graph()

    state_results = [
        (
            "states/example.sls",
            ["managed-file"],
            ["base"],
            [("managed-file", "pkg: deps")],
            [],
        )
    ]

    include_edges, requisite_edges = dep_graph.collect_edges(state_results)

    assert include_edges == [("example", "base")]
    assert requisite_edges == [("managed-file", "pkg: deps", "require")]


def test_collect_edges_preserves_legacy_dict_string_requisites():
    dep_graph = _load_dep_graph()

    state_results = [
        (
            "states/example.sls",
            ["managed-file"],
            [],
            [{"watch": ["service: daemon", {"pkg": "deps"}]}],
            [],
        )
    ]

    _, requisite_edges = dep_graph.collect_edges(state_results)

    assert requisite_edges == [
        ("example", "service: daemon", "watch"),
        ("example", "deps", "watch"),
    ]


def test_collect_edges_and_dot_keep_canonical_names_for_nested_states():
    dep_graph = _load_dep_graph()

    state_results = [
        (
            "states/system_description.sls",
            ["root-state"],
            ["desktop.system"],
            [],
            [],
        ),
        (
            "states/desktop/system.sls",
            ["desktop-system-state"],
            ["desktop.packages"],
            [],
            [],
        ),
    ]

    include_edges, requisite_edges = dep_graph.collect_edges(state_results)
    dot = dep_graph.generate_dot(include_edges, requisite_edges, state_results)

    assert include_edges == [
        ("system_description", "desktop.system"),
        ("desktop.system", "desktop.packages"),
    ]
    assert '  "desktop.system";' in dot
    assert '  "system";' not in dot
    assert '  "desktop.system" -> "desktop.packages" [label="include", color="#333333"];' in dot


def test_main_uses_canonical_discovery_and_only_renders_top_level_entrypoints(monkeypatch, capsys):
    dep_graph = _load_dep_graph()

    records = [
        dep_graph._source_model_module.StateFileRecord(
            relpath="states/system_description.sls",
            state_name="system_description",
            top_level_entrypoint=True,
            workflow_apply_target=True,
            source_text="",
        ),
        dep_graph._source_model_module.StateFileRecord(
            relpath="states/group/ai.sls",
            state_name="group.ai",
            top_level_entrypoint=False,
            workflow_apply_target=True,
            source_text="",
        ),
        dep_graph._source_model_module.StateFileRecord(
            relpath="states/desktop/system.sls",
            state_name="desktop.system",
            top_level_entrypoint=False,
            workflow_apply_target=False,
            source_text="",
        ),
    ]
    render_calls = []

    monkeypatch.setattr(
        dep_graph._source_model_module,
        "discover_state_files",
        lambda _states_dir="states": records,
    )
    monkeypatch.setattr(
        dep_graph._index_module,
        "render_states",
        lambda sls_files: render_calls.append(sls_files) or [],
    )
    monkeypatch.setattr(dep_graph, "generate_dot", lambda *_args: "digraph salt_states {}")
    monkeypatch.setattr(dep_graph, "detect_cycles", lambda _include_edges: [])
    monkeypatch.setattr(dep_graph.sys, "argv", ["dep-graph.py"])

    try:
        dep_graph.main()
    except SystemExit as exc:
        assert exc.code == 0

    captured = capsys.readouterr()

    assert render_calls == [["states/system_description.sls"]]
    assert captured.out == "digraph salt_states {}\n"
    assert captured.err == ""


def test_main_json_output_uses_structured_nodes_and_adds_state_names_from_edges(
    monkeypatch, capsys
):
    dep_graph = _load_dep_graph()

    records = [
        dep_graph._source_model_module.StateFileRecord(
            relpath="states/system_description.sls",
            state_name="system_description",
            top_level_entrypoint=True,
            workflow_apply_target=True,
            source_text="",
        ),
        dep_graph._source_model_module.StateFileRecord(
            relpath="states/desktop/system.sls",
            state_name="desktop.system",
            top_level_entrypoint=False,
            workflow_apply_target=False,
            source_text="",
        ),
        dep_graph._source_model_module.StateFileRecord(
            relpath="states/desktop/browser.sls",
            state_name="desktop.browser",
            top_level_entrypoint=False,
            workflow_apply_target=False,
            source_text="",
        ),
    ]
    state_results = [
        (
            "states/system_description.sls",
            ["root-state"],
            ["desktop.system"],
            [("root-state", "pkg: deps"), {"watch": ["desktop.browser", "service: daemon"]}],
            [],
        ),
    ]

    monkeypatch.setattr(
        dep_graph._source_model_module,
        "discover_state_files",
        lambda _states_dir="states": records,
    )
    monkeypatch.setattr(dep_graph._index_module, "render_states", lambda _sls_files: state_results)
    monkeypatch.setattr(dep_graph.sys, "argv", ["dep-graph.py", "--format", "json"])

    try:
        dep_graph.main()
    except SystemExit as exc:
        assert exc.code == 0

    captured = capsys.readouterr()
    payload = json.loads(captured.out)

    assert payload == {
        "nodes": [
            {"name": "desktop.browser"},
            {"name": "desktop.system"},
            {"name": "system_description"},
        ],
        "edges": [
            {
                "src_kind": "state",
                "src": "system_description",
                "dst_kind": "state",
                "dst": "desktop.system",
                "relation": "include",
            },
            {
                "src_kind": "state_id",
                "src": "root-state",
                "dst_kind": "requisite_target",
                "dst": "pkg: deps",
                "relation": "require",
            },
            {
                "src_kind": "state",
                "src": "system_description",
                "dst_kind": "requisite_target",
                "dst": "desktop.browser",
                "relation": "watch",
            },
            {
                "src_kind": "state",
                "src": "system_description",
                "dst_kind": "requisite_target",
                "dst": "service: daemon",
                "relation": "watch",
            },
        ],
        "cycles": [],
    }
    assert captured.err == ""
