"""Contract tests for _macros_container.jinja — delegates to _modules/container.py."""

from tests import REPO_ROOT_PATH

_CONTAINER_MACRO = REPO_ROOT_PATH / "states" / "_macros_container.jinja"
_SOURCE = _CONTAINER_MACRO.read_text()


def test_container_service_delegates_to_python():
    assert "macro container_service" in _SOURCE
    assert "salt[" in _SOURCE
    assert "container.deploy" in _SOURCE


def test_tilde_expand_helper_present():
    assert "macro _tilde_expand" in _SOURCE


def test_imports_preserved():
    assert "from '_macros_common.jinja'" in _SOURCE
    assert "import_yaml" in _SOURCE
    assert "service_catalog" in _SOURCE or "catalog" in _SOURCE
    assert "container_images" in _SOURCE
