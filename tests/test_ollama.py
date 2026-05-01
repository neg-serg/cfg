"""Contract tests for the ollama Salt state (full render)."""

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


def _render_ollama():
    orig = os.getcwd()
    os.chdir(REPO_ROOT_STR)
    try:
        env = _make_render_env()
        env.globals["grains"]["host"] = "matrix-default"
        env.globals["hosts_data"] = host_model.load_hosts_yaml()
        env.globals["feature_matrix"] = host_model.load_feature_matrix()

        path = "states/ollama.sls"
        with open(path) as fh:
            source = fh.read()
        yaml_vars = _resolve_import_yaml(source)
        tmpl = env.get_template(path.removeprefix("states/"))
        rendered = tmpl.render(**yaml_vars)
        return yaml.safe_load(rendered) or {}
    finally:
        os.chdir(orig)


_STATES = _render_ollama()

GUARD_KEYS = {"creates", "unless", "onlyif"}
CMD_FUNCTIONS = {"cmd.run", "cmd.script"}


def _extract_cmd_states(states):
    cmd_states = []
    for state_id, state_def in states.items():
        if not isinstance(state_def, dict):
            continue
        for func, args in state_def.items():
            if func not in CMD_FUNCTIONS:
                continue
            props = {}
            for item in (args or []):
                if isinstance(item, dict):
                    props.update(item)
            cmd_states.append({
                "state_id": state_id,
                "function": func,
                "has_guard": bool(GUARD_KEYS & set(props.keys())),
            })
    return cmd_states


_CMD_STATES = _extract_cmd_states(_STATES)


def test_state_file_renders():
    assert isinstance(_STATES, dict)
    assert len(_STATES) > 0


def test_ollama_models_dir_present():
    assert "ollama_models_dir" in _STATES


def test_ollama_models_dir_is_ensure_dir():
    s = _STATES["ollama_models_dir"]
    assert isinstance(s, dict)
    assert "file.directory" in s or "ensure_dir" not in str(s)


def test_ollama_native_unit_absent():
    assert "ollama_native_unit_absent" in _STATES
    s = _STATES["ollama_native_unit_absent"]
    assert isinstance(s, dict) and "file.absent" in s


def test_ollama_container_is_container_service():
    key = next((k for k in _STATES if k.startswith("ollama_container")), None)
    assert key is not None, f"ollama_container* not found in {list(_STATES)}"
    assert isinstance(_STATES[key], dict)


def test_ollama_tmp_start_present():
    assert "ollama_tmp_start" in _STATES


def test_ollama_tmp_start_has_unless_guard():
    state = _STATES["ollama_tmp_start"]
    props = {}
    for item in state.get("cmd.run", []):
        if isinstance(item, dict):
            props.update(item)
    assert "unless" in props or "onlyif" in props


def test_ollama_tmp_stop_present():
    assert "ollama_tmp_stop" in _STATES


def test_ollama_tmp_stop_has_onlyif_guard():
    state = _STATES["ollama_tmp_stop"]
    props = {}
    for item in state.get("cmd.run", []):
        if isinstance(item, dict):
            props.update(item)
    assert "onlyif" in props


def test_ollama_state_ids():
    expected_ids = {
        "ollama_models_dir",
        "ollama_native_unit_absent",
        "ollama_tmp_start",
        "ollama_tmp_stop",
    }
    keys = set(_STATES.keys())
    missing = expected_ids - keys
    assert not missing, f"Missing state IDs: {missing}. Found: {sorted(keys)}"


def test_cmd_guards():
    unguarded = [s for s in _CMD_STATES if not s["has_guard"]]
    assert len(unguarded) == 0, f"Unguarded cmd.run states: {unguarded}"
