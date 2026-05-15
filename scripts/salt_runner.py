#!/usr/bin/env python3
"""Salt-call wrapper with compatibility shims for Python 3.13+.

Usage:
  python3 scripts/salt_runner.py --config-dir=.salt_runtime --local state.sls ...
"""

import os

import salt_compat

salt_compat.patch()

import salt.loader as _salt_loader  # noqa: E402
import salt.scripts  # noqa: E402

# Patch Salt's _module_dirs to include our custom modules directory.
_salt_loader._module_dirs_orig = (
    getattr(_salt_loader, "_module_dirs_orig", None) or _salt_loader._module_dirs
)


def _patched_module_dirs(*args, **kwargs):
    dirs = _salt_loader._module_dirs_orig(*args, **kwargs)
    # args[0] is opts, args[1] is ext_type (modules, grains, states, etc.)
    if len(args) > 1 and args[1] == "modules":
        _project_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        _mod_path = os.path.join(_project_dir, "states", "_modules")
        # Remove stale cached copies so source takes precedence
        _cache_path = os.path.join(
            kwargs.get("cachedir", "/var/cache/salt"), "minion", "extmods", "modules"
        )
        if _cache_path in dirs:
            dirs.remove(_cache_path)
        # Insert source before any cached paths
        if _mod_path not in dirs:
            dirs.insert(0, _mod_path)
        # Re-append cache after source (source overrides cache)
        if _cache_path not in dirs:
            dirs.append(_cache_path)
    return dirs


_salt_loader._module_dirs = _patched_module_dirs

# salt.scripts was imported as 'salt.scripts' above; call salt_call directly
salt.scripts.salt_call()
