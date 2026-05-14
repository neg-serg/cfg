"""Contract tests for the music analysis pipeline."""

import importlib.util
import os
import stat

import host_model
import yaml

from tests import REPO_ROOT_PATH, SCRIPTS_DIR

STATES_DIR = REPO_ROOT_PATH / "states"
UNITS_DIR = STATES_DIR / "units" / "user"
DOTFILES_DIR = REPO_ROOT_PATH / "dotfiles" / "dot_local" / "bin"

_lint_path = os.path.join(SCRIPTS_DIR, "lint-jinja.py")
_spec = importlib.util.spec_from_file_location("lint_jinja", _lint_path)
_lint = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_lint)

_make_render_env = _lint._make_render_env
_resolve_import_yaml = _lint._resolve_import_yaml


def _render_music_analysis():
    orig = os.getcwd()
    os.chdir(str(REPO_ROOT_PATH))
    try:
        env = _make_render_env()
        env.globals["grains"]["host"] = "matrix-default"
        env.globals["hosts_data"] = host_model.load_hosts_yaml()
        env.globals["feature_matrix"] = host_model.load_feature_matrix()

        path = "states/music_analysis.sls"
        with open(path) as fh:
            source = fh.read()
        yaml_vars = _resolve_import_yaml(source)
        tmpl = env.get_template(path.removeprefix("states/"))
        rendered = tmpl.render(**yaml_vars)
        return yaml.safe_load(rendered) or {}
    finally:
        os.chdir(orig)


_MA_STATES = _render_music_analysis()


def _collect_funcs(states):
    funcs = set()
    for state_id, state_def in states.items():
        if isinstance(state_def, dict):
            funcs.update(state_def.keys())
    return funcs


def test_music_analysis_deploys_services_and_files():
    funcs = _collect_funcs(_MA_STATES)
    assert "cmd.run" in funcs
    assert "file.managed" in funcs


def test_music_analysis_has_essentia_validation_step():
    onchanges_found = False
    for state_id, state_def in _MA_STATES.items():
        if not isinstance(state_def, dict):
            continue
        for func, args in state_def.items():
            if isinstance(args, list):
                for item in args:
                    if isinstance(item, dict) and "onchanges" in item:
                        onchanges_found = True
    assert onchanges_found, "Expected onchanges requisites for essentia validation"


def test_music_analysis_wires_timer_and_enablement():
    state_ids = list(_MA_STATES.keys())
    assert any("timer" in sid.lower() for sid in state_ids), "Expected timer state"
    assert any("enable" in sid.lower() for sid in state_ids), "Expected enable state"
    assert "music-index.timer" in str(_MA_STATES)


def test_music_index_service_unit():
    path = UNITS_DIR / "music-index.service"
    assert path.exists()
    src = path.read_text()
    assert "Description=Music index update" in src
    assert "Type=oneshot" in src
    assert "ExecStart=%h/.local/bin/music-index" in src


def test_music_index_timer_unit():
    path = UNITS_DIR / "music-index.timer"
    assert path.exists()
    src = path.read_text()
    assert "Description=Weekly music index" in src
    assert "OnCalendar=weekly" in src
    assert "WantedBy=timers.target" in src


def test_music_tui_script_exists():
    path = DOTFILES_DIR / "executable_music-tui"
    assert path.exists()
    mode = os.stat(path).st_mode
    assert mode & stat.S_IXUSR
    src = path.read_text()
    assert src.startswith("#!/usr/bin/env zsh")
    assert "mode_similar" in src
    assert "mode_classify" in src
    assert "mode_profile" in src
    assert "mode_interactive" in src
