"""Contract tests for managed Hiddify automation."""

from tests import REPO_ROOT_PATH as REPO_ROOT


def test_system_description_includes_hiddify_state_by_default():
    source = (REPO_ROOT / "states" / "system_description.sls").read_text()

    assert "host.features.network.get('hiddify', false)" in source
    assert "- hiddify" in source


def test_hiddify_state_removes_legacy_appimage_and_prefers_hiddify_next():
    source = (REPO_ROOT / "states" / "hiddify.sls").read_text()

    assert "Hiddify.AppImage" in source
    assert "hiddify-official.desktop" in source
    assert "hiddify.desktop" in source
    assert "/usr/lib/hiddify/hiddify" in source
    assert "xdg-mime default hiddify.desktop x-scheme-handler/hiddify" in source
    assert "/usr/lib/hiddify/HiddifyCli" in source
    assert "cap_net_admin,cap_net_bind_service,cap_net_raw=ep" in source
    assert "setcap" in source
    assert "getcap" in source


def test_hiddify_local_desktop_uses_wrapper_exec():
    source = (
        REPO_ROOT / "dotfiles" / "dot_local" / "share" / "applications" / "hiddify.desktop"
    ).read_text()

    assert "Exec=/home/neg/.local/bin/hiddify-launch %U" in source
    assert "MimeType=x-scheme-handler/hiddify" in source



