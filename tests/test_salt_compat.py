"""Regression tests for Salt Python-compat shims."""

import os
import sys


def test_patched_url_create_preserves_relative_paths_for_salt_lookup(monkeypatch):
    sys.path.insert(0, os.path.join(os.getcwd(), "scripts"))
    import salt_compat

    salt_compat.patch()

    import salt.utils.url

    assert salt.utils.url.create("system_description", saltenv="base") == (
        "salt://system_description?saltenv=base"
    )
    assert salt.utils.url.create("audio", saltenv="base") == "salt://audio?saltenv=base"
    assert salt.utils.url.create("group/core", saltenv="base") == (
        "salt://group/core?saltenv=base"
    )
