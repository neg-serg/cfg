#!/usr/bin/env python3
# ruff: noqa: E501
"""Inject structured documentation blocks into SLS and Jinja2 macro files.

Reads docs/module-index.yaml for entity metadata and injects:
  - {#- @state ... #} blocks into all SLS files
  - {# @macro_file provides: [...] #} blocks into _macros_*.jinja files
  - {# @macro name=... purpose=... #} blocks for each macro definition

Usage: python3 scripts/inject-doc-blocks.py [--no-sls] [--no-macros] [--dry-run]
"""

import argparse
import re
from pathlib import Path

import yaml

PROJECT_ROOT = Path(__file__).resolve().parent.parent
MODULE_INDEX = PROJECT_ROOT / 'docs' / 'module-index.yaml'
STATES_DIR = PROJECT_ROOT / 'states'

RE_STATE_BLOCK = re.compile(r'\{#-\s*@state\s*\n.*?#\}|$', re.DOTALL)
RE_MACRO_FILE_BLOCK = re.compile(r'\{#\s@macro_file\s*\n.*?#\}|$', re.DOTALL)
RE_MACRO_BLOCK = re.compile(r'\{#\s@macro\s*\n.*?#\}|$', re.DOTALL)
RE_MACRO_DEF = re.compile(r'\{%-?\s*macro\s+(\w+)\s*\(([^)]*)\)')


def make_state_block(state_data: dict) -> str:
    state_id = state_data['id']
    purpose = state_data.get('purpose', '').strip()
    purpose = purpose.strip('─═ ')
    if purpose and not purpose.endswith('.'):
        purpose += '.'
    lines = ['{#- @state']
    lines.append(f'   id: {state_id}')
    lines.append(f'   purpose: "{purpose}"')
    for field, label in [('includes', 'includes'), ('data_files', 'data_files'),
                          ('configs', 'configs'), ('services', 'services'),
                          ('secrets', 'secrets'), ('feature_gate', 'feature_gate'),
                          ('tests', 'tests')]:
        vals = state_data.get(field, [])
        if vals:
            lines.append(f'   {label}: [{", ".join(vals)}]')
    lines.append('#}')
    return '\n'.join(lines) + '\n'


def inject_state_block(path: Path, state_data: dict):
    text = path.read_text(encoding='utf-8')
    block = make_state_block(state_data)
    if text.lstrip().startswith('{#'):
        lines = text.split('\n')
        idx = 0
        in_comment = False
        for i, line in enumerate(lines):
            stripped = line.strip()
            if stripped.startswith('{#') or stripped.startswith('{#-'):
                in_comment = True
            if in_comment and '#}' in stripped:
                in_comment = False
                idx = i + 1
                break
        if idx == 0:
            new_text = block + text
        else:
            new_text = '\n'.join(lines[:idx]) + '\n' + block + '\n'.join(lines[idx:])
    else:
        new_text = block + text
    path.write_text(new_text, encoding='utf-8')
    print(f"  Injected {state_data['id']} into {path.relative_to(PROJECT_ROOT)}")


def make_macro_file_block(provides: list) -> str:
    items = ', '.join(provides)
    return f'{{# @macro_file\n   provides: [{items}]\n#}}\n\n'


def make_macro_block(name: str) -> str:
    return f'{{# @macro\n   name: {name}\n   purpose: ""\n#}}\n'


def inject_macro_blocks(path: Path, provides: list):
    text = path.read_text(encoding='utf-8')
    has_file_block = '{# @macro_file' in text
    if not has_file_block:
        file_block = make_macro_file_block(provides)
        text = file_block + text
        print(f"  Added @macro_file block to {path.relative_to(PROJECT_ROOT)}")

    macro_defs = list(RE_MACRO_DEF.finditer(text))
    existing_macros = set()
    for m in RE_MACRO_BLOCK.finditer(text):
        if 'name:' in m.group():
            for line in m.group().split('\n'):
                if 'name:' in line:
                    name = line.split('name:')[1].strip().strip('"\'')
                    existing_macros.add(name)

    for md in macro_defs:
        name = md.group(1)
        if name in existing_macros:
            print(f"  Skipped {name} (already has @macro block)")
            continue
        macro_block = make_macro_block(name)
        pos = md.start()
        text = text[:pos] + macro_block + text[pos:]
        print(f"  Added @macro block for {name} in {path.relative_to(PROJECT_ROOT)}")

    path.write_text(text, encoding='utf-8')


def main():
    ap = argparse.ArgumentParser(description='Inject documentation blocks into source files.')
    ap.add_argument('--no-sls', action='store_true', help='Skip SLS files')
    ap.add_argument('--no-macros', action='store_true', help='Skip Jinja2 macro files')
    ap.add_argument('--dry-run', action='store_true', help='Print what would be done without modifying files')
    args = ap.parse_args()

    with open(MODULE_INDEX) as f:
        index = yaml.safe_load(f)

    if not args.no_sls:
        print("=== Injecting @state blocks into SLS files ===")
        for state_data in index.get('states', []):
            state_id = state_data['id']
            path_str = state_data.get('path', '')
            sls_path = PROJECT_ROOT / path_str
            if not sls_path.exists():
                print(f"  SKIP: {path_str} not found")
                continue
            current_text = sls_path.read_text(encoding='utf-8')
            if '{#- @state' in current_text[:500]:
                print(f"  SKIP: {path_str} already has @state block")
                continue
            if args.dry_run:
                print(f"  WOULD inject @state for {state_id} into {path_str}")
            else:
                inject_state_block(sls_path, state_data)

    if not args.no_macros:
        print("\n=== Injecting @macro blocks into Jinja2 files ===")
        for macro_data in index.get('macros', []):
            path_str = macro_data.get('path', '')
            jinja_path = PROJECT_ROOT / path_str
            if not jinja_path.exists():
                print(f"  SKIP: {path_str} not found")
                continue
            provides = macro_data.get('provides', [])
            if not provides:
                print(f"  SKIP: {path_str} has no provides list")
                continue
            if args.dry_run:
                print(f"  WOULD inject @macro blocks: {', '.join(provides)} into {path_str}")
            else:
                inject_macro_blocks(jinja_path, provides)

    print("\nDone.")


if __name__ == '__main__':
    main()
