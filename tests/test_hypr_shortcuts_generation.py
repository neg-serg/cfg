import json
from pathlib import Path

import generate_hypr_shortcuts as gen
from tests import REPO_ROOT_PATH


def test_load_bindings_formats_selector_sequence_from_repo():
    actions = gen.load_bindings(
        REPO_ROOT_PATH / "dotfiles" / "dot_config" / "hypr" / "bindings.conf"
    )

    wallpaper = next(
        action
        for action in actions
        if action.dispatcher == "exec" and action.argument == "hyde-selector wallpaper"
    )

    assert wallpaper.hotkey == "Super+Alt+S, W"
    assert wallpaper.submap == "selectors"
    assert wallpaper.signature == "selectors|w|exec|hyde-selector wallpaper"


def test_build_search_entries_uses_repo_metadata_for_browser_and_hides_undocumented_binds():
    actions = gen.load_bindings(
        REPO_ROOT_PATH / "dotfiles" / "dot_config" / "hypr" / "bindings.conf"
    )
    metadata = gen.load_metadata(
        REPO_ROOT_PATH / "dotfiles" / "dot_config" / "hypr" / "shortcuts.yaml"
    )

    entries = gen.build_search_entries(actions, metadata)
    by_id = {entry["id"]: entry for entry in entries}

    assert by_id["apps.browser"] == {
        "id": "apps.browser",
        "title": "Browser",
        "group": "Apps",
        "hotkey": "Super+W",
        "command": 'raise --match "class:regex=^zen$" --launch zen-browser',
        "mode": "launchable",
        "keywords": ["browser", "web", "zen"],
        "label": "Apps / Browser  Super+W",
    }
    assert "navigation.previous_workspace" not in by_id


def test_render_which_key_config_keeps_browser_floorp_and_selectors_submenu():
    actions = gen.load_bindings(
        REPO_ROOT_PATH / "dotfiles" / "dot_config" / "hypr" / "bindings.conf"
    )
    metadata = gen.load_metadata(
        REPO_ROOT_PATH / "dotfiles" / "dot_config" / "hypr" / "shortcuts.yaml"
    )

    rendered = gen.render_which_key_config(actions, metadata)

    assert "desc: Browser" in rendered
    assert 'cmd: raise --match "class:regex=^zen$" --launch zen-browser' in rendered
    assert '- key: "W"' in rendered
    assert "desc: Floorp Browser" in rendered
    assert '- key: "e"' in rendered
    assert "desc: Selectors" in rendered
    assert "cmd: hyde-selector wallpaper" in rendered


def test_main_writes_search_json_and_which_key_yaml(tmp_path):
    search_out = tmp_path / "shortcuts.json"
    which_key_out = tmp_path / "config.yaml"

    rc = gen.main(
        [
            "--bindings",
            str(REPO_ROOT_PATH / "dotfiles" / "dot_config" / "hypr" / "bindings.conf"),
            "--metadata",
            str(REPO_ROOT_PATH / "dotfiles" / "dot_config" / "hypr" / "shortcuts.yaml"),
            "--search-output",
            str(search_out),
            "--which-key-output",
            str(which_key_out),
        ]
    )

    assert rc == 0

    data = json.loads(search_out.read_text())
    by_id = {entry["id"]: entry for entry in data}
    assert by_id["selectors.wallpaper"]["hotkey"] == "Super+Alt+S, W"
    assert "desc: Media" in which_key_out.read_text()


def test_generated_repo_files_are_in_sync_with_the_generator(tmp_path):
    search_out = tmp_path / "shortcuts.json"
    which_key_out = tmp_path / "config.yaml"

    rc = gen.main(
        [
            "--bindings",
            str(REPO_ROOT_PATH / "dotfiles" / "dot_config" / "hypr" / "bindings.conf"),
            "--metadata",
            str(REPO_ROOT_PATH / "dotfiles" / "dot_config" / "hypr" / "shortcuts.yaml"),
            "--search-output",
            str(search_out),
            "--which-key-output",
            str(which_key_out),
        ]
    )

    assert rc == 0
    assert (
        search_out.read_text()
        == (
            REPO_ROOT_PATH / "dotfiles" / "dot_config" / "hypr" / "generated" / "shortcuts.json"
        ).read_text()
    )
    assert (
        which_key_out.read_text()
        == (
            REPO_ROOT_PATH / "dotfiles" / "dot_config" / "wlr-which-key" / "config.yaml"
        ).read_text()
    )
