"""Contract tests for _macros_config.jinja — the config_file_edit macro."""

from tests import REPO_ROOT_PATH

_CONFIG_MACRO = REPO_ROOT_PATH / "states" / "_macros_config.jinja"
_SOURCE = _CONFIG_MACRO.read_text()


def test_config_file_edit_macro_exists():
    assert "{%- macro config_file_edit(" in _SOURCE


def test_idempotency_guard_present():
    assert "- unless:" in _SOURCE or "- onlyif:" in _SOURCE


def test_retry_support():
    assert "- retry:" in _SOURCE
    assert "retry_attempts" in _SOURCE
    assert "retry_interval" in _SOURCE


def test_check_pattern_auto_guard():
    assert "check_pattern" in _SOURCE
    assert "check_file" in _SOURCE
    assert "grep -q" in _SOURCE


def test_imports_from_macros_common():
    assert "from '_macros_common.jinja'" in _SOURCE
