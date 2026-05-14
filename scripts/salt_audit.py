#!/usr/bin/env python3
"""Runtime data audit — tracks which states/data/*.yaml files are consumed during salt-apply.

Approach: reuses salt_impact.py's data→state dependency graph. Runs salt-call
with test=True to evaluate templates, parses output to determine which states
executed, then maps states back to their data file dependencies.

Output: logs/audit-<timestamp>.yaml with consumed/unused lists.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

import yaml

SCRIPTS_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS_DIR))
import salt_impact  # noqa: E402

EXCLUDED_DATA_FILES = {
    "feature_matrix.yaml",
    "feature_registry.yaml",
    "hosts.yaml",
}

STATE_RESULT_RE = re.compile(r"ID:\s+(\S+)")
STATE_SUCCEEDED_RE = re.compile(r"Comment:\s+(.+)")
CORE_ALWAYS_CONSUMED = {
    "hosts.yaml",
    "feature_matrix.yaml",
    "feature_registry.yaml",
}


def _build_expected_consumption(target_state: str) -> dict[str, list[str]]:
    graph = salt_impact._build_data_state_graph()
    if not graph:
        return {}
    expected: dict[str, list[str]] = {}
    for data_file, consumers in graph.items():
        if target_state == "system_description":
            expected[data_file] = consumers
        elif target_state in consumers:
            expected[data_file] = [target_state]
    return expected


def _collect_data_inventory() -> list[str]:
    data_dir = Path("states/data")
    if not data_dir.is_dir():
        return []
    return sorted(p.name for p in data_dir.glob("*.yaml") if p.name not in EXCLUDED_DATA_FILES)


def _run_salt_test(target: str, test_mode: bool) -> tuple[list[str], float]:
    import time

    venv_python = os.path.join(os.path.dirname(SCRIPTS_DIR), ".venv", "bin", "python3")
    runner = str(SCRIPTS_DIR / "salt_runner.py")
    config_dir = os.path.join(os.path.dirname(SCRIPTS_DIR), ".salt_runtime")

    cmd = [
        "sudo",
        venv_python,
        "-u",
        runner,
        f"--config-dir={config_dir}",
        "--local",
        "--log-level=warning",
        "state.sls",
        target,
        "test=True",
        "--out=json",
    ]

    start = time.time()
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    except subprocess.TimeoutExpired:
        return [], time.time() - start

    duration = time.time() - start

    state_names = []
    try:
        data = json.loads(result.stdout)
        local = data.get("local", {})
        if isinstance(local, dict):
            state_names = [
                entry.get("__id__", entry.get("name", ""))
                for entry in local.values()
                if isinstance(entry, dict)
            ]
    except (json.JSONDecodeError, AttributeError, KeyError):
        # Fallback: try regex on text output for non-daemon runs
        output = result.stdout + result.stderr
        state_names = list(set(STATE_RESULT_RE.findall(output)))

    return sorted(state_names), duration


def _resolve_states_to_data(
    state_names: list[str],
    data_graph: dict[str, list[str]],
) -> list[dict]:
    records = []
    seen = set()

    for state in state_names:
        for data_file, consumers in data_graph.items():
            if state in consumers:
                if data_file not in seen:
                    access = "import_yaml"
                    if data_file == "kernel_params.yaml":
                        access = "j2_template"
                    records.append(
                        {
                            "data_file": data_file,
                            "consumers": [s for s in consumers if s in state_names],
                            "access_method": access,
                            "eval_count": 1,
                        }
                    )
                    seen.add(data_file)

    for data_file in CORE_ALWAYS_CONSUMED:
        if data_file not in seen:
            records.append(
                {
                    "data_file": data_file,
                    "consumers": ["host_config.jinja"],
                    "access_method": "import_yaml",
                    "eval_count": 1,
                }
            )
            seen.add(data_file)

    return sorted(records, key=lambda r: r["data_file"])


def _resolve_feature_gating(hostname: str, data_file: str) -> str | None:
    try:
        hosts_data = _load_hosts_yaml()
    except Exception:
        return None

    features = hosts_data.get("defaults", {}).get("features", {})
    if not isinstance(features, dict):
        return None

    host_config = hosts_data.get("hosts", {}).get(hostname, {}).get("features", {})

    data_to_feature = {
        "floorp.yaml": "floorp",
        "zen_browser.yaml": "floorp",
        "zen_profiles.yaml": "zen_profile",
        "monitored_services.yaml": "monitoring.alerts",
        "llama_embed.yaml": "llama_embed",
        "t5_summarization.yaml": "t5_summarization",
        "image_providers.yaml": "image_gen",
        "video_ai.yaml": "video_ai",
        "music_analysis": "music_analysis",
        "tidal": "tidal",
    }

    feature_name = data_to_feature.get(data_file)
    if not feature_name:
        return "truly_orphaned"

    parts = feature_name.split(".")
    obj = features
    host_obj = host_config
    for part in parts:
        if isinstance(obj, dict) and part in obj:
            obj = obj[part]
        else:
            obj = None
        if isinstance(host_obj, dict) and part in host_obj:
            host_obj = host_obj[part]
        else:
            host_obj = None

    if isinstance(host_obj, bool) and not host_obj:
        return f"feature_gated ({feature_name}=false)"
    if isinstance(obj, bool) and not obj:
        return f"feature_gated ({feature_name}=false by default)"
    if isinstance(obj, bool) and obj:
        return "truly_orphaned"

    return "truly_orphaned"


def _load_hosts_yaml() -> dict:
    hosts_path = Path("states/data/hosts.yaml")
    if not hosts_path.is_file():
        return {}
    with hosts_path.open() as fh:
        return yaml.safe_load(fh.read()) or {}


def _get_hostname() -> str:
    hosts = _load_hosts_yaml()
    aliases = hosts.get("aliases", {})
    return aliases.get(os.uname().nodename, os.uname().nodename)


def generate_audit_report(
    target: str,
    test_mode: bool,
    hostname: str | None = None,
) -> dict:
    if hostname is None:
        hostname = _get_hostname()

    data_graph = _build_expected_consumption(target)
    inventory = _collect_data_inventory()

    state_names, duration = _run_salt_test(target, test_mode)
    consumed = _resolve_states_to_data(state_names, data_graph)

    consumed_files = {r["data_file"] for r in consumed}
    unused = sorted(set(inventory) - consumed_files)

    return {
        "version": 1,
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "hostname": hostname,
        "salt_target": target,
        "test_mode": test_mode,
        "duration_seconds": round(duration, 1),
        "consumed": consumed,
        "unused": unused,
        "total_data_files": len(inventory),
        "consumed_count": len(consumed),
    }


def compute_unused_diff(audit_report: dict) -> list[dict]:
    unused = audit_report.get("unused", [])
    hostname = audit_report.get("hostname", "")
    diff = []
    for data_file in sorted(unused):
        reason = _resolve_feature_gating(hostname, data_file)
        diff.append(
            {
                "data_file": data_file,
                "reason": reason or "truly_orphaned",
            }
        )
    return diff


def write_audit_log(report: dict) -> Path:
    log_dir = Path("logs")
    log_dir.mkdir(exist_ok=True)
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    path = log_dir / f"audit-{ts}.yaml"
    with path.open("w") as fh:
        yaml.dump(report, fh, default_flow_style=False, allow_unicode=True)
    return path


def print_diff(diff: list[dict]) -> None:
    if not diff:
        try:
            from lib.pretty import pretty

            pretty.ok("All inventoried data files were consumed.")
        except ImportError:
            print("All inventoried data files were consumed.")
        return

    gated = [d for d in diff if d["reason"].startswith("feature_gated")]
    orphaned = [d for d in diff if d["reason"] == "truly_orphaned"]
    other = [d for d in diff if d not in gated and d not in orphaned]

    try:
        from lib.pretty import pretty
    except ImportError:
        pretty = None

    if gated:
        if pretty:
            pretty.warn(f"Feature-gated: {len(gated)} files")
            pretty.list_items([f"{d['data_file']:<30s} {d['reason']}" for d in gated], "dash")
        else:
            print("\n  Feature-gated (not consumed because feature is disabled):")
            for d in gated:
                print(f"    - {d['data_file']:30s} {d['reason']}")
    if orphaned:
        if pretty:
            pretty.warn(f"Truly orphaned: {len(orphaned)} files")
            pretty.list_items([d["data_file"] for d in orphaned], "dash")
        else:
            print("\n  Truly orphaned (no known consumer):")
            for d in orphaned:
                print(f"    - {d['data_file']}")
    if other:
        if pretty:
            pretty.info(f"Other unused: {len(other)} files")
            pretty.list_items([f"{d['data_file']:<30s} {d['reason']}" for d in other], "dash")
        else:
            print("\n  Other:")
            for d in other:
                print(f"    - {d['data_file']:30s} {d['reason']}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", default="system_description", help="Salt state target")
    parser.add_argument("--test", action="store_true", help="Dry-run mode (test=True)")
    parser.add_argument("--diff", metavar="AUDIT_LOG", help="Compute unused diff from audit log")
    args = parser.parse_args()

    if args.diff:
        try:
            with open(args.diff) as fh:
                report = yaml.safe_load(fh.read())
        except FileNotFoundError:
            try:
                from lib.pretty import pretty as _p

                _p.fail(f"Audit log not found: {args.diff}")
            except ImportError:
                print(f"Audit log not found: {args.diff}", file=sys.stderr)
            return 1
        except yaml.YAMLError as e:
            try:
                from lib.pretty import pretty as _p

                _p.fail(f"Audit log YAML error: {e}")
            except ImportError:
                print(f"Audit log YAML error: {e}", file=sys.stderr)
            return 1

        diff = compute_unused_diff(report)
        _print_report_header(report)
        print_diff(diff)
        return 0

    try:
        report = generate_audit_report(args.target, args.test)
    except Exception as exc:
        print(f"Audit failed: {exc}", file=sys.stderr)
        error_report = {
            "version": 1,
            "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "hostname": _get_hostname(),
            "salt_target": args.target,
            "test_mode": args.test,
            "duration_seconds": 0,
            "consumed": [],
            "unused": [],
            "total_data_files": 0,
            "consumed_count": 0,
            "error": str(exc),
        }
        path = write_audit_log(error_report)
        print(f"Audit log (with error): {path}")
        return 1

    path = write_audit_log(report)
    _print_report_header(report)
    print(f"\nAudit log: {path}")

    diff = compute_unused_diff(report)
    print_diff(diff)

    return 0


def _print_report_header(report: dict) -> None:
    try:
        from lib.pretty import pretty

        pretty.section("Salt Data Audit")
        pretty.key_value(
            {
                "Target": str(report.get("salt_target", "")),
                "Host": str(report.get("hostname", "")),
                "Test mode": str(report.get("test_mode", "")),
                "Duration": pretty.elapsed(report.get("duration_seconds", 0)),
                "Consumed": (
                    f"{report.get('consumed_count', 0)}/"
                    f"{report.get('total_data_files', 0)} data files"
                ),
            }
        )
    except ImportError:
        print("=== Salt Data Audit ===")
        print(
            f"Target: {report.get('salt_target')}  "
            f"Host: {report.get('hostname')}  "
            f"Test: {report.get('test_mode')}  "
            f"Duration: {report.get('duration_seconds', 0)}s"
        )
        print(
            f"Consumed: {report.get('consumed_count')}/{report.get('total_data_files')} data files"
        )


if __name__ == "__main__":
    raise SystemExit(main())
