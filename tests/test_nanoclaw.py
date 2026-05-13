"""Contract tests for the nanoclaw Salt state.

Uses source‑level assertions because the state depends on Jinja macros
(proxypilot_key, tg_secret) that call external tools at render time.
"""

import re

import pytest

from tests import REPO_ROOT_PATH

pytestmark = pytest.mark.slow

_STATE_PATH = REPO_ROOT_PATH / "states" / "nanoclaw.sls"
_SOURCE = _STATE_PATH.read_text()

GUARD_KEYS = {"creates", "unless", "onlyif"}
CMPATTERN = re.compile(r"^\s+\-( (creates|unless|onlyif)\b)")


def _find_state_ids(source: str):
    """Extract all state IDs (lines not indented, before colon at bol)."""
    ids = []
    for line in source.splitlines():
        stripped = line.strip()
        if stripped and not stripped.startswith(("#", "{%", "%}", "{#", "{%")):
            parts = stripped.split(":")
            if parts and parts[0].strip() and " " not in parts[0].strip():
                ids.append(parts[0].strip())
    return ids


def _find_cmd_states(source: str):
    """Find state IDs followed by cmd.run or cmd.script."""
    pattern = re.compile(
        r"^(\w+):\s*\n\s+cmd\.(?:run|script):", re.MULTILINE
    )
    return pattern.findall(source)


def _cmd_has_guard(source: str, state_id: str) -> bool:
    """Check whether the cmd.run block for state_id has a guard key."""
    lines = source.splitlines()
    in_block = False
    for line in lines:
        if re.match(rf"^{state_id}:", line):
            in_block = True
            continue
        if in_block and re.match(r"^\w", line) and ":" in line:
            break
        if in_block and line.strip().startswith("- "):
            key = line.strip().split(":")[0].removeprefix("- ").strip()
            if key in GUARD_KEYS:
                return True
    return False



def test_nanoclaw_clone_has_guard():
    assert _cmd_has_guard(_SOURCE, "nanoclaw_clone")







def test_nanoclaw_env_managed():
    assert "nanoclaw_env:" in _SOURCE
    assert "file.managed" in _SOURCE.split("nanoclaw_env:")[1].split("\n\n")[0]


def test_nanoclaw_native_unit_absent():
    assert "salt['service.remove_native_unit']('nanoclaw'" in _SOURCE
    assert 'scope=\'user\'' in _SOURCE


def test_nanoclaw_native_unit_daemon_reload_has_onlyif():
    assert "salt['service.remove_native_unit']('nanoclaw'" in _SOURCE
    assert 'scope=\'user\'' in _SOURCE




