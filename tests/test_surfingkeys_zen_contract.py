from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text()


def test_zen_extension_manifest_keeps_surfingkeys():
    text = read("states/data/zen_browser.yaml")
    assert "slug: surfingkeys_ff" in text



def test_surfingkeys_config_keeps_zen_helper_actions():
    text = read("dotfiles/dot_config/surfingkeys.js")
    assert "Zen Browser: focus address bar via local helper" in text
    assert "http://localhost:18888/focus" in text
    assert "http://localhost:18888/blank.html" in text
    assert "url: url" in text
    assert "{ tab: { tabbed: true, active: true }, url });" not in text


