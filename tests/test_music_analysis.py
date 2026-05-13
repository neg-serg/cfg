"""Contract tests for the music analysis pipeline."""

import os
import stat

from tests import REPO_ROOT_PATH

STATES_DIR = REPO_ROOT_PATH / "states"
UNITS_DIR = STATES_DIR / "units" / "user"
DOTFILES_DIR = REPO_ROOT_PATH / "dotfiles" / "dot_local" / "bin"


def test_music_analysis_state_exists():
    src = (STATES_DIR / "music_analysis.sls").read_text()
    assert "salt['pkg.paru_install']" in src
    assert "salt['user_service.user_service_file']" in src
    assert "salt['user_service.user_service_enable']" in src
    assert "{% import_yaml 'data/installers.yaml' as tools %}" in src
    assert "salt['pkg.paru_install']('python_annoy', 'python-annoy')" in src


def test_music_analysis_has_essentia_validate():
    src = (STATES_DIR / "music_analysis.sls").read_text()
    assert "essentia_validate:" in src
    assert "onchanges" in src
    assert "install_essentia" in src


def test_music_analysis_has_timer_wiring():
    src = (STATES_DIR / "music_analysis.sls").read_text()
    assert "music-index.service" in src
    assert "music-index.timer" in src
    assert "user_service_enable" in src
    assert "start_now=['music-index.timer']" in src


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
