#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import socket
import subprocess
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path

import yaml
from host_model import build_host, load_hosts_yaml


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha256_file(path: Path) -> str | None:
    if not path.exists() or not path.is_file():
        return None
    digest = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            chunk = f.read(65536)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def file_stat(path: Path) -> tuple[int, int] | None:
    try:
        st = path.stat()
        return (int(st.st_mtime), st.st_size)
    except OSError:
        return None


def resolve_path(raw: str, host: dict) -> str:
    return raw.replace("{{ home }}", host["home"]).replace("{{ runtime_dir }}", host["runtime_dir"])


def load_inventory(project_dir: Path) -> dict:
    with open(project_dir / "scripts" / "drift_inventory.yaml") as fh:
        return yaml.safe_load(fh.read()) or {}


def hash_file_entry(path: Path, file_id: str, severity: str, cache: dict | None) -> dict:
    """Compute file entry with optional cache reuse (mtime+size match → skip SHA-256)."""
    st = file_stat(path)
    sha = None
    mtime = None
    size = None

    if st is not None:
        mtime, size = st
        if cache is not None:
            cached = cache.get(str(path))
            if cached is not None and cached.get("mtime") == mtime and cached.get("size") == size:
                sha = cached.get("sha256")
        if sha is None:
            sha = sha256_file(path)

    return {
        "id": file_id,
        "path": str(path),
        "severity": severity,
        "sha256": sha,
        "mtime": mtime,
        "size": size,
    }


def build_expected_snapshot(
    host: dict,
    inventory: dict,
    project_dir: Path | None = None,
    salt_target: str | None = None,
    previous_snapshot: dict | None = None,
) -> dict:
    cache = (
        {entry["path"]: entry for entry in previous_snapshot.get("files", [])}
        if previous_snapshot
        else None
    )
    entries = [
        (entry["id"], Path(resolve_path(entry["path"], host)), entry["severity"])
        for entry in inventory.get("files", [])
    ]

    files = [None] * len(entries)
    with ThreadPoolExecutor(max_workers=8) as pool:
        fut = {
            pool.submit(hash_file_entry, path, eid, sev, cache): i
            for i, (eid, path, sev) in enumerate(entries)
        }
        for f in as_completed(fut):
            files[fut[f]] = f.result()

    result = {
        "generated_at": now_iso(),
        "hostname": host["hostname"],
        "files": files,
        "system_units": inventory.get("system_units", []),
        "user_units": inventory.get("user_units", []),
    }
    if project_dir is not None:
        try:
            rev = subprocess.run(
                ["git", "rev-parse", "--short", "HEAD"],
                capture_output=True,
                text=True,
                check=False,
                cwd=project_dir,
            ).stdout.strip()
            if rev:
                result["git_revision"] = rev
        except Exception:
            pass
    if salt_target:
        result["salt_target"] = salt_target
    return result


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def read_json(path: Path) -> dict | None:
    if not path.exists():
        return None
    return json.loads(path.read_text())


def run_pkg_drift(project_dir: Path) -> dict:
    proc = subprocess.run(
        ["zsh", str(project_dir / "scripts" / "pkg-drift.zsh"), "--json"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        check=False,
    )
    if not proc.stdout.strip():
        return {"unmanaged": [], "missing": [], "orphans": []}
    return json.loads(proc.stdout)


def collect_unit_state(name: str, *, user: bool, expected_enabled: bool, severity: str) -> dict:
    cmd = ["systemctl"]
    if user:
        cmd.append("--user")
    enabled_proc = subprocess.run(
        cmd + ["is-enabled", name], capture_output=True, text=True, check=False
    )
    show_proc = subprocess.run(
        cmd + ["show", name, "--property=LoadState,ActiveState,UnitFileState"],
        capture_output=True,
        text=True,
        check=False,
    )
    props = {}
    for line in show_proc.stdout.splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            props[key] = value
    return {
        "name": name,
        "enabled": enabled_proc.returncode == 0,
        "masked": props.get("UnitFileState") == "masked",
        "load_state": props.get("LoadState", "unknown"),
        "active_state": props.get("ActiveState", "unknown"),
        "expected_enabled": expected_enabled,
        "severity": severity,
    }


def load_runtime_alerts(cache_dir: Path) -> list[dict]:
    alerts_dir = cache_dir / "alerts"
    if not alerts_dir.exists():
        return []
    records = []
    for path in alerts_dir.iterdir():
        if path.name.startswith("."):
            continue
        parts = path.name.split(".", 2)
        if len(parts) != 3:
            continue
        scope, service, alert_type = parts
        records.append({"scope": scope, "service": service, "type": alert_type})
    return records


def collect_actual_snapshot(
    project_dir: Path, cache_dir: Path, expected: dict, mode: str = "full"
) -> dict:
    cache = {entry["path"]: entry for entry in expected.get("files", [])}
    expected_files = expected.get("files", [])
    results = [None] * len(expected_files)

    def _hash(i: int, entry: dict) -> None:
        path = Path(entry["path"])
        st = file_stat(path)
        sha = None
        if st is not None:
            cached = cache.get(entry["path"])
            if cached is not None and cached.get("mtime") == st[0] and cached.get("size") == st[1]:
                sha = cached.get("sha256")
            if sha is None:
                sha = sha256_file(path)
        results[i] = {
            "id": entry["id"],
            "path": entry["path"],
            "exists": path.exists(),
            "sha256": sha,
        }

    with ThreadPoolExecutor(max_workers=8) as pool:
        fut = {pool.submit(_hash, i, entry): i for i, entry in enumerate(expected_files)}
        for f in as_completed(fut):
            pass
    system_units = [
        collect_unit_state(
            entry["name"], user=False, expected_enabled=entry["enabled"], severity=entry["severity"]
        )
        for entry in expected.get("system_units", [])
    ]
    user_units = [
        collect_unit_state(
            entry["name"], user=True, expected_enabled=entry["enabled"], severity=entry["severity"]
        )
        for entry in expected.get("user_units", [])
    ]
    if mode == "fast":
        packages = {"unmanaged": [], "missing": [], "orphans": []}
        runtime_alerts: list = []
    else:
        packages = run_pkg_drift(project_dir)
        runtime_alerts = load_runtime_alerts(cache_dir)
    return {
        "generated_at": now_iso(),
        "packages": packages,
        "files": results,
        "system_units": system_units,
        "user_units": user_units,
        "runtime_alerts": runtime_alerts,
    }


def classify_drift(
    expected: dict | None,
    actual: dict,
    stale_after_hours: int = 72,
    maintenance_lock_path: str | None = None,
) -> dict:
    del stale_after_hours
    in_maintenance = maintenance_lock_path is not None and Path(maintenance_lock_path).exists()

    if expected is None:
        return {
            "generated_at": now_iso(),
            "status": "unknown",
            "records": [
                {
                    "category": "meta",
                    "object": "expected-snapshot",
                    "status": "stale_baseline",
                    "severity": "info",
                    "expected": "fresh baseline",
                    "actual": "missing baseline",
                    "evidence": "expected-snapshot.json is absent",
                    "source": "meta",
                }
            ],
        }

    records = []
    for pkg in actual.get("packages", {}).get("unmanaged", []):
        records.append(
            {
                "category": "package",
                "object": pkg,
                "status": "unmanaged",
                "severity": "warning",
                "source": "expected-vs-actual",
            }
        )
    for pkg in actual.get("packages", {}).get("missing", []):
        records.append(
            {
                "category": "package",
                "object": pkg,
                "status": "missing",
                "severity": "critical",
                "source": "expected-vs-actual",
            }
        )
    for pkg in actual.get("packages", {}).get("orphans", []):
        records.append(
            {
                "category": "package",
                "object": pkg,
                "status": "orphaned",
                "severity": "info",
                "source": "expected-vs-actual",
            }
        )

    expected_files = {entry["path"]: entry for entry in expected.get("files", [])}
    for entry in actual.get("files", []):
        baseline = expected_files.get(entry["path"])
        if baseline and baseline.get("sha256") != entry.get("sha256"):
            records.append(
                {
                    "category": "file",
                    "object": entry["path"],
                    "status": "changed",
                    "severity": baseline["severity"],
                    "expected": baseline.get("sha256"),
                    "actual": entry.get("sha256"),
                    "source": "expected-vs-actual",
                }
            )

    expected_units = {
        entry["name"]: entry
        for entry in expected.get("system_units", []) + expected.get("user_units", [])
    }
    for entry in actual.get("system_units", []) + actual.get("user_units", []):
        baseline = expected_units.get(entry["name"])
        if baseline and baseline.get("enabled") != entry.get("enabled"):
            records.append(
                {
                    "category": "unit",
                    "object": entry["name"],
                    "status": "policy_mismatch",
                    "severity": entry["severity"],
                    "expected": baseline.get("enabled"),
                    "actual": entry.get("enabled"),
                    "source": "expected-vs-actual",
                }
            )

    for entry in actual.get("runtime_alerts", []):
        records.append(
            {
                "category": "runtime",
                "object": entry["service"],
                "status": entry["type"],
                "severity": "warning",
                "expected": "healthy",
                "actual": entry["type"],
                "source": "runtime",
            }
        )

    if in_maintenance:
        for record in records:
            if record["severity"] in ("critical", "warning"):
                record["severity"] = "info"

    top = "clean"
    if any(record["category"] in {"file", "package", "unit"} for record in records):
        top = "drifted"
    elif any(record["category"] == "runtime" for record in records):
        top = "degraded"
    elif any(record["status"] == "stale_baseline" for record in records):
        top = "unknown"

    if in_maintenance and top == "drifted":
        top = "degraded"

    return {"generated_at": now_iso(), "status": top, "records": records}


def print_report(payload: dict, *, json_mode: bool) -> None:
    if json_mode:
        print(json.dumps(payload, indent=2, sort_keys=True))
        return
    print(f"status: {payload['status']}")
    for category in ("package", "file", "unit", "runtime", "meta"):
        section = [record for record in payload["records"] if record["category"] == category]
        if not section:
            continue
        print(f"[{category}]")
        for record in section:
            print(f"- {record['object']}: {record['status']}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["refresh-expected", "fast", "full", "status", "report"])
    parser.add_argument("--project-dir", default=str(Path.home() / "src" / "cfg"))
    parser.add_argument("--cache-dir", default=str(Path.home() / ".cache" / "salt-monitor"))
    parser.add_argument("--json", action="store_true")
    parser.add_argument(
        "--maintenance", choices=["on", "off"], help="Create or remove maintenance lock file"
    )
    parser.add_argument("--salt-target", help="Salt state target applied when snapshot was created")
    args = parser.parse_args()

    project_dir = Path(args.project_dir)
    cache_dir = Path(args.cache_dir)
    maintenance_lock_path = cache_dir / "maintenance.lock"

    if args.maintenance == "on":
        maintenance_lock_path.parent.mkdir(parents=True, exist_ok=True)
        maintenance_lock_path.write_text("")
        print(f"maintenance lock created at {maintenance_lock_path}")
        return 0
    if args.maintenance == "off":
        maintenance_lock_path.unlink(missing_ok=True)
        print(f"maintenance lock removed from {maintenance_lock_path}")
        return 0

    hosts_data = load_hosts_yaml()
    host = build_host(socket.gethostname(), hosts_data)
    inventory = load_inventory(project_dir)
    expected_path = cache_dir / "expected-snapshot.json"
    actual_fast_path = cache_dir / "actual-fast.json"
    actual_full_path = cache_dir / "actual-full.json"
    status_path = cache_dir / "drift-status.json"

    if args.command == "refresh-expected":
        previous = read_json(expected_path)
        payload = build_expected_snapshot(
            host,
            inventory,
            project_dir=project_dir,
            salt_target=args.salt_target,
            previous_snapshot=previous,
        )
        write_json(expected_path, payload)
        print(f"refreshed {expected_path}")
        return 0

    expected = read_json(expected_path)
    if args.command in {"fast", "full"}:
        mode = args.command
        actual = collect_actual_snapshot(
            project_dir,
            cache_dir,
            expected or {"files": [], "system_units": [], "user_units": []},
            mode=mode,
        )
        write_json(actual_full_path if args.command == "full" else actual_fast_path, actual)
        payload = classify_drift(expected, actual, maintenance_lock_path=str(maintenance_lock_path))
        write_json(status_path, payload)
        print_report(payload, json_mode=args.json)
        return 1 if payload["status"] in {"drifted", "degraded", "unknown"} else 0

    payload = read_json(status_path) or classify_drift(
        None, {"packages": {"unmanaged": [], "missing": [], "orphans": []}}
    )
    print_report(payload, json_mode=args.json)

    expected = read_json(expected_path)
    if expected and not args.json:
        meta_parts = []
        if "git_revision" in expected:
            meta_parts.append(f"revision: {expected['git_revision']}")
        if "salt_target" in expected:
            meta_parts.append(f"target: {expected['salt_target']}")
        if "hostname" in expected:
            meta_parts.append(f"host: {expected['hostname']}")
        if "generated_at" in expected:
            meta_parts.append(f"generated: {expected['generated_at']}")
        if meta_parts:
            print("")
            print("Baseline snapshot:")
            for line in meta_parts:
                print(f"  {line}")

    return 1 if payload["status"] in {"drifted", "degraded", "unknown"} else 0


if __name__ == "__main__":
    raise SystemExit(main())
