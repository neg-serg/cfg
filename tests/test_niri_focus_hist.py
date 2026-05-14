"""Contract tests for Niri focus‑history script."""

import re
import subprocess
import sys

from tests import REPO_ROOT_PATH as REPO_ROOT

SCRIPT_PATH = REPO_ROOT / "dotfiles" / "dot_local" / "bin" / "executable_niri-focus-hist"


def test_script_syntax_valid():
    """Script must pass Python syntax check."""
    result = subprocess.run(
        [sys.executable, "-m", "py_compile", str(SCRIPT_PATH)],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, f"Syntax error: {result.stderr}"


def test_address_regex_matches_expected_pattern():
    """Validate the assumed Niri window address format."""
    # Extract ADDR_REGEX from script source
    source = SCRIPT_PATH.read_text()
    # Find line like: ADDR_REGEX = re.compile(r'^0x[0-9a-f]+$', re.IGNORECASE)
    match = re.search(r'ADDR_REGEX\s*=\s*re\.compile\(r(["\'])(.*?)\1', source, re.DOTALL)
    assert match is not None, "ADDR_REGEX definition not found in script"
    pattern = match.group(2)
    # Unescape raw string (simple)
    addr_regex = re.compile(rf"{pattern}", re.IGNORECASE)

    # Should match hex strings prefixed with "0x"
    assert addr_regex.fullmatch("0x1a2b3c")
    assert addr_regex.fullmatch("0xABCDEF")
    assert addr_regex.fullmatch("0x123")
    # Should reject malformed addresses
    assert not addr_regex.fullmatch("")
    assert not addr_regex.fullmatch("0x")
    assert not addr_regex.fullmatch("0xghijkl")  # non‑hex
    assert not addr_regex.fullmatch("1a2b3c")  # missing prefix
    assert not addr_regex.fullmatch("0x1a2b3c ")  # trailing space
    assert not addr_regex.fullmatch(" 0x1a2b3c")


def test_subscribes_to_required_events():
    """Script must subscribe to window‑closed and window‑focused events."""
    source = SCRIPT_PATH.read_text()
    # The subscription line should contain both events
    assert '"window-closed,window-focused"' in source
    # Optional: ensure window‑opened is omitted (by design)
    assert '"window-opened,window-closed,window-focused"' not in source
