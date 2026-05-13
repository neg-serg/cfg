"""Tests for states/_modules/common.py"""

import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parent.parent
_MODULES_DIR = _REPO_ROOT / "states" / "_modules"
sys.path.insert(0, str(_MODULES_DIR))

import common as _common  # noqa: E402


def test_get_host_returns_dict():
    host = _common.get_host()
    assert isinstance(host, dict)
    assert "user" in host
    assert "home" in host
    assert "runtime_dir" in host
    assert host["runtime_dir"].startswith("/run/user/")


def test_get_host_has_derived_fields():
    host = _common.get_host()
    assert host["pkg_list"] == "/var/cache/salt/pacman_installed.txt"
    assert "uid" in host


def test_get_constants_returns_expected_keys():
    const = _common.get_constants()
    assert const["retry_attempts"] == 3
    assert const["retry_interval"] == 10
    assert const["healthcheck_timeout"] == 30
    assert const["ollama_pull_timeout"] == 14400
    assert const["ver_dir"].endswith("/.cache/salt-versions")
    assert const["sys_ver_dir"] == "/var/cache/salt/versions"
    assert const["download_cache"] == "/var/cache/salt/downloads"


def test_ver_dir_default():
    vd = _common.ver_dir()
    assert vd.endswith("/.cache/salt-versions")


def test_ver_dir_custom_home():
    vd = _common.ver_dir("/home/testuser")
    assert vd == "/home/testuser/.cache/salt-versions"


def test_sys_ver_dir():
    assert _common.sys_ver_dir() == "/var/cache/salt/versions"


def test_download_cache():
    assert _common.download_cache() == "/var/cache/salt/downloads"


def test_get_registry_returns_dict():
    reg = _common.get_registry()
    assert isinstance(reg, dict)
    assert "features" in reg
