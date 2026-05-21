#!/usr/bin/env python3
"""Parallel Salt state group executor.

Spawns concurrent salt-call processes (via salt_runner.py) for independent
state groups, respecting the group dependency graph.

Usage:
    salt_parallel.py [--max-parallel N] [--dry-run]
"""

import json
import re
import subprocess
import sys
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_DIR = SCRIPT_DIR.parent
VENV_DIR = PROJECT_DIR / ".venv"
RUNTIME_CONFIG_DIR = PROJECT_DIR / ".salt_runtime"
SALT_RUNNER = SCRIPT_DIR / "salt_runner.py"

_API_KEY_RE = re.compile(r"(?:csk|sk)-[a-z0-9]{30,}")


def _sanitize(text: str) -> str:
    return _API_KEY_RE.sub("[REDACTED]", text)


def _sudo_args() -> tuple[list[str], str]:
    """Resolve sudo command — prefer NOPASSWD, fall back to askpass, then .password.
    Returns (sudo_cmd_list, sudo_password_or_empty)."""
    r = subprocess.run(["sudo", "-n", "true"], capture_output=True)
    if r.returncode == 0:
        return ["sudo"], ""

    askpass = SCRIPT_DIR / "salt-askpass.sh"
    if askpass.exists():
        import os
        os.environ["SUDO_ASKPASS"] = str(askpass)
        r = subprocess.run(["sudo", "-A", "true"], capture_output=True)
        if r.returncode == 0:
            return ["sudo", "-A"], ""

    pw_file = PROJECT_DIR / ".password"
    if pw_file.exists():
        return ["sudo", "-S"], pw_file.read_text().strip()
    return [], ""


@dataclass
class Group:
    name: str
    states: list[str]
    depends_on: list[str] = field(default_factory=list)
    exit_code: int | None = None
    duration_ms: int = 0
    log_file: str = ""


# Group dependency graph — uses actual group state files from states/group/
# core → packages → {desktop∥network} → {services∥ai}
GROUPS: list[Group] = [
    Group(name="core", states=["group.core"], depends_on=[]),
    Group(name="packages", states=["group.packages"], depends_on=["core"]),
    Group(name="desktop", states=["group.desktop"], depends_on=["packages"]),
    Group(name="network", states=["group.network"], depends_on=["packages"]),
    Group(name="services", states=["group.services"], depends_on=["network"]),
    Group(name="ai", states=["group.ai"], depends_on=["services"]),
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


def run_group(group: Group, log_dir: Path, sudo: list[str], sudo_pass: str) -> int:
    """Execute a single group's states via salt_runner.py. Return exit code."""
    timestamp = time.strftime("%Y%m%d-%H%M%S")
    log_file = log_dir / f"phase-{group.name}-{timestamp}.log"
    group.log_file = str(log_file)

    start = time.monotonic()
    exit_codes = []

    for state_name in group.states:
        # Per-group cachedir to avoid concurrent cache corruption
        group_cache = RUNTIME_CONFIG_DIR / f".parallel_cache/{group.name}"
        group_cache.mkdir(parents=True, exist_ok=True)
        cmd = sudo + [
            str(VENV_DIR / "bin" / "python3"),
            "-u",
            str(SALT_RUNNER),
            "--config-dir",
            str(RUNTIME_CONFIG_DIR),
            "--cachedir",
            str(group_cache),
            "--local",
            "--log-level=warning",
            "--force-color",
            "state.sls",
            state_name,
        ]
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            input=sudo_pass if sudo_pass else None,
        )

        exit_codes.append(result.returncode)
        with open(log_file, "a") as f:
            f.write(f"\n=== {state_name} exit={result.returncode} ===\n")
            f.write(_sanitize(result.stdout))
            if result.stderr:
                f.write(_sanitize(result.stderr))

    duration = int((time.monotonic() - start) * 1000)
    group.duration_ms = duration
    group.exit_code = max(exit_codes) if exit_codes else 0
    return group.exit_code


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Parallel Salt state group executor")
    parser.add_argument("--max-parallel", type=int, default=4, help="Max concurrent groups")
    parser.add_argument("--dry-run", action="store_true", help="Print plan only")
    args = parser.parse_args()

    sudo, sudo_pass = _sudo_args()
    if not sudo:
        print("ERROR: no NOPASSWD sudo and no .password file found")
        return 1

    log_dir = PROJECT_DIR / "logs"
    log_dir.mkdir(exist_ok=True)

    groups = list(GROUPS)
    completed: set[str] = set()

    if args.dry_run:
        print(json.dumps([g.name for g in groups], indent=2))
        return 0

    print(f"Parallel apply: {len(groups)} groups, max {args.max_parallel} concurrent")
    print("Order: core → packages → {desktop∥network} → {services∥ai}\n")

    while len(completed) < len(groups):
        ready = resolve_ready(groups, completed, set())
        if not ready:
            break

        results: dict[str, int] = {}

        def runner(g: Group):
            results[g.name] = run_group(g, log_dir, sudo, sudo_pass)
            completed.add(g.name)

        threads = []
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
