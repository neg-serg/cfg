"""Contract tests for _macros_desktop.jinja — browser, hyprpm, dconf macros."""

from tests import REPO_ROOT_PATH

_DESKTOP_MACRO = REPO_ROOT_PATH / "states" / "_macros_desktop.jinja"
_SOURCE = _DESKTOP_MACRO.read_text()


def test_all_five_macros_defined():
    assert "{%- macro browser_extensions(" in _SOURCE
    assert "{%- macro hyprpm_update(" in _SOURCE
    assert "{%- macro hyprpm_add(" in _SOURCE
    assert "{%- macro hyprpm_enable(" in _SOURCE
    assert "{%- macro dconf_settings(" in _SOURCE


def test_browser_extensions_has_unwanted_removal():
    assert "file.absent:" in _SOURCE
    assert ".xpi" in _SOURCE


def test_browser_extensions_resets_extensions_json():
    assert "extensions.json" in _SOURCE
    assert "onchanges_any" in _SOURCE


def test_hyprpm_macros_have_onlyif_guard():
    assert "HYPRLAND_INSTANCE_SIGNATURE" in _SOURCE
    assert "onlyif:" in _SOURCE
    assert "hyprpm" in _SOURCE


def test_hyprpm_macros_have_unless_guard():
    assert "unless:" in _SOURCE
    assert "hyprpm list" in _SOURCE


def test_hyprpm_macros_use_env_block():
    assert "XDG_RUNTIME_DIR" in _SOURCE
    assert "HYPRLAND_INSTANCE_SIGNATURE" in _SOURCE


def test_dconf_settings_has_idempotency():
    assert "dconf write" in _SOURCE
    assert "dconf read" in _SOURCE
    assert "DBUS_SESSION_BUS_ADDRESS" in _SOURCE


def test_dconf_settings_escapes_special_chars():
    assert "replace('\\\\'," in _SOURCE
    assert "replace('$'," in _SOURCE


def test_imports_from_macros_common():
    assert "from '_macros_common.jinja'" in _SOURCE


def test_imports_from_macros_service():
    assert "from '_macros_service.jinja'" in _SOURCE


def test_imports_from_macros_install():
    assert "from '_macros_install.jinja'" in _SOURCE
