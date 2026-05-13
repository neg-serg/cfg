#!/usr/bin/env python3
"""Salt-call wrapper with compatibility shims for Python 3.13+.

Usage:
  python3 scripts/salt_runner.py --config-dir=.salt_runtime --local state.sls ...
"""

import os
import sys

import salt_compat

salt_compat.patch()

import salt.scripts
import salt.loader as _salt_loader

# Patch Salt's _module_dirs to include our custom modules directory.
_salt_loader._module_dirs_orig = getattr(_salt_loader, "_module_dirs_orig", None) or _salt_loader._module_dirs

def _patched_module_dirs(*args, **kwargs):
    dirs = _salt_loader._module_dirs_orig(*args, **kwargs)
    # args[0] is opts, args[1] is ext_type (modules, grains, states, etc.)
    if len(args) > 1 and args[1] == "modules":
        _project_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        _mod_path = os.path.join(_project_dir, "states", "_modules")
        if _mod_path not in dirs:
            dirs.append(_mod_path)
    return dirs

_salt_loader._module_dirs = _patched_module_dirs

# salt.scripts was imported as 'salt.scripts' above; call salt_call directly
import salt.scripts
salt.scripts.salt_call()
