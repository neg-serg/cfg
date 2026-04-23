import json
import os
import stat
import subprocess
import textwrap
from pathlib import Path

from tests import REPO_ROOT_PATH


def read(path: str) -> str:
    return (REPO_ROOT_PATH / path).read_text()


def test_hypr_browser_binding_prefers_zen_and_keeps_floorp_secondary():
    text = read("dotfiles/dot_config/hypr/bindings/apps.conf")
    primary = (
        "bind = $M4, w, exec, raise --match "
        f'"class:regex={PRIMARY_BROWSER_REGEX}" '
        "--launch zen-browser"
    )
    secondary = (
        "bind = $M4+$S, w, exec, raise --match "
        f'"class:regex={FLOORP_BROWSER_REGEX}" '
        "--launch floorp"
    )
    assert primary in text
    assert secondary in text


def test_wayfire_browser_binding_prefers_zen_and_keeps_floorp_secondary():
    text = read("dotfiles/dot_config/wayfire.ini")
    primary = (
        "command_browser = raise --match "
        f'"class:regex={PRIMARY_BROWSER_REGEX}" '
        "--launch zen-browser"
    )
    secondary = (
        "command_browser_floorp = raise --match "
        f'"class:regex={FLOORP_BROWSER_REGEX}" '
        "--launch floorp"
    )
    assert primary in text
    assert secondary in text


def test_wlr_which_key_browser_menu_prefers_zen_and_keeps_floorp_secondary():
    text = read("dotfiles/dot_config/wlr-which-key/config.yaml")
    assert f'cmd: raise --match "class:regex={PRIMARY_BROWSER_REGEX}" --launch zen-browser' in text
    assert '- key: "W"' in text
    assert "desc: Floorp Browser" in text
    assert f'cmd: raise --match "class:regex={FLOORP_BROWSER_REGEX}" --launch floorp' in text


def test_generated_hypr_shortcuts_index_contains_browser_and_selector_entries():
    data = json.loads(read("dotfiles/dot_config/hypr/generated/shortcuts.json"))
    by_id = {entry["id"]: entry for entry in data}

    assert by_id["apps.browser"]["hotkey"] == "Super+W"
    assert by_id["apps.browser_floorp"]["hotkey"] == "Super+Shift+W"
    assert by_id["selectors.wallpaper"]["hotkey"] == "Super+Alt+S, W"
    assert by_id["selectors.wallpaper"]["mode"] == "docs_only"


def test_hypr_shortcuts_script_reads_generated_shortcut_json():
    text = read("dotfiles/dot_local/bin/executable_hypr-shortcuts")

    assert "$HOME/.config/hypr/generated/shortcuts.json" in text
    assert 'select(.mode == "launchable")' in text
    assert "@tsv" in text
    assert 'jq -r --arg id "$selection_id"' in text


def test_hypr_slash_bind_opens_hotkey_search_without_conflicts():
    bindings = read("dotfiles/dot_config/hypr/bindings.conf")
    misc = read("dotfiles/dot_config/hypr/bindings/misc.conf")
    media = read("dotfiles/dot_config/hypr/bindings/media.conf")

    assert "bind = $M4, slash, exec, ~/.local/bin/hypr-shortcuts" in misc
    assert "bind = $M4, slash, workspace, previous" not in bindings
    assert "bind = $M4+$S, slash, exec, ~/.local/bin/hypr-shortcuts" not in misc
    assert "bind = $M4+$S, slash, exec, ~/.local/bin/sink-switch select" not in media


def write_executable(path: Path, content: str) -> None:
    path.write_text(textwrap.dedent(content).lstrip())
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


def run_hypr_shortcuts(tmp_path: Path, dataset: list[dict] | str, *, selection: str = ""):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    input_capture = tmp_path / "vicinae-input.txt"
    output_capture = tmp_path / "command-output.txt"
    called_capture = tmp_path / "vicinae-called.txt"
    data_file = tmp_path / "shortcuts.json"

    if isinstance(dataset, str):
        data_file.write_text(dataset)
    else:
        data_file.write_text(json.dumps(dataset))

    write_executable(
        bin_dir / "vicinae",
        f"""
        #!/usr/bin/env zsh
        setopt ERR_EXIT NOUNSET PIPE_FAIL
        cat > "{input_capture}"
        : > "{called_capture}"
        if [[ -n "${{VICINAE_SELECTION:-}}" ]]; then
          printf '%s' "$VICINAE_SELECTION"
        fi
        """,
    )

    env = os.environ.copy()
    env.update(
        {
            "PATH": f"{bin_dir}:{env['PATH']}",
            "HYPR_SHORTCUTS_DATA": str(data_file),
            "HYPR_TEST_OUTPUT": str(output_capture),
            "VICINAE_SELECTION": selection,
        }
    )

    result = subprocess.run(
        [
            "zsh",
            str(REPO_ROOT_PATH / "dotfiles" / "dot_local" / "bin" / "executable_hypr-shortcuts"),
        ],
        cwd=REPO_ROOT_PATH,
        env=env,
        capture_output=True,
        text=True,
    )

    return result, input_capture, output_capture, called_capture


def test_hypr_shortcuts_executes_selected_launchable_entry_from_generated_data(tmp_path):
    dataset = [
        {
            "id": "apps.browser",
            "label": "Apps / Browser  Super+W",
            "command": 'printf %s "$HYPR_TEST_OUTPUT" > "$HYPR_TEST_OUTPUT"',
            "mode": "docs_only",
        },
        {
            "id": "apps.terminal",
            "label": "Apps / Terminal  Super+X",
            "command": 'printf terminal > "$HYPR_TEST_OUTPUT"',
            "mode": "launchable",
        },
    ]

    result, input_capture, output_capture, _ = run_hypr_shortcuts(
        tmp_path,
        dataset,
        selection="apps.terminal\tApps / Terminal  Super+X",
    )

    assert result.returncode == 0
    assert output_capture.read_text() == "terminal"
    assert input_capture.read_text() == "apps.terminal\tApps / Terminal  Super+X"


def test_hypr_shortcuts_duplicate_labels_still_execute_the_selected_id(tmp_path):
    dataset = [
        {
            "id": "apps.first",
            "label": "Apps / Browser  Super+W",
            "command": 'printf first > "$HYPR_TEST_OUTPUT.first"',
            "mode": "launchable",
        },
        {
            "id": "apps.second",
            "label": "Apps / Browser  Super+W",
            "command": 'printf second > "$HYPR_TEST_OUTPUT.second"',
            "mode": "launchable",
        },
    ]

    result, input_capture, output_capture, _ = run_hypr_shortcuts(
        tmp_path,
        dataset,
        selection="apps.second\tApps / Browser  Super+W",
    )

    assert result.returncode == 0
    assert not output_capture.exists()
    assert (tmp_path / "command-output.txt.second").read_text() == "second"
    assert not (tmp_path / "command-output.txt.first").exists()
    assert input_capture.read_text().splitlines() == [
        "apps.first\tApps / Browser  Super+W",
        "apps.second\tApps / Browser  Super+W",
    ]


def test_hypr_shortcuts_reports_malformed_json_and_exits_non_zero(tmp_path):
    result, _, output_capture, called_capture = run_hypr_shortcuts(
        tmp_path,
        "{not valid json}\n",
        selection="ignored",
    )

    assert result.returncode != 0
    assert "hypr-shortcuts: failed to parse launchable shortcuts from" in result.stderr
    assert not output_capture.exists()
    assert not called_capture.exists()


def test_hypr_shared_browser_matchers_include_zen_for_routing_and_navigation():
    classes = read("dotfiles/dot_config/hypr/classes.conf")
    vars_conf = read("dotfiles/dot_config/hypr/vars.conf")
    bindings = read("dotfiles/dot_config/hypr/bindings.conf")
    workspaces = read("dotfiles/dot_config/hypr/workspaces.conf")

    assert (
        "$web = match:class "
        "(?i)^(zen|floorp|one\\.ablaze\\.floorp|floorpdeveloperedition|"
        "firefox(?:[ -]?developer[ -]?edition)?|"
        "org\\.mozilla\\.firefox(?:[ -]?developer[ -]?edition)?|"
        "librewolf|io\\.gitlab\\.librewolf-community|chromium(?:-browser)?|org\\.chromium\\.chromium|"
        "ungoogled-chromium(?:-dev)?|brave(?:-browser(?:-(?:beta|nightly))?)?|com\\.brave\\.browser|"
        "vivaldi(?:-(?:stable|snapshot))?|opera(?:-(?:beta|developer))?|thorium-browser|com\\.thorium\\.thorium|"
        "mullvad-browser|com\\.mullvad\\.browser|palemoon|net\\.palemoon\\.palemoon|qutebrowser|"
        "org\\.qutebrowser\\.qutebrowser|falkon|org\\.kde\\.falkon|midori|epiphany|org\\.gnome\\.epiphany|"
        "google-chrome(?:-(?:stable|beta|unstable))?|com\\.google\\.chrome|"
        "microsoft-edge(?:-(?:beta|dev|canary))?|com\\.microsoft\\.edge)$"
    ) in classes
    assert (
        "$browser_match = match:class "
        "(?i)^(zen|floorp|one\\.ablaze\\.floorp|floorpdeveloperedition|"
        "firefox(?:[ -]?developer[ -]?edition)?|"
        "org\\.mozilla\\.firefox(?:[ -]?developer[ -]?edition)?|"
        "librewolf|io\\.gitlab\\.librewolf-community|chromium(?:-browser)?|org\\.chromium\\.chromium|"
        "ungoogled-chromium(?:-dev)?|brave(?:-browser(?:-(?:beta|nightly))?)?|com\\.brave\\.browser|"
        "vivaldi(?:-(?:stable|snapshot))?|opera(?:-(?:beta|developer))?|thorium-browser|com\\.thorium\\.thorium|"
        "mullvad-browser|com\\.mullvad\\.browser|palemoon|net\\.palemoon\\.palemoon|qutebrowser|"
        "org\\.qutebrowser\\.qutebrowser|falkon|org\\.kde\\.falkon|midori|epiphany|org\\.gnome\\.epiphany|"
        "google-chrome(?:-(?:stable|beta|unstable))?|com\\.google\\.chrome|"
        "microsoft-edge(?:-(?:beta|dev|canary))?|com\\.microsoft\\.edge)$"
    ) in vars_conf
    assert "windowrule = match:class ^(zen)$, workspace 2 silent" in workspaces
    assert "windowrule = match:initial_class ^(zen)$, workspace 2 silent" in workspaces
    assert "windowrule = $web, workspace 2 silent" in workspaces
    assert "$browser = zen-browser" in bindings


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

FLOORP_BROWSER_REGEX = "^(floorp|one\\.ablaze\\.floorp|floorpdeveloperedition)$"
