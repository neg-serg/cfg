
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



def test_render_which_key_config_keeps_browser_menu_and_wraps_shell_commands():
    actions = gen.load_bindings(
        REPO_ROOT_PATH / "dotfiles" / "dot_config" / "hypr" / "bindings.conf"
    )
    metadata = gen.load_metadata(
        REPO_ROOT_PATH / "dotfiles" / "dot_config" / "hypr" / "shortcuts.yaml"
    )

    rendered = gen.render_which_key_config(actions, metadata)

    assert "desc: Browser" in rendered
    assert (
        f'cmd: raise --match "class:regex={PRIMARY_BROWSER_REGEX}" --launch zen-browser' in rendered
    )
    assert '- key: "W"' in rendered
    assert "desc: Floorp Browser" in rendered
    assert '- key: "e"' in rendered
    assert "desc: Selectors" in rendered
    assert "cmd: hyde-selector wallpaper" in rendered
    assert "desc: Full screen" in rendered
    assert "cmd: sh -lc" in rendered
    assert 'pic-info \\"$shot\\"' in rendered
    assert "namespace:" not in rendered



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


def test_hierarchical_key_hint_mode_runs_from_shortcuts():
    misc_conf = (
        REPO_ROOT_PATH / "dotfiles" / "dot_config" / "hypr" / "bindings" / "misc.conf"
    ).read_text()

    assert "bind = $M4, i, exec, wlr-which-key" in misc_conf


PRIMARY_BROWSER_REGEX = (
    "(?i)^(zen|floorp|one\\.ablaze\\.floorp|floorpdeveloperedition|"
    "firefox(?:[ -]?developer[ -]?edition)?|org\\.mozilla\\.firefox(?:[ -]?developer[ -]?edition)?|"
    "librewolf|io\\.gitlab\\.librewolf-community|chromium(?:-browser)?|org\\.chromium\\.chromium|"
    "ungoogled-chromium(?:-dev)?|brave(?:-browser(?:-(?:beta|nightly))?)?|com\\.brave\\.browser|"
    "vivaldi(?:-(?:stable|snapshot))?|opera(?:-(?:beta|developer))?|thorium-browser|com\\.thorium\\.thorium|"
    "mullvad-browser|com\\.mullvad\\.browser|palemoon|net\\.palemoon\\.palemoon|qutebrowser|"
    "org\\.qutebrowser\\.qutebrowser|falkon|org\\.kde\\.falkon|midori|epiphany|org\\.gnome\\.epiphany|"
    "google-chrome(?:-(?:stable|beta|unstable))?|com\\.google\\.chrome|"
    "microsoft-edge(?:-(?:beta|dev|canary))?|com\\.microsoft\\.edge)$"
)
