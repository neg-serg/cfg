#!/usr/bin/env python3
"""
Format /etc/fstab with aligned columns, preserving comments and blank lines.
Only non‑comment lines are reformatted; column widths are computed across all data lines.

Usage:
  format-fstab.py          # format if needed
  format-fstab.py --check  # return 0 if already formatted, 1 otherwise
  format-fstab.py --dry-run # show what would change, don't modify
"""

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def read_fstab(path: Path):
    """Return (all_lines, data_indices, data_lines)."""
    lines = path.read_text().splitlines()
    data_indices = []
    data_lines = []
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("#") or not stripped:
            continue
        data_indices.append(i)
        data_lines.append(line)
    return lines, data_indices, data_lines


def format_data_lines(data_lines):
    """Return list of formatted lines (same order)."""
    with tempfile.NamedTemporaryFile(mode="w+") as infile:
        infile.write("\n".join(data_lines))
        infile.flush()
        try:
            result = subprocess.run(
                ["column", "-t", infile.name],
                capture_output=True,
                text=True,
                check=True,
            )
        except subprocess.CalledProcessError as e:
            print(f"column failed: {e.stderr}", file=sys.stderr)
            sys.exit(e.returncode)
        except FileNotFoundError:
            print("error: column not found (install util-linux)", file=sys.stderr)
            sys.exit(1)
        formatted = result.stdout.splitlines()
        if len(formatted) != len(data_lines):
            print("error: column changed line count", file=sys.stderr)
            sys.exit(1)
        return formatted


def main() -> None:
    check = False
    dry_run = False
    for arg in sys.argv[1:]:
        if arg in ("-h", "--help"):
            print(__doc__)
            sys.exit(0)
        elif arg == "--check":
            check = True
        elif arg == "--dry-run":
            dry_run = True
        else:
            print(f"unknown argument: {arg}", file=sys.stderr)
            sys.exit(1)

    fstab = Path("/etc/fstab")
    if not fstab.is_file():
        print("error: /etc/fstab does not exist", file=sys.stderr)
        sys.exit(1)

    lines, data_indices, data_lines = read_fstab(fstab)
    if not data_lines:
        # No data lines, nothing to format
        if check:
            sys.exit(0)
        return

    formatted = format_data_lines(data_lines)
    # Check if formatting would change anything
    changed = any(lines[i] != formatted[j] for j, i in enumerate(data_indices))
    if check:
        sys.exit(0 if not changed else 1)
    if dry_run:
        if changed:
            print("--- /etc/fstab (current) ---")
            print("\n".join(lines))
            print("\n--- /etc/fstab (formatted) ---")
            new_lines = lines.copy()
            for idx, new_line in zip(data_indices, formatted):
                new_lines[idx] = new_line
            print("\n".join(new_lines))
        else:
            print("No changes required.")
        return
    if not changed:
        return
    # Apply formatting
    for idx, new_line in zip(data_indices, formatted):
        lines[idx] = new_line
    # Write back atomically
    with tempfile.NamedTemporaryFile(mode="w", dir=fstab.parent, delete=False) as tmp:
        tmp.write("\n".join(lines) + "\n")
        tmp_path = tmp.name
    shutil.move(tmp_path, fstab)


if __name__ == "__main__":
    main()
