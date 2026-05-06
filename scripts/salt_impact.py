#!/usr/bin/env python3
"""Conservative impact planner for Salt auto-plan preview."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import defaultdict
from pathlib import Path

SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, SCRIPTS_DIR)

import salt_debug_report  # noqa: E402
import salt_source_model  # noqa: E402

TOP_LEVEL_PREFIX = "states/"
GROUP_PREFIX = "states/group/"
OWNER_MAPPINGS = {
    "states/desktop/": "desktop",
    "states/video_ai/": "video_ai",
    "states/group/": "system_description",
}
DATA_PREFIX = "states/data/"
CONFIGS_PREFIX = "states/configs/"
MACRO_PREFIX = "states/_macros_"
SHARED_PATHS = {
    "states/_macros_common.jinja": "shared macro input",
    "states/_macros_config.jinja": "shared macro input",
    "states/_macros_container.jinja": "shared macro input",
    "states/_macros_desktop.jinja": "shared macro input",
    "states/_macros_install.jinja": "shared macro input",
    "states/_macros_pkg.jinja": "shared macro input",
    "states/_macros_service.jinja": "shared macro input",
    "states/_macros_every.jinja": "shared macro input",
    "states/_macros_user.jinja": "shared macro input",
    "states/_macros_zsh.jinja": "shared macro input",
    "states/_imports.jinja": "shared imports",
    "states/data/hosts.yaml": "shared data input",
}
NOOP_PREFIXES = (
    "scripts/",
    "tests/",
    "docs/",
    "dotfiles/",
    "specs/",
    ".specify/",
    "AGENTS.md",
    "TODO.md",
    ".gitignore",
    ".chezmoiignore",
    ".chezmoiremove",
)

STATE_ASSET_PREFIXES = (
    "states/configs/",
    "states/scripts/",
    "states/units/",
)

J2_IMPORT_YAML_RE = re.compile(r"\{%-?\s*import_yaml\s+['\"]([^'\"]+)['\"]\s+as\s+\w+")
CONFIG_TO_STATE: dict[str, list[str]] = {}
UNIT_TO_STATE: dict[str, list[str]] = {}

_DATA_TO_STATE_CACHE: dict[str, dict[str, list[str]]] | None = None


def _build_data_state_graph(repo_root: str | None = None) -> dict[str, list[str]]:
    global _DATA_TO_STATE_CACHE

    if _DATA_TO_STATE_CACHE is not None:
        return _DATA_TO_STATE_CACHE

    states_dir = repo_root or os.getcwd()
    data_dir = os.path.join(states_dir, "states", "data")
    configs_dir = os.path.join(states_dir, "states", "configs")

    data_to_states: dict[str, list[str]] = defaultdict(list)

    records = salt_source_model.discover_state_files(os.path.join(states_dir, "states"))
    for record in records:
        record = salt_source_model.enrich_source_metadata(record)
        state_target = _state_target_from_record(record)
        if not state_target:
            continue
        for yaml_ref in record.imported_yaml:
            data_basename = os.path.basename(yaml_ref)
            data_path = os.path.join("states", "data", data_basename)
            if data_path.endswith(".yaml") or data_path.endswith(".yml"):
                data_to_states[data_basename].append(state_target)

    if os.path.isdir(configs_dir):
        for config_path in Path(configs_dir).rglob("*.j2"):
            try:
                src = config_path.read_text()
            except Exception:
                continue
            yaml_refs = J2_IMPORT_YAML_RE.findall(src)
            if not yaml_refs:
                continue
            rel_config = os.path.relpath(config_path, states_dir)
            for yaml_ref in yaml_refs:
                data_basename = os.path.basename(yaml_ref)
                if data_basename.endswith((".yaml", ".yml")):
                    config_state = _resolve_config_to_state(
                        os.path.join("states", "configs", os.path.basename(rel_config)), states_dir
                    )
                    if config_state:
                        data_to_states[data_basename].append(config_state)

    data_to_states = {
        k: sorted(set(v)) for k, v in data_to_states.items() if v
    }

    _DATA_TO_STATE_CACHE = data_to_states
    return data_to_states


def _state_target_from_record(record) -> str | None:
    relpath = record.relpath
    if not relpath.startswith("states/") or not relpath.endswith(".sls"):
        return None
    name = relpath.removeprefix("states/").removesuffix(".sls")
    if name.startswith("group/"):
        subname = name.removeprefix("group/")
        return f"group_{subname}" if "/" not in subname else None
    if "/" in name:
        return None
    return name


def _resolve_config_to_state(config_path: str, repo_root: str) -> str | None:
    global CONFIG_TO_STATE
    if not CONFIG_TO_STATE:
        _build_config_state_map(repo_root)
    return CONFIG_TO_STATE.get(config_path, [None])[0] if CONFIG_TO_STATE.get(config_path) else None


def _resolve_unit_to_state(unit_path: str, repo_root: str) -> str | None:
    global UNIT_TO_STATE
    if not UNIT_TO_STATE:
        _build_config_state_map(repo_root)
    if unit_path in UNIT_TO_STATE:
        return UNIT_TO_STATE[unit_path][0]
    unit_basename = os.path.basename(unit_path)
    for full_path, states in UNIT_TO_STATE.items():
        if os.path.basename(full_path) == unit_basename:
            return states[0]
    return None


def _build_config_state_map(repo_root: str) -> None:
    global CONFIG_TO_STATE, UNIT_TO_STATE
    configs_dir = os.path.join(repo_root, "states", "configs")
    states_dir = os.path.join(repo_root, "states")
    CONFIG_TO_STATE = {}
    UNIT_TO_STATE = {}

    UNIT_REF_RE = re.compile(r"salt://(units/[^\s'\"}]+)")

    for sls_path in Path(states_dir).rglob("*.sls"):
        try:
            src = sls_path.read_text()
        except Exception:
            continue
        config_refs = set()
        unit_refs = set()
        for match in re.finditer(r"salt://(configs/[^\s'\"]+)", src):
            config_refs.add("states/" + match.group(1))
        for match in UNIT_REF_RE.finditer(src):
            unit_refs.add("states/" + match.group(1))

        if not config_refs and not unit_refs:
            continue

        rel = sls_path.relative_to(repo_root)
        record = salt_source_model.StateFileRecord(
            relpath=str(rel),
            state_name="",
            top_level_entrypoint=False,
            workflow_apply_target=False,
            source_text=src,
        )
        state_target = _state_target_from_record(record)
        if state_target:
            for cref in config_refs:
                if cref not in CONFIG_TO_STATE:
                    CONFIG_TO_STATE[cref] = []
                CONFIG_TO_STATE[cref].append(state_target)
            for uref in unit_refs:
                if uref not in UNIT_TO_STATE:
                    UNIT_TO_STATE[uref] = []
                UNIT_TO_STATE[uref].append(state_target)


def _normalize_changed_files(changed_files: list[str]) -> list[str]:
    return sorted(dict.fromkeys(path.replace("\\", "/") for path in changed_files))


def _top_level_state_target(path: str) -> str | None:
    if not path.startswith(TOP_LEVEL_PREFIX) or not path.endswith(".sls"):
        return None

    name = path.removeprefix(TOP_LEVEL_PREFIX).removesuffix(".sls")
    if "/" in name:
        return None
    return name


def _group_target(path: str) -> str | None:
    if not path.startswith(GROUP_PREFIX) or not path.endswith(".sls"):
        return None

    name = path.removeprefix(GROUP_PREFIX).removesuffix(".sls")
    if "/" in name:
        return None
    return f"group/{name}"


def _owner_target(path: str) -> str | None:
    for prefix, target in OWNER_MAPPINGS.items():
        if path.startswith(prefix) and path.endswith(".sls"):
            return target
    return None


def plan_for_changed_files(changed_files: list[str], repo_root: str | None = None) -> dict[str, object]:
    normalized = _normalize_changed_files(changed_files)
    selected_states: list[str] = []
    fallback_reasons: list[str] = []
    data_graph = _build_data_state_graph(repo_root)
    MAX_DATA_CONSUMERS = 5

    for path in normalized:
        if path in SHARED_PATHS:
            fallback_reasons.append(f"{path} is a {SHARED_PATHS[path]}")
            continue

        if path.startswith(NOOP_PREFIXES) or path in {".gitignore", "AGENTS.md", "TODO.md"}:
            continue

        if path.startswith(STATE_ASSET_PREFIXES):
            target = None
            if path.startswith(CONFIGS_PREFIX):
                target = _resolve_config_to_state(path, repo_root or os.getcwd())
                if target:
                    selected_states.append(target)
                    continue
            if path.startswith("states/units/"):
                target = _resolve_unit_to_state(path, repo_root or os.getcwd())
                if target:
                    selected_states.append(target)
                    continue
            fallback_reasons.append(f"{path} is a state asset (config/script/unit) — requires system_description for safety")
            continue

        if path.startswith(MACRO_PREFIX):
            fallback_reasons.append(f"{path} is a shared macro — requires system_description for safety")
            continue

        if path.startswith(DATA_PREFIX):
            data_basename = os.path.basename(path)
            consumers = data_graph.get(data_basename, [])
            if consumers and len(consumers) <= MAX_DATA_CONSUMERS:
                selected_states.extend(consumers)
                continue
            elif consumers:
                fallback_reasons.append(
                    f"{path} has {len(consumers)} consumers ({MAX_DATA_CONSUMERS}+)"
                    " — requires system_description for safety"
                )
                continue
            else:
                fallback_reasons.append(f"{path} is a data file with no known SLS consumers")
                continue

        target = _group_target(path) or _top_level_state_target(path) or _owner_target(path)
        if target is not None:
            selected_states.append(target)
            continue

        fallback_reasons.append(f"{path} has no safe workflow target mapping")

    selected_states = sorted(dict.fromkeys(selected_states))
    if not selected_states and not fallback_reasons:
        final_target = "none"
    elif fallback_reasons:
        final_target = "system_description"
    elif len(selected_states) == 1:
        final_target = selected_states[0]
    elif len(selected_states) > 1:
        fallback_reasons.append(
            f"changed files map to multiple workflow targets: {', '.join(selected_states)}"
        )
        final_target = "system_description"
    else:
        fallback_reasons.append("no changed files mapped to a safe workflow target")
        final_target = "system_description"

    return {
        "changed_files": normalized,
        "selected_states": selected_states,
        "fallback_reasons": fallback_reasons,
        "final_target": final_target,
    }


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--files", nargs="+", required=True)
    parser.add_argument("--json", action="store_true", dest="as_json")
    return parser


def _print_text(plan: dict[str, object]) -> None:
    print("Changed files:")
    for path in plan["changed_files"]:
        print(f"- {path}")

    print(f"Final target: {plan['final_target']}")

    print("Selected states:")
    if plan["selected_states"]:
        for target in plan["selected_states"]:
            print(f"- {target}")
    else:
        print("- none")

    print("Fallback reasons:")
    if plan["fallback_reasons"]:
        for reason in plan["fallback_reasons"]:
            print(f"- {reason}")
    else:
        print("- none")


def _debug_bundle_context(changed_files: list[str] | None) -> dict[str, object]:
    if not changed_files:
        return {"state": "auto"}

    selected_states = sorted(
        {
            target
            for path in _normalize_changed_files(changed_files)
            for target in [
                _group_target(path) or _top_level_state_target(path) or _owner_target(path)
            ]
            if target is not None
        }
    )
    if len(selected_states) == 1:
        return {"state": selected_states[0]}
    if selected_states:
        return {"selected_states": selected_states}
    return {"state": "auto"}


def _write_planning_failure_bundle(changed_files: list[str] | None, error: Exception) -> None:
    bundle = {
        "tool": "salt-impact",
        "failure_stage": "planning",
        "error": str(error),
    }
    bundle.update(_debug_bundle_context(changed_files))
    salt_debug_report.write_debug_bundle(bundle)


def main() -> None:
    args = None
    try:
        args = _build_parser().parse_args(sys.argv[1:])
        plan = plan_for_changed_files(args.files)
        if args.as_json:
            print(json.dumps(plan, indent=2))
        else:
            _print_text(plan)
    except Exception as exc:  # noqa: BLE001 (surface unexpected planning failures)
        changed_files = getattr(args, "files", None)
        _write_planning_failure_bundle(changed_files, exc)
        raise SystemExit(1) from exc
    raise SystemExit(0)


if __name__ == "__main__":
    main()
