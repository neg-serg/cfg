"""Contract tests for _macros_container.jinja — the container_service macro."""

from tests import REPO_ROOT_PATH

_CONTAINER_MACRO = REPO_ROOT_PATH / "states" / "_macros_container.jinja"
_SOURCE = _CONTAINER_MACRO.read_text()


def test_container_service_macro_exists():
    assert "{%- macro container_service(" in _SOURCE


def test_precondition_fail_macros_present():
    assert "{%- macro _cs_fail(" in _SOURCE
    assert "test.fail_without_changes" in _SOURCE


def test_tilde_expand_helper_present():
    assert "{%- macro _tilde_expand(" in _SOURCE


def test_quadlet_paths_differ_by_scope():
    assert "/etc/containers/systemd/" in _SOURCE
    assert ".config/containers/systemd/" in _SOURCE


def test_image_pull_skipped_for_localhost():
    assert "localhost" in _SOURCE
    assert "if not _is_localhost" in _SOURCE


def test_manual_start_skips_enable_and_healthcheck():
    assert "if not _manual_start" in _SOURCE


def test_user_scope_uses_env_block():
    assert "_env_block()" in _SOURCE


def test_imports_from_macros_service():
    assert "from '_macros_service.jinja'" in _SOURCE


def test_imports_from_macros_common():
    assert "from '_macros_common.jinja'" in _SOURCE
