#!/usr/bin/env python3
"""Parallel Salt state group executor.

Spawns concurrent salt-call processes for independent state groups.
Resolves the group dependency graph to determine execution order.

Usage:
    salt_parallel.py [--max-parallel N] [--dry-run]

Environment:
    SALT_PARALLEL   Set to 1 to enable parallel execution (default: 0)
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_DIR = SCRIPT_DIR.parent
VENV_DIR = PROJECT_DIR / ".venv"
RUNTIME_CONFIG_DIR = PROJECT_DIR / ".salt_runtime"

SALT_CALL = [str(VENV_DIR / "bin" / "salt-call"), "--config-dir", str(RUNTIME_CONFIG_DIR)]


@dataclass
class Group:
    name: str
    states: list[str]
    depends_on: list[str] = field(default_factory=list)
    exit_code: int | None = None
    duration_ms: int = 0
    log_file: str = ""


# Group dependency graph — derived from system_description.sls include chain
# core → packages → {desktop∥network} → {services∥ai}
GROUPS: list[Group] = [
    Group(name="core", states=["mounts", "cachyos", "system_description"], depends_on=[]),
    Group(
        name="packages",
        states=[
            "installers_base",
            "installers_desktop",
            "installers_themes",
            "custom_pkgs",
        ],
        depends_on=["core"],
    ),
    Group(
        name="desktop",
        states=["audio", "fonts", "desktop", "greetd", "pacman_db_warmup", "steam"],
        depends_on=["packages"],
    ),
    Group(
        name="network",
        states=[
            "dns",
            "network",
            "amnezia",
            "zapret2",
            "hiddify",
            "ipv6",
        ],
        depends_on=["packages"],
    ),
    Group(
        name="services",
        states=[
            "services",
            "monitoring_alerts",
            "user_services",
            "code_rag",
            "jellyfin",
            "transmission",
            "bitcoind",
            "duckdns",
            "vaultwarden",
            "adguardhome",
            "proxypilot",
        ],
        depends_on=["network"],
    ),
    Group(
        name="ai",
        states=[
            "ollama",
            "llama_embed",
            "t5_summarization",
            "image_generation",
            "video_ai",
            "telethon_bridge",
            "managed_bots",
        ],
        depends_on=["services"],
    ),
]


def resolve_ready(
    groups: list[Group], completed: set[str], in_progress: set[str]
) -> list[Group]:
    """Return groups whose dependencies are all satisfied and not yet started."""
    ready = []
    for g in groups:
        if g.name in completed or g.name in in_progress:
            continue
        if all(dep in completed for dep in g.depends_on):
            ready.append(g)
    return ready


def run_group(group: Group, log_dir: Path) -> int:
    """Execute a single group's salt-call and return exit code."""
    timestamp = time.strftime("%Y%m%d-%H%M%S")
    log_file = log_dir / f"phase-{group.name}-{timestamp}.log"
    group.log_file = str(log_file)

    start = time.monotonic()
    salt_args = SALT_CALL + [
        "--local",
        "--log-level=warning",
        "--force-color",
        "--log-file",
        str(log_file),
        "--log-file-level=debug",
        "state.sls",
    ]

    # Apply each state in the group sequentially
    # (individual salt-call per state to isolate failures)
    exit_codes = []
    for state_name in group.states:
        cmd = salt_args + [state_name]
        result = subprocess.run(cmd, capture_output=True, text=True)
        exit_codes.append(result.returncode)
        # Write stdout to log
        with open(log_file, "a") as f:
            f.write(f"\n=== {state_name} exit={result.returncode} ===\n")
            f.write(result.stdout)
            if result.stderr:
                f.write(result.stderr)

    duration = int((time.monotonic() - start) * 1000)
    group.duration_ms = duration
    group.exit_code = max(exit_codes) if exit_codes else 0
    return group.exit_code


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Parallel Salt state group executor")
    parser.add_argument("--max-parallel", type=int, default=4, help="Max concurrent groups")
    parser.add_argument("--dry-run", action="store_true", help="Print plan but don't execute")
    args = parser.parse_args()

    log_dir = PROJECT_DIR / "logs"
    log_dir.mkdir(exist_ok=True)

    groups = list(GROUPS)
    completed: set[str] = set()
    exit_codes: dict[str, int] = {}

    if args.dry_run:
        print(json.dumps([g.name for g in groups], indent=2))
        return 0

    print(f"Parallel apply: {len(groups)} groups, max {args.max_parallel} concurrent")
    print(f"Order: core → packages → {{desktop∥network}} → {{services∥ai}}\n")

    while len(completed) < len(groups):
        ready = resolve_ready(groups, completed, set())
        if not ready:
            break

        # Limit concurrency
        threads = []
        results: dict[str, int] = {}

        def runner(g: Group):
            results[g.name] = run_group(g, log_dir)
            completed.add(g.name)

        for g in ready:
            t = threading.Thread(target=runner, args=(g,), name=g.name)
            threads.append(t)
            t.start()

        for t in threads:
            t.join()

    # Summary
    print(f"\n{'='*60}")
    print(f"Parallel apply summary ({len(completed)}/{len(groups)} groups)")
    print(f"{'='*60}")
    for g in groups:
        status = "PASS" if g.exit_code == 0 else f"FAIL({g.exit_code})"
        print(f"  {g.name:12s} {status:8s} {g.duration_ms:6d}ms  log: {Path(g.log_file).name}")
    print(f"{'='*60}")

    return max((g.exit_code or 0) for g in groups)


if __name__ == "__main__":
    sys.exit(main())
