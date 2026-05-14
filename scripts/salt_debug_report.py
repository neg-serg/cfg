#!/usr/bin/env python3
"""Write structured Salt debug bundles for failure analysis."""

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.pretty import pretty


def _debug_report_dir() -> Path:
    override = os.environ.get("SALT_DEBUG_REPORT_DIR")
    if override:
        return Path(override)
    return Path("logs") / "debug"


def write_debug_bundle(bundle: dict) -> Path:
    output_dir = _debug_report_dir()
    output_dir.mkdir(parents=True, exist_ok=True)

    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    tool = str(bundle.get("tool", "tool")).replace("/", "-")
    state = str(bundle.get("state", "state")).replace("/", "-")
    scenario = str(bundle.get("scenario", "scenario")).replace("/", "-")
    path = output_dir / f"{timestamp}-{tool}-{state}-{scenario}.json"
    path.write_text(json.dumps(bundle, indent=2, sort_keys=True) + "\n")
    return path


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", required=True, help="Filter bundles by state name")
    parser.add_argument("--scenario", help="Filter bundles by scenario name")
    parser.add_argument(
        "--compare-scenario",
        help="Compare semantic debug signals across two scenarios",
    )
    return parser.parse_args(argv)


def _load_matching_bundles(state: str, scenario: str | None = None) -> list[dict]:
    matches = []
    for bundle_path in sorted(_debug_report_dir().glob("*.json")):
        bundle = json.loads(bundle_path.read_text())
        if bundle.get("state") != state:
            continue
        if scenario is not None and bundle.get("scenario") != scenario:
            continue
        matches.append(bundle)
    return matches


def _has_failure(bundles: list[dict]) -> bool:
    return any(bundle.get("failure_stage") for bundle in bundles)


def _build_scenario_diff(state: str, scenario: str, compare_scenario: str) -> tuple[dict, int]:
    scenario_bundles = _load_matching_bundles(state, scenario)
    compare_bundles = _load_matching_bundles(state, compare_scenario)
    scenario_bundle_present = bool(scenario_bundles)
    compare_bundle_present = bool(compare_bundles)
    scenario_has_failure = _has_failure(scenario_bundles)
    compare_has_failure = _has_failure(compare_bundles)

    return (
        {
            "state": state,
            "scenario": scenario,
            "compare_scenario": compare_scenario,
            "scenario_bundle_present": scenario_bundle_present,
            "compare_scenario_bundle_present": compare_bundle_present,
            "scenario_has_failure": scenario_has_failure,
            "compare_scenario_has_failure": compare_has_failure,
            "bundle_presence_changed": scenario_bundle_present != compare_bundle_present,
            "failure_changed": scenario_has_failure != compare_has_failure,
        },
        0 if scenario_bundle_present or compare_bundle_present else 1,
    )


def main(argv: list[str] | None = None) -> None:
    args = _parse_args(argv)
    if args.compare_scenario:
        if not args.scenario:
            raise SystemExit("--compare-scenario requires --scenario")
        payload, exit_code = _build_scenario_diff(
            args.state,
            args.scenario,
            args.compare_scenario,
        )
        print(json.dumps(payload, indent=2, sort_keys=True))
        raise SystemExit(exit_code)

    matches = _load_matching_bundles(args.state, args.scenario)
    print(json.dumps(matches, indent=2, sort_keys=True))
    raise SystemExit(0 if matches else 1)


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except (OSError, KeyboardInterrupt):
        raise
    except Exception as e:
        pretty.fail(f"Error: {e}")
        sys.exit(1)
