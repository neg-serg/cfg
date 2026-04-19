import json
import os
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT = REPO_ROOT / "scripts" / "pkg-drift.zsh"


def _write_fake_pacman(bin_dir: Path, *, explicit: str, installed: str, orphans: str) -> None:
    (bin_dir / "pacman").write_text(
        "#!/usr/bin/env bash\n"
        "set -euo pipefail\n"
        'case "$1" in\n'
        "  -Qqe) printf '%s' \"$PACMAN_EXPLICIT\" ;;\n"
        "  -Qq) printf '%s' \"$PACMAN_INSTALLED\" ;;\n"
        "  -Qdtq) printf '%s' \"$PACMAN_ORPHANS\" ;;\n"
        "  *) exit 1 ;;\n"
        "esac\n"
    )
    os.chmod(bin_dir / "pacman", 0o755)


def test_pkg_drift_json_reports_unmanaged_missing_and_orphans(tmp_path):
    project = tmp_path / "repo"
    states = project / "states"
    data = states / "data"
    states.mkdir(parents=True)
    data.mkdir(parents=True)
    (data / "packages.yaml").write_text("base:\n  - declared-pkg\n")
    (data / "fonts.yaml").write_text("{}\n")
    (data / "installers_desktop.yaml").write_text("{}\n")
    (states / "example.sls").write_text("")

    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    _write_fake_pacman(
        bin_dir,
        explicit="declared-pkg\nunmanaged-pkg\n",
        installed="unmanaged-pkg\n",
        orphans="orphan-pkg\n",
    )

    env = os.environ | {
        "PATH": f"{bin_dir}:{os.environ['PATH']}",
        "PACMAN_EXPLICIT": "declared-pkg\nunmanaged-pkg\n",
        "PACMAN_INSTALLED": "unmanaged-pkg\n",
        "PACMAN_ORPHANS": "orphan-pkg\n",
    }
    proc = subprocess.run(
        ["zsh", str(SCRIPT), "--json"],
        cwd=project,
        capture_output=True,
        text=True,
        env=env,
        check=False,
    )

    assert proc.returncode == 1
    payload = json.loads(proc.stdout)
    assert payload["unmanaged"] == ["unmanaged-pkg"]
    assert payload["missing"] == ["declared-pkg"]
    assert payload["orphans"] == ["orphan-pkg"]


def test_pkg_drift_json_reports_no_drift(tmp_path):
    project = tmp_path / "repo"
    states = project / "states"
    data = states / "data"
    states.mkdir(parents=True)
    data.mkdir(parents=True)
    (data / "packages.yaml").write_text("base:\n  - declared-pkg\n")
    (data / "fonts.yaml").write_text("{}\n")
    (data / "installers_desktop.yaml").write_text("{}\n")
    (states / "example.sls").write_text("")

    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    _write_fake_pacman(
        bin_dir,
        explicit="declared-pkg\n",
        installed="declared-pkg\n",
        orphans="",
    )

    env = os.environ | {
        "PATH": f"{bin_dir}:{os.environ['PATH']}",
        "PACMAN_EXPLICIT": "declared-pkg\n",
        "PACMAN_INSTALLED": "declared-pkg\n",
        "PACMAN_ORPHANS": "",
    }
    proc = subprocess.run(
        ["zsh", str(SCRIPT), "--json"],
        cwd=project,
        capture_output=True,
        text=True,
        env=env,
        check=False,
    )

    assert proc.returncode == 0
    payload = json.loads(proc.stdout)
    assert payload["unmanaged"] == []
    assert payload["missing"] == []
    assert payload["orphans"] == []
    assert payload["drift"] is False
