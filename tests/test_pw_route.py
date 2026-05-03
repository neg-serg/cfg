import os
import stat
import subprocess
from pathlib import Path

from tests import REPO_ROOT_PATH

SCRIPT_PATH = REPO_ROOT_PATH / "dotfiles" / "dot_local" / "bin" / "executable_pw-route"


def _write_executable(path: Path, content: str) -> None:
    path.write_text(content)
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


def _run_pw_route(tmp_path: Path, command: str, pw_link_listing: str):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()

    pw_link_log = tmp_path / "pw-link.log"
    pw_cli_log = tmp_path / "pw-cli.log"

    _write_executable(
        bin_dir / "pw-cli",
        "#!/usr/bin/env zsh\n"
        "setopt ERR_EXIT NOUNSET PIPE_FAIL\n"
        f"print -r -- \"$*\" >> {pw_cli_log}\n"
        "if [[ \"${1:-}\" == \"list-objects\" && \"${2:-}\" == \"Node\" ]]; then\n"
        "  cat <<'EOF'\n"
        'node.name = "alsa_output.pci-0000_05_00.0.pro-output-0"\n'
        'node.nick = "RME AIO Pro"\n'
        "EOF\n"
        "fi\n",
    )

    _write_executable(
        bin_dir / "pw-link",
        "#!/usr/bin/env zsh\n"
        "setopt ERR_EXIT NOUNSET PIPE_FAIL\n"
        f"print -r -- \"$*\" >> {pw_link_log}\n"
        "if [[ \"${1:-}\" == \"-l\" || \"${1:-}\" == \"-iol\" ]]; then\n"
        "  cat <<'EOF'\n"
        f"{pw_link_listing}"
        "EOF\n"
        "fi\n",
    )

    result = subprocess.run(
        ["zsh", str(SCRIPT_PATH), command],
        cwd=REPO_ROOT_PATH,
        env={**os.environ, "PATH": f"{bin_dir}:{os.environ['PATH']}"},
        capture_output=True,
        text=True,
        check=False,
    )

    return result, pw_link_log.read_text() if pw_link_log.exists() else ""


def test_current_reports_aes_from_exact_monitor_pair(tmp_path: Path):
    listing = """alsa_output.pci-0000_05_00.0.pro-output-0:monitor_AUX0
  |-> alsa_output.pci-0000_05_00.0.pro-output-0:playback_AUX2
alsa_output.pci-0000_05_00.0.pro-output-0:monitor_AUX1
  |-> alsa_output.pci-0000_05_00.0.pro-output-0:playback_AUX3
mpd.PipeWire Output:output_FL
  |-> alsa_output.pci-0000_05_00.0.pro-output-0:playback_AUX0
mpd.PipeWire Output:output_FR
  |-> alsa_output.pci-0000_05_00.0.pro-output-0:playback_AUX1
"""

    result, _ = _run_pw_route(tmp_path, "current", listing)

    assert result.returncode == 0, result.stderr
    assert result.stdout.strip() == "aes"


def test_toggle_switches_aes_to_an_for_primary_workflow(tmp_path: Path):
    listing = """alsa_output.pci-0000_05_00.0.pro-output-0:monitor_AUX0
  |-> alsa_output.pci-0000_05_00.0.pro-output-0:playback_AUX2
alsa_output.pci-0000_05_00.0.pro-output-0:monitor_AUX1
  |-> alsa_output.pci-0000_05_00.0.pro-output-0:playback_AUX3
"""

    result, pw_link_log = _run_pw_route(tmp_path, "toggle", listing)

    assert result.returncode == 0, result.stderr
    assert "an -> AUX0/AUX1" in result.stdout
    assert "-d alsa_output.pci-0000_05_00.0.pro-output-0:monitor_AUX0 alsa_output.pci-0000_05_00.0.pro-output-0:playback_AUX2" in pw_link_log
    assert "-d alsa_output.pci-0000_05_00.0.pro-output-0:monitor_AUX1 alsa_output.pci-0000_05_00.0.pro-output-0:playback_AUX3" in pw_link_log
    assert "alsa_output.pci-0000_05_00.0.pro-output-0:monitor_AUX0 alsa_output.pci-0000_05_00.0.pro-output-0:playback_AUX0" in pw_link_log
    assert "alsa_output.pci-0000_05_00.0.pro-output-0:monitor_AUX1 alsa_output.pci-0000_05_00.0.pro-output-0:playback_AUX1" in pw_link_log


def test_toggle_prefers_aes_when_state_is_unknown_or_non_aes(tmp_path: Path):
    listing = """alsa_output.pci-0000_05_00.0.pro-output-0:monitor_AUX0
  |-> alsa_output.pci-0000_05_00.0.pro-output-0:playback_AUX6
alsa_output.pci-0000_05_00.0.pro-output-0:monitor_AUX1
  |-> alsa_output.pci-0000_05_00.0.pro-output-0:playback_AUX7
"""

    result, _ = _run_pw_route(tmp_path, "toggle", listing)

    assert result.returncode == 0, result.stderr
    assert "aes -> AUX2/AUX3" in result.stdout


def test_current_matches_known_pair_even_when_monitor_ports_have_extra_links(tmp_path: Path):
    listing = """alsa_output.pci-0000_05_00.0.pro-output-0:monitor_AUX0
  |-> loopback.debug:left
  |-> alsa_output.pci-0000_05_00.0.pro-output-0:playback_AUX2
alsa_output.pci-0000_05_00.0.pro-output-0:monitor_AUX1
  |-> loopback.debug:right
  |-> alsa_output.pci-0000_05_00.0.pro-output-0:playback_AUX3
"""

    result, _ = _run_pw_route(tmp_path, "current", listing)

    assert result.returncode == 0, result.stderr
    assert result.stdout.strip() == "aes"
