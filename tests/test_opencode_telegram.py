"""Contract tests for the OpenCode Telegram bot state."""

from tests import REPO_ROOT_PATH


_STATE_PATH = REPO_ROOT_PATH / "states" / "opencode_telegram.sls"
_ENV_PATH = REPO_ROOT_PATH / "states" / "configs" / "opencode-telegram-bot.env.j2"
_SOURCE = _STATE_PATH.read_text()
_ENV_SOURCE = _ENV_PATH.read_text()


def test_opencode_telegram_state_exposes_multi_user_allowlist():
    assert "telegram_uid_levra" in _SOURCE
    assert "telegram_uid_levra" in _ENV_SOURCE
    assert "TELEGRAM_ALLOWED_USER_IDS" in _ENV_SOURCE
    assert "{{ telegram_uid }},{{ telegram_uid_levra }}" in _ENV_SOURCE


def test_opencode_telegram_auth_patch_supports_allowlist_membership():
    assert "allowedUserIds" in _SOURCE
    assert "includes(userId)" in _SOURCE


def test_opencode_telegram_config_patch_exports_allowed_user_ids():
    assert "dist/config.js" in _SOURCE
    assert "getOptionalAllowedUserIdsEnvVar" in _SOURCE
    assert "TELEGRAM_ALLOWED_USER_IDS" in _SOURCE
