#!/usr/bin/env python3
"""Shared discovery helpers for Salt source analysis."""

import re
from dataclasses import dataclass, field
from pathlib import Path

IMPORT_YAML_RE = re.compile(r"\{%-?\s*import_yaml\s+['\"]([^'\"]+)['\"]\s+as\s+\w+")
FEATURE_ATTR_RE = re.compile(r"\bhost\.features\.([a-zA-Z_]\w*(?:\.[a-zA-Z_]\w*)*)")
FEATURE_GET_RE = re.compile(r"\bhost\.features\.get\(\s*['\"]([a-zA-Z_]\w*)['\"]")
FEATURE_NESTED_GET_RE = re.compile(
    r"\bhost\.features\.([a-zA-Z_]\w*(?:\.[a-zA-Z_]\w*)*)\.get\(\s*['\"]([a-zA-Z_]\w*)['\"]"
)
JINJA_IF_RE = re.compile(r"\{%-?\s*(?:if|elif)\s+(.*?)\s*-?%\}")
JINJA_OUTPUT_RE = re.compile(r"\{\{\s*(.*?)\s*\}\}", re.DOTALL)
FEATURE_ALIAS_RE = re.compile(
    r"\{%-?\s*set\s+([a-zA-Z_]\w*)\s*=\s*host\.features\.([a-zA-Z_]\w*(?:\.[a-zA-Z_]\w*)*)\s*-?%\}"
)
ALIAS_ATTR_RE = re.compile(r"\b([a-zA-Z_]\w*)\.([a-zA-Z_]\w*(?:\.[a-zA-Z_]\w*)*)")
ALIAS_GET_RE = re.compile(r"\b([a-zA-Z_]\w*)\.get\(\s*['\"]([a-zA-Z_]\w*)['\"]")
ALIAS_DYNAMIC_GET_RE = re.compile(
    r"\b([a-zA-Z_]\w*)\.get\(\s*(?!['\"])([a-zA-Z_]\w*)\s*(?:,|\))"
)
CALL_LIKE_RE = re.compile(r"^[a-zA-Z_]\w*\s*\(")


@dataclass
class StateFileRecord:
    relpath: str
    state_name: str
    top_level_entrypoint: bool
    workflow_apply_target: bool
    source_text: str
    imported_yaml: list[str] = field(default_factory=list)
    feature_guards: list[str] = field(default_factory=list)


def discover_state_files(states_dir: str = "states") -> list[StateFileRecord]:
    root = Path(states_dir)
    records = []
    for path in sorted(root.glob("**/*.sls")):
        relpath = Path("states") / path.relative_to(root)
        relative = path.relative_to(root)
        top_level_entrypoint = path.parent == root
        workflow_apply_target = top_level_entrypoint or relative.parent.as_posix() == "group"
        records.append(
            StateFileRecord(
                relpath=relpath.as_posix(),
                state_name=relative.as_posix().removesuffix(".sls").replace("/", "."),
                top_level_entrypoint=top_level_entrypoint,
                workflow_apply_target=workflow_apply_target,
                source_text=path.read_text(),
            )
        )
    return records


def _strip_comments(source_text: str) -> str:
    lines = []
    for line in source_text.splitlines():
        hash_index = line.find("#")
        lines.append(line if hash_index == -1 else line[:hash_index])
    return "\n".join(lines)


def enrich_source_metadata(record: StateFileRecord) -> StateFileRecord:
    source_text = _strip_comments(record.source_text)
    imported_yaml = set(IMPORT_YAML_RE.findall(source_text))
    conditional_source = "\n".join(JINJA_IF_RE.findall(source_text))
    macro_arg_source = "\n".join(
        expr for expr in JINJA_OUTPUT_RE.findall(source_text) if CALL_LIKE_RE.match(expr.lstrip())
    )
    alias_get_source = "\n".join([conditional_source, macro_arg_source])
    feature_aliases = dict(FEATURE_ALIAS_RE.findall(source_text))

    feature_guards = {
        guard
        for match in FEATURE_ATTR_RE.finditer(conditional_source)
        for guard in [match.group(1)]
        if not guard.endswith(".get")
        and guard != "get"
        and not conditional_source[match.end() :].lstrip().startswith(".get(")
    }
    feature_guards.update(FEATURE_GET_RE.findall(conditional_source))
    feature_guards.update(
        f"{prefix}.{name}" for prefix, name in FEATURE_NESTED_GET_RE.findall(conditional_source)
    )
    feature_guards.update(
        f"{feature_aliases[alias]}.{name}"
        for alias, name in ALIAS_ATTR_RE.findall(conditional_source)
        if alias in feature_aliases and not name.endswith(".get") and name != "get"
    )
    feature_guards.update(
        f"{feature_aliases[alias]}.{name}"
        for alias, name in ALIAS_GET_RE.findall(alias_get_source)
        if alias in feature_aliases
    )
    feature_guards.update(
        f"{feature_aliases[alias]}.*"
        for alias, _name in ALIAS_DYNAMIC_GET_RE.findall(alias_get_source)
        if alias in feature_aliases
    )

    record.imported_yaml = sorted(imported_yaml)
    record.feature_guards = sorted(feature_guards)
    return record
