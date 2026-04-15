"""Shared constants for the Salt test suite.

Import from this module in test files to get REPO_ROOT and SCRIPTS_DIR
without duplicating path computation logic.
"""

import sys
from pathlib import Path

REPO_ROOT_PATH = Path(__file__).resolve().parents[1]
REPO_ROOT_STR = str(REPO_ROOT_PATH)
SCRIPTS_DIR = str(REPO_ROOT_PATH / "scripts")

# Add scripts/ to sys.path so host_model and other helpers are importable
if SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, SCRIPTS_DIR)
