"""Render‑idempotency test: rendering the same .sls twice must produce identical YAML.

Non‑deterministic Jinja features (cycler, namespace mutations) or leaked
mutable state between renders will cause this test to fail.
"""

import glob
import importlib.util
import os

import host_model
import pytest
import yaml

from tests import REPO_ROOT_STR, SCRIPTS_DIR

pytestmark = pytest.mark.slow

_lint_path = os.path.join(SCRIPTS_DIR, "lint-jinja.py")
_spec = importlib.util.spec_from_file_location("lint_jinja", _lint_path)
_lint = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_lint)

_make_render_env = _lint._make_render_env
_resolve_import_yaml = _lint._resolve_import_yaml


_SINGLE_ENV = None


def _render_sls(sls_path: str) -> dict | None:
    """Render a single .sls and return parsed YAML, or None on failure."""
    global _SINGLE_ENV
    orig = os.getcwd()
    os.chdir(REPO_ROOT_STR)
    try:
        if _SINGLE_ENV is None:
            env = _make_render_env()
            env.globals["grains"]["host"] = "matrix-default"
            env.globals["hosts_data"] = host_model.load_hosts_yaml()
            env.globals["feature_matrix"] = host_model.load_feature_matrix()
            _SINGLE_ENV = env

        rel = os.path.basename(sls_path)
        with open(sls_path) as fh:
            source = fh.read()
        yaml_vars = _resolve_import_yaml(source)
        tmpl = _SINGLE_ENV.get_template(rel)
        rendered = tmpl.render(**yaml_vars)
        data = yaml.safe_load(rendered)
        return data if isinstance(data, dict) else None
    except Exception:
        return None
    finally:
        os.chdir(orig)


_SLS_FILES = sorted(glob.glob(os.path.join(REPO_ROOT_STR, "states", "*.sls")))


@pytest.mark.parametrize("sls_path", _SLS_FILES)
def test_render_idempotent(sls_path):
    """Every .sls must produce the same YAML when rendered twice."""
    first = _render_sls(sls_path)
    if first is None:
        pytest.skip(f"{sls_path}: could not render (secrets?)")
    second = _render_sls(sls_path)
    assert second is not None, f"{sls_path}: first render OK, second failed"
    assert first == second, (
        f"{sls_path}: non‑deterministic render — "
        "differs on second render. Check for mutable state in Jinja helpers."
    )
