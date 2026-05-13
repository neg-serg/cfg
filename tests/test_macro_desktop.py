"""Contract tests for _macros_desktop.jinja — delegates to _modules/desktop.py."""

from tests import REPO_ROOT_PATH

_DESKTOP_MACRO = REPO_ROOT_PATH / "states" / "_macros_desktop.jinja"
_SOURCE = _DESKTOP_MACRO.read_text()


def test_all_five_macros_delegate_to_python():
    assert "macro browser_extensions" in _SOURCE
    assert "macro hyprpm_update" in _SOURCE
    assert "macro hyprpm_add" in _SOURCE
    assert "macro hyprpm_enable" in _SOURCE
    assert "macro dconf_settings" in _SOURCE
    assert "salt[" in _SOURCE
    assert "desktop." in _SOURCE


def test_browser_extensions_delegation():
    assert "browser_extensions" in _SOURCE
    assert "desktop.browser_extensions" in _SOURCE


def test_hyprpm_macros_delegate():
    assert "desktop.hyprpm_update" in _SOURCE
    assert "desktop.hyprpm_add" in _SOURCE
    assert "desktop.hyprpm_enable" in _SOURCE


def test_dconf_settings_delegates():
    assert "desktop.dconf_settings" in _SOURCE


def test_imports_preserved():
    assert "from '_macros_common.jinja'" in _SOURCE
    assert "from '_macros_service.jinja'" in _SOURCE
    assert "from '_macros_install.jinja'" in _SOURCE
