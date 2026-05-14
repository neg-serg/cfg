"""Contract tests for managed Hiddify automation."""

import importlib.util
import os

import host_model
import yaml

from tests import REPO_ROOT_PATH as REPO_ROOT
from tests import SCRIPTS_DIR

_lint_path = os.path.join(SCRIPTS_DIR, "lint-jinja.py")
_spec = importlib.util.spec_from_file_location("lint_jinja", _lint_path)
_lint = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_lint)

_make_render_env = _lint._make_render_env
_resolve_import_yaml = _lint._resolve_import_yaml


def _render_hiddify_sls():
    orig = os.getcwd()
    os.chdir(str(REPO_ROOT))
    try:
        env = _make_render_env()
        env.globals["grains"]["host"] = "matrix-default"
        env.globals["hosts_data"] = host_model.load_hosts_yaml()
        env.globals["feature_matrix"] = host_model.load_feature_matrix()

        path = "states/hiddify.sls"
        with open(path) as fh:
            source = fh.read()
        yaml_vars = _resolve_import_yaml(source)
        tmpl = env.get_template(path.removeprefix("states/"))
        rendered = tmpl.render(**yaml_vars)
        return yaml.safe_load(rendered) or {}
    finally:
        os.chdir(orig)


_HIDDIFY_STATES = _render_hiddify_sls()


def _collect_state_types(states):
    types = set()
    for state_id, state_def in states.items():
        if isinstance(state_def, dict):
            for func in state_def:
                types.add((state_id, func))
    return types


def test_system_description_includes_hiddify_state_by_default():
    source = (REPO_ROOT / "states" / "system_description.sls").read_text()

    assert "- hiddify" in source


def test_hiddify_state_manages_appimage_cleanup():
    state_types = _collect_state_types(_HIDDIFY_STATES)
    funcs = {t[1] for t in state_types}

    assert "file.absent" in funcs
    assert any("legacy" in sid.lower() or "cleanup" in sid.lower() for sid, _ in state_types)


def test_hiddify_state_includes_gui_capabilities_setup():
    state_types = _collect_state_types(_HIDDIFY_STATES)
    funcs = {t[1] for t in state_types}

    assert "cmd.run" in funcs
    assert any("gui" in sid.lower() for sid, _ in state_types)


def test_hiddify_state_includes_cli_tool_setup():
    state_types = _collect_state_types(_HIDDIFY_STATES)

    assert any("caps" in sid.lower() or "cli" in sid.lower() for sid, _ in state_types)


def test_hiddify_local_desktop_uses_wrapper_exec_and_hiddify_mime():
    source = (
        REPO_ROOT / "dotfiles" / "dot_local" / "share" / "applications" / "hiddify.desktop"
    ).read_text()

    assert "Exec=" in source
    assert "hiddify-launch" in source
    assert "x-scheme-handler/hiddify" in source
