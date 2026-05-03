#!/usr/bin/env python3
"""Lint documentation: language consistency only (Russian docs discontinued)."""

import glob
import os
import re
import sys

# Directories containing docs
DOC_DIRS = ["docs"]

# Cyrillic Unicode range
_CYRILLIC_RE = re.compile(r"[\u0400-\u04FF]")


def _collect_all_md():
    """Return list of all .md files for Cyrillic checking."""
    docs = []
    for d in DOC_DIRS:
        docs += sorted(glob.glob(os.path.join(d, "*.md")))
    docs += sorted(glob.glob("*.md"))
    return docs


def check_no_cyrillic():
    """English docs must not contain Cyrillic characters."""
    docs = _collect_all_md()
    errors = 0
    files_checked = 0
    for path in docs:
        files_checked += 1
        with open(path, encoding="utf-8") as f:
            for lineno, line in enumerate(f, 1):
                if _CYRILLIC_RE.search(line):
                    print(
                        f"\033[31mCyrillic in English doc: {path}:{lineno}: {line.rstrip()}\033[0m"
                    )
                    errors += 1
    return errors, files_checked


def main():
    cyrillic_errors, files_checked = check_no_cyrillic()
    print(f"Language consistency: {files_checked} files, {cyrillic_errors} violations")
    sys.exit(1 if cyrillic_errors else 0)


if __name__ == "__main__":
    try:
        main()
    except (OSError, KeyboardInterrupt):
        raise
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
