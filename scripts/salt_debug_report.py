#!/usr/bin/env python3
"""Write structured Salt debug bundles for failure analysis."""

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path


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


def main(argv: list[str] | None = None) -> None:
    args = _parse_args(argv)
    matches = _load_matching_bundles(args.state, args.scenario)
    print(json.dumps(matches, indent=2, sort_keys=True))
    raise SystemExit(0 if matches else 1)


if __name__ == "__main__":
    main(sys.argv[1:])
