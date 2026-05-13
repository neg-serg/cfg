"""Contract tests for _macros_config.jinja — delegates to _modules/config.py."""

from tests import REPO_ROOT_PATH

_CONFIG_MACRO = REPO_ROOT_PATH / "states" / "_macros_config.jinja"
_SOURCE = _CONFIG_MACRO.read_text()


def test_config_file_edit_delegates_to_python():
    assert "config_file_edit" in _SOURCE
    assert "salt[" in _SOURCE
    assert "config.config_file_edit" in _SOURCE


def test_imports_constants():
    assert "from '_macros_common.jinja'" in _SOURCE
    assert "retry_attempts" in _SOURCE
    assert "retry_interval" in _SOURCE


def test_config_file_edit_macro_exists():
    assert "macro config_file_edit" in _SOURCE
