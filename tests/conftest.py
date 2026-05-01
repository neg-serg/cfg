"""Shared pytest configuration for the Salt test suite."""

import sys

from tests import REPO_ROOT_PATH, SCRIPTS_DIR

# Add scripts/ to sys.path so host_model and other helpers are importable
if SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, SCRIPTS_DIR)


def pytest_configure(config):
    """Register custom markers to suppress warnings."""
    config.addinivalue_line("markers", "slow: marks tests as slow (module-level render)")
    config.addinivalue_line("markers", "integration: marks tests as integration tests")


__all__ = ["REPO_ROOT_PATH", "SCRIPTS_DIR"]
