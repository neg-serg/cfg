"""Python 3.14 compatibility shims for Salt.

Salt 3008+ handles PEP 594 removals (crypt, spwd) natively.
This module retains only Python 3.14-specific patches:
  - Multiprocessing fork fix: Python 3.14 defaulted to forkserver
  - URL fix: urlunparse normalization breaks salt:// URL creation

Call patch() before importing any salt module.
"""

import importlib
import importlib.abc
import multiprocessing
import sys


def patch():
    """Install Python 3.14 stdlib patches for Salt compatibility."""
    # Python 3.14 changed default multiprocessing start method from 'fork' to
    # 'forkserver' on Linux.  Salt's parallel state execution (parallel: True)
    # passes unpicklable objects through call_parallel and its Process.__new__
    # only sets pickling attrs on spawning_platform().  Force 'fork'.
    if sys.version_info >= (3, 14):
        try:
            multiprocessing.set_start_method("fork")
        except RuntimeError:
            pass  # already set

    # Python 3.14: urlunparse normalizes file:///path differently, breaking
    # salt.utils.url.create().
    if sys.version_info >= (3, 14):
        _patch_url_module()
        _install_url_patch()


def _patched_url_create(path, saltenv=None):
    """Replacement for salt.utils.url.create that handles Python 3.14+ urlunparse."""
    from urllib.parse import urlunparse

    import salt.utils.data

    path = path.replace("\\", "/")
    query = f"saltenv={saltenv}" if saltenv else ""
    url = salt.utils.data.decode(urlunparse(("file", "", path, "", query, "")))
    # Python 3.14 urlunparse may produce either:
    # - file:path?saltenv=base        for relative paths
    # - file:///abs/path?saltenv=base for absolute paths
    # Preserve relative paths exactly; strip only the extra leading slashes from
    # absolute paths.
    suffix = url.split("file:", 1)[1]
    if suffix.startswith("///"):
        suffix = suffix[2:]
    return f"salt://{suffix}"


class _SaltUrlPatchFinder(importlib.abc.MetaPathFinder):
    """Meta path finder that patches salt.utils.url.create after import."""

    def find_module(self, fullname, path=None):
        if fullname == "salt.utils.url":
            return self
        return None

    def load_module(self, fullname):
        # Remove ourselves to avoid recursion
        sys.meta_path.remove(self)
        # Let the real import happen
        mod = importlib.import_module(fullname)
        # Patch the create function
        mod.create = _patched_url_create
        return mod


def _install_url_patch():
    """Install a meta path finder that patches salt.utils.url on first import."""
    if not any(isinstance(finder, _SaltUrlPatchFinder) for finder in sys.meta_path):
        sys.meta_path.insert(0, _SaltUrlPatchFinder())


def _patch_url_module():
    """Import and patch salt.utils.url.create deterministically."""
    module = importlib.import_module("salt.utils.url")
    module.create = _patched_url_create
