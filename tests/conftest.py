"""Shared pytest fixtures for the Salt test suite."""

import sys

from tests import SCRIPTS_DIR, REPO_ROOT_PATH

# Add scripts/ to sys.path so host_model and other helpers are importable
if SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, SCRIPTS_DIR)


__all__ = ["REPO_ROOT_PATH", "SCRIPTS_DIR"]
