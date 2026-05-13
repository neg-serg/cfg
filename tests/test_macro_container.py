"""__macros_container.jinja cleared — all logic in _modules/."""  

from tests import REPO_ROOT_PATH

_CONFIG = REPO_ROOT_PATH / "states" / "_macros_container.jinja"  
_SRC = _CONFIG.read_text()

def test_macro_cleared():
    """File kept for backward compat, no business logic"""
    assert "# All business logic migrated" in _SRC or "# Business logic migrated" in _SRC
