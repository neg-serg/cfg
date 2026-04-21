#!/usr/bin/env python3
"""Generate dependency graph of Salt states (include/require/watch/onchanges)."""

import argparse
import importlib.util
import json
import os
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent

# Reuse index-salt.py rendering (same pattern as state-profiler.py)
_index_spec = importlib.util.spec_from_file_location(
    "index_salt_module", SCRIPTS_DIR / "index-salt.py"
)
if not _index_spec or not _index_spec.loader:
    raise ImportError("Cannot load index-salt.py")
_index_module = importlib.util.module_from_spec(_index_spec)
_index_spec.loader.exec_module(_index_module)

_source_model_spec = importlib.util.spec_from_file_location(
    "salt_source_model_module", SCRIPTS_DIR / "salt_source_model.py"
)
if not _source_model_spec or not _source_model_spec.loader:
    raise ImportError("Cannot load salt_source_model.py")
_source_model_module = importlib.util.module_from_spec(_source_model_spec)
_source_model_spec.loader.exec_module(_source_model_module)


def _state_name_from_relpath(relpath):
    rel = relpath.replace("\\", "/")
    if rel.startswith("states/"):
        rel = rel[len("states/") :]
    return rel.removesuffix(".sls").replace("/", ".")


def collect_json_nodes(state_results, include_edges, requisite_edges, known_state_names):
    """Collect canonical state nodes for JSON output."""
    node_names = {_state_name_from_relpath(rel) for rel, *_ in state_results}

    for src, dst in include_edges:
        if src in known_state_names:
            node_names.add(src)
        if dst in known_state_names:
            node_names.add(dst)

    for src, dst, _req_type in requisite_edges:
        if src in known_state_names:
            node_names.add(src)
        if dst in known_state_names:
            node_names.add(dst)

    return [{"name": name} for name in sorted(node_names)]


def collect_edges(state_results):
    """Extract include and requisite edges from rendered state results."""
    include_edges = []  # (from_file, to_file)
    requisite_edges = []  # (from_state, to_state, type)

    for rel, state_ids, includes, requisites, *_ in state_results:
        name = _state_name_from_relpath(rel)
        # Include edges
        for inc in includes or []:
            include_edges.append((name, inc))
        # Requisite edges
        for req in requisites or []:
            if (
                isinstance(req, tuple)
                and len(req) == 2
                and isinstance(req[0], str)
                and isinstance(req[1], str)
            ):
                requisite_edges.append((req[0], req[1], "require"))
                continue
            if isinstance(req, dict):
                for req_type, targets in req.items():
                    if isinstance(targets, list):
                        for t in targets:
                            if isinstance(t, dict):
                                for mod, sid in t.items():
                                    label = f"{mod}:{sid}" if ":" in str(sid) else str(sid)
                                    requisite_edges.append((name, label, req_type))
                            elif isinstance(t, str):
                                requisite_edges.append((name, t, req_type))

    return include_edges, requisite_edges


def generate_dot(include_edges, requisite_edges, state_results):
    """Generate DOT format graph."""
    lines = ["digraph salt_states {"]
    lines.append("  rankdir=LR;")
    lines.append('  node [shape=box, style=filled, fillcolor="#e8e8e8", fontname="monospace"];')
    lines.append('  edge [fontname="monospace", fontsize=10];')
    lines.append("")

    # Collect all state file nodes
    nodes = set()
    for rel, *_ in state_results:
        name = _state_name_from_relpath(rel)
        nodes.add(name)

    for node in sorted(nodes):
        lines.append(f'  "{node}";')

    lines.append("")

    # Include edges (solid black)
    for src, dst in include_edges:
        lines.append(f'  "{src}" -> "{dst}" [label="include", color="#333333"];')

    # Requisite edges (colored by type)
    colors = {
        "require": "#2196F3",  # blue
        "watch": "#FF9800",  # orange
        "onchanges": "#4CAF50",  # green
        "require_in": "#9C27B0",  # purple
    }
    for src, dst, req_type in requisite_edges:
        # Simplify dst to file name if it looks like a state reference
        color = colors.get(req_type, "#999999")
        lines.append(f'  "{src}" -> "{dst}" [label="{req_type}", color="{color}", style=dashed];')

    lines.append("}")
    return "\n".join(lines)


def generate_text_tree(include_edges, root="system_description"):
    """Generate text tree from include edges."""
    children = defaultdict(list)
    for src, dst in include_edges:
        children[src].append(dst)

    visited = set()
    lines = []

    def walk(node, prefix="", is_last=True):
        if node in visited:
            lines.append(f"{prefix}{'└── ' if is_last else '├── '}{node} (cycle)")
            return
        visited.add(node)
        connector = "└── " if is_last else "├── "
        lines.append(f"{prefix}{connector}{node}" if prefix else node)
        kids = sorted(children.get(node, []))
        for i, kid in enumerate(kids):
            extension = "    " if is_last else "│   "
            walk(kid, prefix + (extension if prefix else ""), i == len(kids) - 1)

    walk(root)
    return "\n".join(lines)


def generate_json(include_edges, requisite_edges, state_results, cycles, known_state_names):
    """Generate JSON graph payload."""
    nodes = collect_json_nodes(state_results, include_edges, requisite_edges, known_state_names)
    edges = [
        {
            "src_kind": "state",
            "src": src,
            "dst_kind": "state",
            "dst": dst,
            "relation": "include",
        }
        for src, dst in include_edges
    ]
    edges.extend(
        {
            "src_kind": "state_id" if req_type == "require" else "state",
            "src": src,
            "dst_kind": "requisite_target",
            "dst": dst,
            "relation": req_type,
        }
        for src, dst, req_type in requisite_edges
    )
    relation_order = {"include": 0, "require": 1, "watch": 2, "onchanges": 3, "require_in": 4}
    edges = sorted(
        enumerate(edges),
        key=lambda item: (relation_order.get(item[1]["relation"], 99), item[0]),
    )
    return json.dumps(
        {
            "nodes": nodes,
            "edges": [edge for _, edge in edges],
            "cycles": cycles,
        },
        indent=2,
    )


def detect_cycles(include_edges):
    """Detect cycles in include graph using DFS."""
    children = defaultdict(list)
    for src, dst in include_edges:
        children[src].append(dst)

    WHITE, GRAY, BLACK = 0, 1, 2
    color = defaultdict(int)
    cycles = []
    path = []

    def dfs(node):
        color[node] = GRAY
        path.append(node)
        for child in children[node]:
            if color[child] == GRAY:
                cycle_start = path.index(child)
                cycles.append(path[cycle_start:] + [child])
            elif color[child] == WHITE:
                dfs(child)
        path.pop()
        color[node] = BLACK

    for node in list(children.keys()):
        if color[node] == WHITE:
            dfs(node)

    return cycles


def discover_render_targets(states_dir="states"):
    """Select dep-graph render targets from canonical state discovery."""
    return [
        record.relpath
        for record in _source_model_module.discover_state_files(states_dir)
        if record.top_level_entrypoint
    ]


def main():
    parser = argparse.ArgumentParser(description="Generate Salt state dependency graph")
    parser.add_argument(
        "--format",
        choices=["dot", "svg", "text", "json"],
        default="dot",
        help="Output format (default: dot)",
    )
    parser.add_argument(
        "--output", "-o", type=str, default=None, help="Output file (default: stdout)"
    )
    parser.add_argument(
        "--root",
        default="system_description",
        help="Root state for text tree (default: system_description)",
    )
    args = parser.parse_args()

    all_state_records = _source_model_module.discover_state_files()
    known_state_names = {record.state_name for record in all_state_records}
    sls_files = [record.relpath for record in all_state_records if record.top_level_entrypoint]
    if not sls_files:
        print("No .sls files found in states/", file=sys.stderr)
        sys.exit(2)

    state_results = _index_module.render_states(sls_files)
    include_edges, requisite_edges = collect_edges(state_results)

    # Check for cycles
    cycles = detect_cycles(include_edges)
    if cycles:
        print("WARNING: Circular dependencies detected:", file=sys.stderr)
        for cycle in cycles:
            print(f"  {' -> '.join(cycle)}", file=sys.stderr)
        if args.format != "text":
            pass  # Still generate graph but with exit code 1

    if args.format == "text":
        output = generate_text_tree(include_edges, args.root)
    elif args.format == "json":
        output = generate_json(include_edges, requisite_edges, state_results, cycles, known_state_names)
    else:
        dot_output = generate_dot(include_edges, requisite_edges, state_results)
        if args.format == "svg":
            try:
                result = subprocess.run(
                    ["dot", "-Tsvg"], input=dot_output, capture_output=True, text=True, check=True
                )
                output = result.stdout
            except FileNotFoundError:
                print("graphviz (dot) not found. Install: pacman -S graphviz", file=sys.stderr)
                sys.exit(2)
            except subprocess.CalledProcessError as e:
                print(f"dot failed: {e.stderr}", file=sys.stderr)
                sys.exit(2)
        else:
            output = dot_output

    if args.output:
        Path(args.output).write_text(output)
        print(f"Written to {args.output}", file=sys.stderr)
    else:
        print(output)

    sys.exit(1 if cycles else 0)


if __name__ == "__main__":
    main()
