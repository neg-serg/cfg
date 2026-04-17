import json
from pathlib import Path

import generate_hypr_shortcuts as gen
from tests import REPO_ROOT_PATH


def test_load_bindings_follows_source_graph_and_excludes_unsourced_files(tmp_path):
    bindings_root = tmp_path / "bindings.conf"
    bindings_dir = tmp_path / "bindings"
    bindings_dir.mkdir()

    bindings_root.write_text(
        "source = ~/.config/hypr/bindings/apps.conf\nbind = $M4, q, exec, root-launch\n"
    )
    (bindings_dir / "apps.conf").write_text(
        "source = ~/.config/hypr/bindings/nested.conf\nbind = $M4, w, exec, app-launch\n"
    )
    (bindings_dir / "nested.conf").write_text("bind = $M1, e, exec, nested-launch\n")
    (bindings_dir / "unsourced.conf").write_text("bind = $M4, z, exec, should-not-appear\n")

    actions = gen.load_bindings(bindings_root)

    arguments = {action.argument for action in actions}
    assert "root-launch" in arguments
    assert "app-launch" in arguments
    assert "nested-launch" in arguments
    assert "should-not-appear" not in arguments


def test_build_search_entries_uses_repo_metadata_and_marks_unsourced_selectors_as_docs_only():
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
    assert by_id["selectors.wallpaper"] == {
        "id": "selectors.wallpaper",
        "title": "Wallpaper Selector",
        "group": "Selectors",
        "hotkey": "Super+Alt+S, W",
        "command": "hyde-selector wallpaper",
        "mode": "docs_only",
        "keywords": ["wallpaper", "selector", "hyde"],
        "label": "Selectors / Wallpaper Selector  Super+Alt+S, W",
    }


def test_render_which_key_config_keeps_browser_menu_and_wraps_shell_commands():
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
    assert "desc: Full screen" in rendered
    assert "cmd: sh -lc" in rendered
    assert 'pic-info \\"$shot\\"' in rendered


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
    assert by_id["selectors.wallpaper"]["mode"] == "docs_only"
    assert by_id["selectors.wallpaper"]["hotkey"] == "Super+Alt+S, W"
    rendered = which_key_out.read_text()
    assert "desc: Media" in rendered
    assert "desc: Selectors" in rendered


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
