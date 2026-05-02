"""Regression tests for the OptiScaler benchmark wrapper."""

from pathlib import Path
import subprocess


WRAPPER_PATH = Path("/home/neg/src/cfg/dotfiles/dot_local/bin/executable_optiscaler-benchmark")


def test_optiscaler_wrapper_exists():
    assert WRAPPER_PATH.is_file()


def test_optiscaler_wrapper_defaults_to_diablo_iv_app_id():
    source = WRAPPER_PATH.read_text()
    assert "2344520" in source
    assert "sed \"s/<APP_ID>/" in source


def test_optiscaler_wrapper_has_valid_shell_syntax():
    result = subprocess.run(["bash", "-n", str(WRAPPER_PATH)], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr.strip()
