"""All cleared macros checked for no business logic."""

from tests import REPO_ROOT_PATH

ACTIVE = {"_macros_common.jinja", "_macros_service.jinja", "_macros_pkg.jinja", "_macros_ipv6_tunnel.jinja"}

def test_cleared_macros():
    for f in sorted(REPO_ROOT_PATH.glob("states/_macros_*.jinja")):
        if f.name in ACTIVE:
            continue
        src = f.read_text()
        assert "# All business logic migrated" in src or "# Business logic migrated" in src, f"{f.name}: unexpected content"
