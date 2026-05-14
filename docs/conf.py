import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / '_ext'))

project = 'Salt Configuration'
author = 'neg'
release = '1.0'
extensions = [
    'sphinx.ext.autodoc',
    'sphinx.ext.intersphinx',
    'myst_parser',
    'salt_domain',
]
source_suffix = {'.rst': 'restructuredtext', '.md': 'markdown'}
master_doc = 'index'
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store']
html_theme = 'sphinx_book_theme'
html_title = 'Salt Configuration Docs'
html_static_path = ['_static']
intersphinx_mapping = {
    'python': ('https://docs.python.org/3', None),
}
nitpicky = True


def run_extractor(app):
    import subprocess
    extractor = Path(__file__).resolve().parent.parent / 'scripts' / 'extract-inline-docs.py'
    if extractor.exists():
        subprocess.run([sys.executable, str(extractor), '--all'], cwd=extractor.parent.parent, check=False)


def setup(app):
    app.connect('builder-inited', run_extractor)
