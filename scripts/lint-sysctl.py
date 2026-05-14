#!/usr/bin/env python3
"""
lint-sysctl: two-part sysctl hygiene check.

1. Drift: every param in sysctl-custom.conf must match the live kernel value.
2. Unmanaged: /etc/sysctl.d/ must contain only Salt-managed or package-owned files.

Run from project root. Most params are readable as a regular user;
if READ_FAIL entries appear, retry with sudo.
"""

import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.pretty import pretty

SYSCTL_CONF = Path("states/configs/sysctl-custom.conf")
SYSCTL_ETC_DIR = Path("/etc/sysctl.d")

# Files Salt actively manages in /etc/sysctl.d/
SALT_MANAGED = {"99-custom.conf"}

# Symlinks/stubs placed by packages — not user-managed, not a problem
KNOWN_PACKAGE_FILES = {"99-sysctl.conf"}  # procps: symlink → /etc/sysctl.conf


def parse_conf(path: Path) -> dict[str, str]:
    """Parse 'key = value' pairs from sysctl config, skip comments/blanks."""
    params: dict[str, str] = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" in line:
            key, _, val = line.partition("=")
            params[key.strip()] = val.strip()
    return params


def live_value(key: str) -> str | None:
    r = subprocess.run(["sysctl", "-n", key], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else None


def pkg_owner(path: Path) -> str | None:
    """Return 'pkg-name version' if pacman owns the file, else None."""
    r = subprocess.run(["pacman", "-Qo", str(path)], capture_output=True, text=True)
    if r.returncode == 0:
        # "path is owned by pkgname version" → extract "pkgname version"
        parts = r.stdout.strip().split()
        return " ".join(parts[-2:]) if len(parts) >= 2 else r.stdout.strip()
    return None


def check_drift(conf_path: Path) -> tuple[int, int]:
    """Compare every param in conf against the live kernel. Return (errors, total)."""
    params = parse_conf(conf_path)
    errors = 0
    for key, expected in params.items():
        live = live_value(key)
        if live is None:
            pretty.fail(f"READ_FAIL {key}  (param unreadable or unknown)")
            errors += 1
        elif live != expected:
            pretty.fail(f"DRIFT     {key}")
            pretty.key_value({"expected": expected, "live": live})
            errors += 1
        else:
            pretty.ok(f"OK        {key} = {live}")
    return errors, len(params)


def check_unmanaged() -> int:
    """Find /etc/sysctl.d/ files not owned by Salt or a package. Return count."""
    if not SYSCTL_ETC_DIR.exists():
        return 0
    unmanaged = 0
    for f in sorted(SYSCTL_ETC_DIR.iterdir()):
        if f.name in SALT_MANAGED:
            pretty.ok(f"MANAGED   {f}")
            continue
        if f.name in KNOWN_PACKAGE_FILES:
            pretty.info(f"SKIP      {f}  (known package stub)")
            continue
        owner = pkg_owner(f)
        if owner:
            pretty.info(f"PKG       {f}  ({owner})")
        else:
            pretty.fail(f"UNMANAGED {f}")
            unmanaged += 1
    return unmanaged


def main() -> None:
    if not SYSCTL_CONF.exists():
        pretty.fail(f"ERROR: {SYSCTL_CONF} not found — run from project root")
        sys.exit(1)

    total_errors = 0

    pretty.header(f"Drift check: {SYSCTL_CONF}")
    drift_errors, param_count = check_drift(SYSCTL_CONF)
    total_errors += drift_errors
    if drift_errors:
        pretty.summary_line(param_count - drift_errors, drift_errors, "Sysctl params")
        pretty.info("hint: some params may need root — retry with sudo")
    else:
        pretty.ok(f"{param_count} params checked, all applied")

    pretty.header(f"Unmanaged files: {SYSCTL_ETC_DIR}")
    unmanaged = check_unmanaged()
    total_errors += unmanaged
    if unmanaged == 0:
        pretty.ok("No unmanaged sysctl.d files")
    else:
        pretty.fail(f"{unmanaged} unmanaged file(s) — add to Salt or remove")

    sys.exit(1 if total_errors else 0)


if __name__ == "__main__":
    try:
        main()
    except (OSError, KeyboardInterrupt):
        raise
    except Exception as e:
        pretty.fail(f"Error: {e}")
        sys.exit(1)
