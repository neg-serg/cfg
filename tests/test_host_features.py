"""Tests for states/_modules/host_features.py"""

import sys
from pathlib import Path

_MODULES_DIR = Path(__file__).resolve().parent.parent / "states" / "_modules"
sys.path.insert(0, str(_MODULES_DIR))

import host_features as hf  # noqa: E402


def test_feature_default_mpd():
    assert hf.feature_default("mpd") is True


def test_feature_default_nonexistent():
    assert hf.feature_default("nonexistent.feature.xyz") is None


def test_feature_default_nested():
    result = hf.feature_default("monitoring.loki")
    assert result is False  # registry default


def test_feature_enabled_no_host():
    result = hf.feature_enabled("mpd")
    assert isinstance(result, bool)


def test_feature_enabled_with_host():
    host = {"features": {"mpd": True, "steam": False}}
    assert hf.feature_enabled("mpd", host) is True
    assert hf.feature_enabled("steam", host) is False


def test_feature_enabled_nested():
    host = {"features": {"monitoring": {"loki": True, "prometheus": False}}}
    assert hf.feature_enabled("monitoring.loki", host) is True
    assert hf.feature_enabled("monitoring.prometheus", host) is False
    assert hf.feature_enabled("monitoring.nonexistent", host) is False
