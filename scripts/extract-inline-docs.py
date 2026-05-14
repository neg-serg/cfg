#!/usr/bin/env python3
# ruff: noqa: E501
"""Extract structured inline documentation from source files and generate Sphinx RST pages.

Scanner architecture:
  - Regex-based line-wise parser extracts {# @state ... #}, {# @macro ... #},
    # @script ... blocks from SLS, Jinja2, Python, and shell files
  - Schema validator (validate_block) checks against contract schemas
    from contracts/comment-block-schemas.yaml using the data-model
  - RST generators (gen_state_rst, gen_macro_rst, etc.) produce Sphinx-compatible
    pages under docs/{states,macros,scripts,data-files}/

Integration:
  - Invoked as Sphinx pre-build hook from docs/conf.py via builder-inited event
  - Also callable standalone: extract-inline-docs.py --all (full rebuild)
  - Validation mode: --validate (exit 1 on schema errors)
  - Used by just lint via lint-all.sh for inline doc comment validation
  - Produces docs/entity-manifest.json + docs/entity-manifest.yaml for LLM agent
    consumption and cross-referencing

Output:
  - RST pages: docs/states/{id}.rst, docs/macros/{name}.rst, etc.
  - Entity index: docs/index.md (regenerated from entity-manifest.json)
  - Machine manifests: docs/entity-manifest.json, docs/entity-manifest.yaml

Usage:
    extract-inline-docs.py --all           # Process all file types
    extract-inline-docs.py --sls           # Salt SLS files only
    extract-inline-docs.py --jinja         # Jinja2 macro files only
    extract-inline-docs.py --python        # Python scripts (autodoc config)
    extract-inline-docs.py --shell         # Shell scripts only
    extract-inline-docs.py --validate      # Validate only (for just lint)
"""

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DOCS_DIR = PROJECT_ROOT / 'docs'
STATES_SRC = PROJECT_ROOT / 'states'
SCRIPTS_SRC = PROJECT_ROOT / 'scripts'
IGNORE_FILES = {'__init__.py', '__main__.py'}
IGNORE_DIRS = {'__pycache__', '__init__'}

# ── Block patterns ──────────────────────────────────────────────────────────

RE_STATE_BLOCK = re.compile(
    r'\{#-\s*@state\s*\n(.*?)#\}',
    re.DOTALL,
)
RE_MACRO_BLOCK = re.compile(
    r'\{#\s@macro\s*\n(.*?)#\}',
    re.DOTALL,
)
RE_MACRO_FILE_BLOCK = re.compile(
    r'\{#\s@macro_file\s*\n(.*?)#\}',
    re.DOTALL,
)
RE_SCRIPT_SH_BLOCK = re.compile(
    r'#[ ]@script\n(#[ ].*\n?)*',
    re.MULTILINE,
)
RE_MACRO_DEF = re.compile(r'\{%\s*macro\s+(\w+)')
RE_MACRO_PARAM = re.compile(
    r'\{#\s@macro_param\s*\n(.*?)#\}',
    re.DOTALL,
)

# ── Key-value parser ────────────────────────────────────────────────────────

RE_KV = re.compile(r'(\w[\w_-]*)\s*:\s*(.*)')
RE_LIST = re.compile(r'\[([^\]]*)\]')
RE_NESTED_OBJ = re.compile(r'\{([^}]*)\}')


def _parse_value(raw: str):
    raw = raw.strip()
    if not raw:
        return None
    if raw.startswith('['):
        m = RE_LIST.match(raw)
        if m:
            items = m.group(1)
            return [x.strip().strip("'\"") for x in items.split(',') if x.strip()]
    if raw.startswith('{'):
        m = RE_NESTED_OBJ.match(raw)
        if m:
            inner = m.group(1)
            obj = {}
            for pair in inner.split(','):
                if ':' in pair:
                    k, v = pair.split(':', 1)
                    obj[k.strip().strip("'\"")] = v.strip().strip("'\"")
            return obj
    return raw.strip("'\"")


def parse_kv_block(text: str):
    """Parse key: value lines into a dict. Handles multi-line values indented under a key."""
    result = {}
    current_key = None
    current_val = []
    for line in text.split('\n'):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        match = RE_KV.match(line)
        if match:
            if current_key:
                result[current_key] = _parse_value(' '.join(current_val))
            current_key = match.group(1)
            val = match.group(2).strip()
            current_val = [val]
        elif current_key:
            current_val.append(line)
    if current_key:
        result[current_key] = _parse_value(' '.join(current_val))
    return result


# ── Schema validation ───────────────────────────────────────────────────────

SCHEMAS = {
    'state': {
        'required': ['id', 'purpose'],
        'optional': ['includes', 'data_files', 'configs', 'services',
                      'secrets', 'feature_gate', 'tests'],
        'list_fields': ['includes', 'data_files', 'configs', 'services',
                        'secrets', 'feature_gate', 'tests'],
    },
    'macro': {
        'required': ['name', 'purpose'],
        'optional': ['params', 'returns'],
        'list_fields': [],
    },
    'script_sh': {
        'required': ['purpose'],
        'optional': ['dependencies', 'outputs'],
        'list_fields': ['dependencies', 'outputs'],
    },
}


def validate_block(entity_type: str, data: dict) -> list:
    """Validate a parsed comment block against schema. Returns list of issues."""
    issues = []
    schema = SCHEMAS.get(entity_type)
    if not schema:
        return [f"unknown entity type: {entity_type}"]
    for field in schema['required']:
        if field not in data or data[field] is None:
            issues.append(f"MISSING_REQUIRED: {field} is required in @{entity_type} block")
    for field in schema['list_fields']:
        if field in data and data[field] is not None and not isinstance(data[field], list):
            issues.append(f"INVALID_VALUE: {field} expects list value, got {type(data[field]).__name__}")
    allowed = set(schema['required'] + schema['optional'])
    for field in data:
        if field not in allowed:
            issues.append(f"UNKNOWN_FIELD: {field} in @{entity_type} block")
    return issues


# ── File scanners ───────────────────────────────────────────────────────────

def scan_sls_files():
    """Scan all state/*.sls files for @state blocks. Also scan subdirectories."""
    entities = []
    seen_ids = defaultdict(list)
    for sls_path in sorted(STATES_SRC.rglob('*.sls')):
        rel_path = sls_path.relative_to(PROJECT_ROOT)
        text = sls_path.read_text(encoding='utf-8')
        m = RE_STATE_BLOCK.search(text)
        if m:
            data = parse_kv_block(m.group(1))
            issues = validate_block('state', data)
            entity_id = data.get('id', '')
            entity = {
                'id': entity_id,
                'type': 'state',
                'source_path': str(rel_path),
                'purpose': data.get('purpose', ''),
                'includes': data.get('includes', []),
                'data_files': data.get('data_files', []),
                'configs': data.get('configs', []),
                'services': data.get('services', []),
                'secrets': data.get('secrets', []),
                'feature_gate': data.get('feature_gate', []),
                'tests': data.get('tests', []),
                'issues': issues,
            }
            entities.append(entity)
            if entity_id:
                seen_ids[entity_id].append(str(rel_path))
        else:
            entities.append({
                'id': sls_path.stem,
                'type': 'state',
                'source_path': str(rel_path),
                'purpose': '',
                'issues': ['BLOCK_MISSING: no @state block found'],
            })
    return entities, seen_ids


def scan_jinja_macro_files():
    """Scan all _macros_*.jinja files for @macro blocks."""
    entities = []
    seen_names = defaultdict(list)
    for jinja_path in sorted(STATES_SRC.glob('_macros_*.jinja')):
        rel_path = jinja_path.relative_to(PROJECT_ROOT)
        text = jinja_path.read_text(encoding='utf-8')
        macro_blocks = list(RE_MACRO_BLOCK.finditer(text))
        macro_defs = list(RE_MACRO_DEF.finditer(text))

        if macro_blocks:
            for mb in macro_blocks:
                data = parse_kv_block(mb.group(1))
                issues = validate_block('macro', data)
                macro_name = data.get('name', '')
                entity = {
                    'id': macro_name,
                    'type': 'macro',
                    'source_path': str(rel_path),
                    'purpose': data.get('purpose', ''),
                    'params': data.get('params', []),
                    'returns': data.get('returns', ''),
                    'issues': issues,
                }
                entities.append(entity)
                if macro_name:
                    seen_names[macro_name].append(str(rel_path))
        else:
            for md in macro_defs:
                macro_name = md.group(1)
                entities.append({
                    'id': macro_name,
                    'type': 'macro',
                    'source_path': str(rel_path),
                    'purpose': '',
                    'issues': ['BLOCK_MISSING: no @macro block for this macro'],
                })
            if not macro_defs:
                entities.append({
                    'id': jinja_path.stem,
                    'type': 'macro',
                    'source_path': str(rel_path),
                    'purpose': '',
                    'issues': ['BLOCK_MISSING: no @macro blocks found'],
                })

    return entities, seen_names


def scan_python_scripts():
    """Scan scripts/*.py for module-level docstrings (autodoc reference)."""
    entities = []
    for py_path in sorted(SCRIPTS_SRC.rglob('*.py')):
        if py_path.name in IGNORE_FILES:
            continue
        rel_path = py_path.relative_to(PROJECT_ROOT)
        text = py_path.read_text(encoding='utf-8')
        module_doc = ''
        lines = text.split('\n')
        if lines and lines[0].startswith('#!'):
            lines = lines[1:]
        stripped = '\n'.join(lines).lstrip()
        if stripped.startswith('"""'):
            end = stripped.find('"""', 3)
            if end != -1:
                module_doc = stripped[3:end].strip()
        name = py_path.stem
        entities.append({
            'id': name,
            'type': 'script_py',
            'source_path': str(rel_path),
            'purpose': module_doc.split('\n')[0] if module_doc else '',
            'docstring': module_doc,
            'issues': [] if module_doc else ['BLOCK_MISSING: no module-level docstring'],
        })
    return entities


def scan_shell_scripts():
    """Scan scripts/*.sh and scripts/*.zsh for @script blocks."""
    entities = []
    for ext in ('*.sh', '*.zsh'):
        for sh_path in sorted(SCRIPTS_SRC.glob(ext)):
            rel_path = sh_path.relative_to(PROJECT_ROOT)
            text = sh_path.read_text(encoding='utf-8')
            m = RE_SCRIPT_SH_BLOCK.search(text)
            if m:
                lines = m.group(0).split('\n')
                kv_lines = []
                for line in lines:
                    line = line.strip()
                    if line.startswith('# @script'):
                        continue
                    if line.startswith('# '):
                        kv_lines.append(line[2:])
                data = parse_kv_block('\n'.join(kv_lines))
                issues = validate_block('script_sh', data)
                entities.append({
                    'id': sh_path.stem,
                    'type': 'script_sh',
                    'source_path': str(rel_path),
                    'purpose': data.get('purpose', ''),
                    'dependencies': data.get('dependencies', []),
                    'outputs': data.get('outputs', []),
                    'issues': issues,
                })
            else:
                entities.append({
                    'id': sh_path.stem,
                    'type': 'script_sh',
                    'source_path': str(rel_path),
                    'purpose': '',
                    'issues': ['BLOCK_MISSING: no @script block found'],
                })
    return entities


def scan_data_files():
    """Scan data files from module-index.yaml consumer data."""
    index_path = PROJECT_ROOT / 'docs' / 'module-index.yaml'
    entities = []
    if not index_path.exists():
        return entities
    import yaml
    with open(index_path) as f:
        index = yaml.safe_load(f)
    for df in index.get('data_files', []):
        path = df.get('path', '')
        consumers = df.get('consumers', [])
        if not consumers:
            consumers = []
        name = path.replace('states/', '').replace('.yaml', '')
        consumers_clean = [c.replace('.sls', '').replace('.jinja', '') for c in (consumers if isinstance(consumers, list) else [])]
        entities.append({
            'id': name,
            'type': 'data_file',
            'source_path': path,
            'purpose': f"Data file consumed by {', '.join(consumers_clean)}" if consumers else '',
            'consumers': consumers_clean,
            'issues': [],
        })
    return entities


# ── RST generators ──────────────────────────────────────────────────────────

def rst_escape(text: str) -> str:
    return text.replace('*', '\\*').replace('`', '\\`')


def gen_state_rst(entity: dict) -> str:
    id_ = entity['id']
    purpose = entity.get('purpose', '')
    lines = [
        f'.. salt:state:: {id_}',
        '',
        f'   {purpose}' if purpose else '',
        '',
        '.. list-table:: Metadata',
        '   :header-rows: 1',
        '   :widths: 20 80',
        '',
        '   * - Source',
        f'     - ``{entity["source_path"]}``',
    ]
    if entity.get('purpose'):
        lines.extend(['', '   * - Purpose', f'     - {purpose}'])
    for field, label in [('includes', 'Includes'), ('data_files', 'Data Files'),
                          ('configs', 'Configs'), ('services', 'Services'),
                          ('secrets', 'Secrets'), ('feature_gate', 'Feature Gate'),
                          ('tests', 'Tests')]:
        vals = entity.get(field, [])
        if vals:
            refs = []
            for v in vals:
                v = v.replace('.sls', '').replace('.yaml', '')
                if field == 'data_files':
                    refs.append(f':salt:data:`{v}`')
                elif field == 'includes':
                    refs.append(f':salt:state:`{v}`')
                elif field == 'tests':
                    refs.append(f'``{v.replace("tests/", "")}``')
                else:
                    refs.append(f'``{v}``')
            lines.extend(['', f'   * - {label}', f'     - {", ".join(refs)}'])
    if entity.get('issues'):
        lines.extend(['', '.. warning::', ''])
        for issue in entity['issues']:
            lines.append(f'   {issue}')
    return '\n'.join(lines) + '\n'


def gen_macro_rst(entity: dict) -> str:
    name = entity['id']
    purpose = entity.get('purpose', '')
    lines = [
        f'.. salt:macro:: {name}',
        '',
        f'   {purpose}' if purpose else '',
        '',
        '.. list-table:: Metadata',
        '   :header-rows: 1',
        '   :widths: 20 80',
        '',
        '   * - Source',
        f'     - ``{entity["source_path"]}``',
    ]
    if entity.get('purpose'):
        lines.extend(['', '   * - Purpose', f'     - {purpose}'])
    if entity.get('returns'):
        lines.extend(['', '   * - Returns', f'     - {entity["returns"]}'])
    params = entity.get('params', [])
    if params:
        if isinstance(params, list):
            lines.extend(['', '.. list-table:: Parameters', '   :header-rows: 1', '   :widths: 20 20 60', '',
                          '   * - Name', '     - Type', '     - Description'])
            for p in params:
                if isinstance(p, dict):
                    lines.append(f'   * - ``{p.get("name", "")}``')
                    lines.append(f'     - ``{p.get("type", "")}``')
                    lines.append(f'     - {p.get("description", "")}')
                else:
                    lines.append(f'   * - ``{p}``')
                    lines.append('     -')
                    lines.append('     -')
    if entity.get('issues'):
        lines.extend(['', '.. warning::', ''])
        for issue in entity['issues']:
            lines.append(f'   {issue}')
    return '\n'.join(lines) + '\n'


def gen_script_py_rst(entity: dict) -> str:
    name = entity['id']
    purpose = entity.get('purpose', '')
    lines = [
        f'.. salt:script-py:: {name}',
        '',
        f'   {rst_escape(purpose)}' if purpose else '',
        '',
        '.. list-table:: Metadata',
        '   :header-rows: 1',
        '   :widths: 20 80',
        '',
        '   * - Source',
        f'     - ``{entity["source_path"]}``',
    ]
    if purpose:
        lines.extend(['', '   * - Purpose', f'     - {purpose}'])
    if entity.get('docstring'):
        lines.extend(['', '.. rubric:: Module Documentation', '', entity['docstring']])
    if entity.get('issues') and any('BLOCK_MISSING' in i for i in entity['issues']):
        lines.extend(['', '.. note::', '   No module-level docstring found. Add a module docstring for documentation.'])
    return '\n'.join(lines) + '\n'


def gen_script_sh_rst(entity: dict) -> str:
    name = entity['id']
    purpose = entity.get('purpose', '')
    lines = [
        f'.. salt:script-sh:: {name}',
        '',
        f'   {purpose}' if purpose else '',
        '',
        '.. list-table:: Metadata',
        '   :header-rows: 1',
        '   :widths: 20 80',
        '',
        '   * - Source',
        f'     - ``{entity["source_path"]}``',
    ]
    if purpose:
        lines.extend(['', '   * - Purpose', f'     - {purpose}'])
    if entity.get('issues'):
        lines.extend(['', '.. warning::', ''])
        for issue in entity['issues']:
            lines.append(f'   {issue}')
    return '\n'.join(lines) + '\n'


def gen_data_file_rst(entity: dict) -> str:
    id_ = entity['id']
    purpose = entity.get('purpose', '')
    consumers = entity.get('consumers', [])
    lines = [
        f'.. salt:data-file:: {id_}',
        '',
        f'   {purpose}' if purpose else '',
        '',
        '.. list-table:: Metadata',
        '   :header-rows: 1',
        '   :widths: 20 80',
        '',
        '   * - Source',
        f'     - ``{entity["source_path"]}``',
    ]
    if purpose:
        lines.extend(['', '   * - Purpose', f'     - {purpose}'])
    if consumers:
        refs_list = []
        for c in consumers:
            if c.endswith('.jinja'):
                refs_list.append(f':salt:macro:`{c.replace(".jinja", "")}`')
            elif c.endswith('.sls') or Path(PROJECT_ROOT / 'states' / c).exists() or Path(PROJECT_ROOT / 'states' / f'{c}.sls').exists():
                refs_list.append(f':salt:state:`{c.replace(".sls", "")}`')
            else:
                refs_list.append(f'``{c}``')
        refs = ', '.join(refs_list)
        lines.extend(['', '   * - Consumed By', f'     - {refs}'])
    if entity.get('issues'):
        lines.extend(['', '.. warning::', ''])
        for issue in entity['issues']:
            lines.append(f'   {issue}')
    return '\n'.join(lines) + '\n'


# ── Index generator ─────────────────────────────────────────────────────────

def gen_index(entities: list, manifest_path: Path):
    """Generate docs/index.md with grouped entity tables from the manifest."""
    grouped = defaultdict(list)
    for e in entities:
        grouped[e['type']].append(e)

    type_labels = {
        'state': 'Salt States',
        'macro': 'Jinja2 Macros',
        'script_py': 'Python Scripts',
        'script_sh': 'Shell Scripts',
        'data_file': 'Data Files',
    }

    lines = [
        '# Salt Configuration Documentation',
        '',
        'Generated documentation for all project entities — states, macros, scripts, and data files.',
        '',
        '.. toctree::',
        '   :maxdepth: 1',
        '   :glob:',
        '',
        '   *',
        '   states/*',
        '   macros/*',
        '   scripts/*',
        '   data-files/*',
        '',
    ]

    for type_key in ['state', 'macro', 'script_py', 'script_sh', 'data_file']:
        ents = grouped.get(type_key, [])
        if not ents:
            continue
        label = type_labels.get(type_key, type_key)
        lines.extend([f'{label}', '=' * len(label), '', '.. list-table::', '   :header-rows: 1', '   :widths: 25 15 60', '',
                      '   * - ID', '     - Source', '     - Purpose'])
        for e in sorted(ents, key=lambda x: x.get('id', '')):
            source = e.get('source_path', '')
            purpose = e.get('purpose', '') or '(no documentation)'
            eid = e.get('id', '')
            if type_key == 'state':
                ref = f':salt:state:`{eid}`'
            elif type_key == 'macro':
                ref = f':salt:macro:`{eid}`'
            elif type_key == 'data_file':
                ref = f':salt:data:`{eid}`'
            else:
                ref = f'``{eid}``'
            lines.extend(['', f'   * - {ref}', f'     - ``{source}``', f'     - {purpose}'])

    index_path = DOCS_DIR / 'index.md'
    index_path.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(f"  Generated {index_path}")


# ── Output writer ───────────────────────────────────────────────────────────

def write_rst(file_path: Path, content: str):
    file_path.parent.mkdir(parents=True, exist_ok=True)
    file_path.write_text(content, encoding='utf-8')
    print(f"  Wrote {file_path}")


# ── Update conf.py for autodoc ──────────────────────────────────────────────

def update_conf_py_for_autodoc(scripts: list):
    """Generate autodoc stubs for Python scripts and inject into conf.py."""
    autodoc_dir = DOCS_DIR / 'scripts'
    autodoc_dir.mkdir(parents=True, exist_ok=True)
    for script in scripts:
        name = script['id']
        src_path = script['source_path']
        module_path = str(src_path).replace('/', '.').replace('.py', '').replace('-', '_')
        rst = [
            f'.. salt:script-py:: {name}',
            '',
            f'   {script.get("purpose", "")}',
            '',
            '',
            '.. automodule:: ' + module_path,
            '   :members:',
            '   :undoc-members:',
            '   :show-inheritance:',
            '',
        ]
        rst_path = autodoc_dir / f'{name}.rst'
        rst_path.write_text('\n'.join(rst) + '\n', encoding='utf-8')
        print(f"  Wrote {rst_path}")


# ── Manifest writer ─────────────────────────────────────────────────────────

def write_manifest(entities: list, issues: list, manifest_json: Path, manifest_yaml: Path):
    manifest_json.parent.mkdir(parents=True, exist_ok=True)
    manifest = {
        'generated': __import__('datetime').datetime.now().isoformat(),
        'entity_count': len(entities),
        'issue_count': len(issues),
        'entities': entities,
    }
    manifest_json.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding='utf-8')
    print(f"  Wrote {manifest_json}")

    import yaml
    yml = {e.get('id', ''): {
        'type': e['type'],
        'source': e.get('source_path', ''),
        'purpose': e.get('purpose', ''),
    } for e in entities}
    manifest_yaml.write_text(yaml.dump({'entities': yml}, default_flow_style=False), encoding='utf-8')
    print(f"  Wrote {manifest_yaml}")


# ── Main ────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(description='Extract inline docs and generate Sphinx RST pages.')
    ap.add_argument('--all', action='store_true', help='Process all file types')
    ap.add_argument('--sls', action='store_true', help='Process Salt SLS files')
    ap.add_argument('--jinja', action='store_true', help='Process Jinja2 macro files')
    ap.add_argument('--python', action='store_true', help='Process Python scripts')
    ap.add_argument('--shell', action='store_true', help='Process shell scripts')
    ap.add_argument('--manifest-only', action='store_true', help='Only generate the manifest, skip RST generation')
    ap.add_argument('--validate', action='store_true', help='Validate comment blocks without generating RST (exit 1 on errors)')
    args = ap.parse_args()

    if not any([args.all, args.sls, args.jinja, args.python, args.shell, args.validate]):
        args.all = True
    if args.validate:
        args.all = True

    all_entities = []
    all_issues = []
    seen_ids = {}

    if args.all or args.sls:
        print("Scanning SLS files...")
        states, state_ids = scan_sls_files()
        all_entities.extend(states)
        seen_ids.update(state_ids)

    if args.all or args.jinja:
        print("Scanning Jinja2 macro files...")
        macros, macro_ids = scan_jinja_macro_files()
        all_entities.extend(macros)
        seen_ids.update(macro_ids)

    if args.all or args.python:
        print("Scanning Python scripts...")
        scripts = scan_python_scripts()
        all_entities.extend(scripts)

    if args.all or args.shell:
        print("Scanning shell scripts...")
        shells = scan_shell_scripts()
        all_entities.extend(shells)

    if args.all:
        print("Scanning data files...")
        data_files = scan_data_files()
        all_entities.extend(data_files)

    for entity in all_entities:
        for issue in entity.get('issues', []):
            all_issues.append(f"{entity['source_path']}: {issue}")

    for eid, sources in seen_ids.items():
        if len(sources) > 1:
            issue = f"DUPLICATE_ID: {eid} in {', '.join(sources)}"
            all_issues.append(issue)

    if all_issues:
        print(f"\nIssues ({len(all_issues)}):")
        for issue in all_issues:
            print(f"  WARN: {issue}" if 'BLOCK_MISSING' in issue or 'DANGLING' in issue else f"  ERROR: {issue}")

    if args.validate:
        has_errors = any(not ('BLOCK_MISSING' in i or 'DANGLING' in i) for i in all_issues)
        if all_issues:
            for issue in all_issues:
                print(issue)
            if has_errors:
                print(f"\nFAIL: {len(all_issues)} issues found ({sum(1 for i in all_issues if not ('BLOCK_MISSING' in i or 'DANGLING' in i))} errors)")
                sys.exit(1)
            else:
                print(f"\nPASS: {len(all_issues)} warnings only (BLOCK_MISSING and DANGLING_REFERENCE are non-fatal)")
        else:
            print("PASS: all comment blocks valid")
        return

    if args.manifest_only:
        manifest_json = DOCS_DIR / 'entity-manifest.json'
        manifest_yaml = DOCS_DIR / 'entity-manifest.yaml'
        write_manifest(all_entities, all_issues, manifest_json, manifest_yaml)
        return

    states_dir = DOCS_DIR / 'states'
    macros_dir = DOCS_DIR / 'macros'
    scripts_dir = DOCS_DIR / 'scripts'
    data_files_dir = DOCS_DIR / 'data-files'

    for e in all_entities:
        if e['type'] == 'state':
            write_rst(states_dir / f"{e['id'].replace('.', '-')}.rst", gen_state_rst(e))
        elif e['type'] == 'macro':
            write_rst(macros_dir / f"{e['id'].replace('.', '-')}.rst", gen_macro_rst(e))
        elif e['type'] == 'script_py':
            pass
        elif e['type'] == 'script_sh':
            write_rst(scripts_dir / f"{e['id']}.rst", gen_script_sh_rst(e))

    scripts = [e for e in all_entities if e['type'] == 'script_py']
    if scripts:
        update_conf_py_for_autodoc(scripts)

    data_files_ents = [e for e in all_entities if e['type'] == 'data_file']
    for e in data_files_ents:
        write_rst(data_files_dir / f"{e['id'].replace('/', '-')}.rst", gen_data_file_rst(e))

    manifest_json = DOCS_DIR / 'entity-manifest.json'
    manifest_yaml = DOCS_DIR / 'entity-manifest.yaml'
    write_manifest(all_entities, all_issues, manifest_json, manifest_yaml)

    gen_index(all_entities, manifest_json)

    print(f"\nDone. Generated {len(all_entities)} entity pages.")
    if all_issues:
        print(f"Total issues: {len(all_issues)}")


if __name__ == '__main__':
    main()
