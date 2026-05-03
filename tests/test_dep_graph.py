"""Tests for dep-graph requisite edge extraction."""

import importlib.util

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



