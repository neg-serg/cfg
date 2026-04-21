#!/usr/bin/env python3
"""Conservative impact planner for Salt auto-plan preview."""

from __future__ import annotations

import argparse
import json
import sys

TOP_LEVEL_PREFIX = "states/"
GROUP_PREFIX = "states/group/"
OWNER_MAPPINGS = {
    "states/desktop/": "desktop",
    "states/video_ai/": "video_ai",
}
SHARED_PATHS = {
    "states/_macros_service.jinja": "shared macro input",
    "states/_macros_pkg.jinja": "shared macro input",
    "states/data/services.yaml": "shared data input",
    "states/data/service_catalog.yaml": "shared data input",
}


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


def plan_for_changed_files(changed_files: list[str]) -> dict[str, object]:
    normalized = _normalize_changed_files(changed_files)
    selected_states: list[str] = []
    fallback_reasons: list[str] = []

    for path in normalized:
        if path in SHARED_PATHS:
            fallback_reasons.append(f"{path} is a {SHARED_PATHS[path]}")
            continue

        target = _group_target(path) or _top_level_state_target(path) or _owner_target(path)
        if target is not None:
            selected_states.append(target)
            continue

        fallback_reasons.append(f"{path} has no safe workflow target mapping")

    selected_states = sorted(dict.fromkeys(selected_states))
    if fallback_reasons:
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


def main() -> None:
    args = _build_parser().parse_args(sys.argv[1:])
    plan = plan_for_changed_files(args.files)
    if args.as_json:
        print(json.dumps(plan, indent=2))
    else:
        _print_text(plan)
    raise SystemExit(0)


if __name__ == "__main__":
    main()
