#!/usr/bin/env python3
"""Query minimal provenance for Salt states and imported data files."""

import argparse
import importlib.util
import json
import re
import sys
from dataclasses import asdict, dataclass, field
from pathlib import Path

import yaml

SCRIPTS_DIR = Path(__file__).resolve().parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))


_index_spec = importlib.util.spec_from_file_location(
    "index_salt_module", SCRIPTS_DIR / "index-salt.py"
)
if not _index_spec or not _index_spec.loader:
    raise ImportError("Cannot load index-salt.py")
_index_module = importlib.util.module_from_spec(_index_spec)
_index_spec.loader.exec_module(_index_module)

_source_model_spec = importlib.util.spec_from_file_location(
    "salt_source_model_module", SCRIPTS_DIR / "salt_source_model.py"
)
if not _source_model_spec or not _source_model_spec.loader:
    raise ImportError("Cannot load salt_source_model.py")
_source_model_module = importlib.util.module_from_spec(_source_model_spec)
_source_model_spec.loader.exec_module(_source_model_module)


@dataclass
class StateProvenanceRecord:
    state_name: str
    relpath: str
    top_level_entrypoint: bool
    workflow_apply_target: bool
    state_ids: list[str] = field(default_factory=list)
    includes: list[str] = field(default_factory=list)
    requires: list[tuple[str, str]] = field(default_factory=list)
    feature_guards: list[str] = field(default_factory=list)
    imported_yaml: list[str] = field(default_factory=list)


@dataclass
class ReverseIndex:
    states_by_name: dict[str, StateProvenanceRecord]
    states_by_id: dict[str, list[StateProvenanceRecord]]
    data_files: dict[str, dict[str, object]]
    data_key_consumers: dict[str, list[StateProvenanceRecord]] = field(default_factory=dict)
    macro_calls: dict[str, list[StateProvenanceRecord]] = field(default_factory=dict)

    def lookup_state(self, state_name: str) -> StateProvenanceRecord | None:
        return self.states_by_name.get(state_name)

    def lookup_state_id(self, state_id: str) -> list[StateProvenanceRecord]:
        return self.states_by_id.get(state_id, [])

    def lookup_data_file(self, data_file: str) -> dict[str, object] | None:
        normalized = _normalize_data_file_path(data_file)
        payload = self.data_files.get(normalized)
        if payload is None:
            return None
        return {"data_file": normalized, **payload}

    def lookup_data_key(self, data_key: str) -> dict[str, object] | None:
        for data_file, payload in self.data_files.items():
            if data_key in payload.get("keys", []):
                return {
                    "data_file": data_file,
                    **payload,
                    "consumers": list(
                        self.data_key_consumers.get(data_key, payload.get("consumers", []))
                    ),
                }
        return None

    def lookup_macro(self, macro_name: str) -> list[StateProvenanceRecord]:
        return self.macro_calls.get(macro_name, [])


def _normalize_data_file_path(data_file: str) -> str:
    normalized = data_file.replace("\\", "/")
    if normalized.startswith("states/"):
        return normalized
    if normalized.startswith("data/"):
        return f"states/{normalized}"
    return f"states/data/{normalized}"


def _read_data_keys(repo_data_path: Path) -> list[str]:
    try:
        payload = yaml.safe_load(repo_data_path.read_text())
    except Exception:
        return []
    if not isinstance(payload, dict):
        return []

    stem = repo_data_path.stem
    return sorted(f"{stem}.{key}" for key in payload)


IMPORT_YAML_ALIAS_RE = re.compile(r"\{%-?\s*import_yaml\s+['\"]([^'\"]+)['\"]\s+as\s+(\w+)")


def _strip_comments(source_text: str) -> str:
    return _source_model_module._strip_comments(source_text)


def _import_yaml_aliases(source_text: str) -> dict[str, set[str]]:
    aliases: dict[str, set[str]] = {}
    for imported, alias in IMPORT_YAML_ALIAS_RE.findall(_strip_comments(source_text)):
        aliases.setdefault(_normalize_data_file_path(imported), set()).add(alias)
    return aliases


def _source_references_data_key(source_text: str, aliases: set[str], data_key: str) -> bool:
    _, _, key_path = data_key.partition(".")
    if not key_path:
        return False

    clean_source = _strip_comments(source_text)
    for alias in aliases:
        pattern = re.compile(rf"\b{re.escape(alias)}\.{re.escape(key_path)}(?:\b|\.)")
        if pattern.search(clean_source):
            return True
    return False


def _source_references_macro(source_text: str, macro_name: str) -> bool:
    pattern = re.compile(rf"\b{re.escape(macro_name)}\s*\(")
    return pattern.search(_strip_comments(source_text)) is not None


def _defined_macro_names(states_dir: str) -> set[str]:
    macro_files = sorted(str(path) for path in Path(states_dir).glob("_macros_*.jinja"))
    return {name for name, _params, _source_file, _doc in _index_module.parse_macros(macro_files)}


def _state_variants(record: StateProvenanceRecord) -> set[str]:
    rel = record.relpath.removeprefix("states/")
    return {record.relpath, rel, Path(rel).name, record.state_name}


def _serialize_state(record: StateProvenanceRecord) -> dict[str, object]:
    payload = asdict(record)
    payload.pop("requires", None)
    return payload


def _serialize_data_match(match: dict[str, object]) -> dict[str, object]:
    return {
        "data_file": match["data_file"],
        "keys": list(match.get("keys", [])),
        "consumers": [_serialize_state(record) for record in match.get("consumers", [])],
    }


def build_reverse_index(states_dir: str = "states") -> ReverseIndex:
    source_records = [
        _source_model_module.enrich_source_metadata(record)
        for record in _source_model_module.discover_state_files(states_dir)
    ]
    rendered = {
        relpath: (state_ids, includes, requires, feature_guards)
        for relpath, state_ids, includes, requires, feature_guards in _index_module.render_states(
            [record.relpath for record in source_records]
        )
    }

    states_by_name = {}
    states_by_id: dict[str, list[StateProvenanceRecord]] = {}
    states_by_variant = {}
    source_text_by_state = {}
    import_aliases_by_state = {}
    macro_calls: dict[str, list[StateProvenanceRecord]] = {}
    defined_macro_names = _defined_macro_names(states_dir)

    for source_record in source_records:
        state_ids, includes, requires, feature_guards = rendered.get(
            source_record.relpath,
            ([], [], [], source_record.feature_guards),
        )
        record = StateProvenanceRecord(
            state_name=source_record.state_name,
            relpath=source_record.relpath,
            top_level_entrypoint=source_record.top_level_entrypoint,
            workflow_apply_target=source_record.workflow_apply_target,
            state_ids=list(state_ids),
            includes=list(includes),
            requires=list(requires),
            feature_guards=list(feature_guards),
            imported_yaml=list(source_record.imported_yaml),
        )
        states_by_name[record.state_name] = record
        source_text_by_state[record.state_name] = source_record.source_text
        import_aliases_by_state[record.state_name] = _import_yaml_aliases(source_record.source_text)
        for state_id in record.state_ids:
            states_by_id.setdefault(state_id, []).append(record)
        for variant in _state_variants(record):
            states_by_variant[variant] = record

    usage = _index_module.collect_data_usage()
    data_files = {}
    for data_file, consumers in usage.items():
        normalized_data_file = _normalize_data_file_path(data_file)
        repo_data_path = Path(normalized_data_file)
        matched_consumers = []
        for consumer in consumers:
            match = states_by_variant.get(consumer)
            if match is not None:
                matched_consumers.append(match)
        data_files[normalized_data_file] = {
            "consumers": sorted(matched_consumers, key=lambda record: record.state_name),
            "keys": _read_data_keys(repo_data_path),
        }

    # Keep imported_yaml ownership visible even if collect_data_usage misses a file.
    for record in states_by_name.values():
        for imported in record.imported_yaml:
            data_file = _normalize_data_file_path(imported)
            bucket = data_files.setdefault(
                data_file,
                {"consumers": [], "keys": _read_data_keys(Path(data_file))},
            )
            consumers = bucket.setdefault("consumers", [])
            if record not in consumers:
                consumers.append(record)
                consumers.sort(key=lambda item: item.state_name)

    data_key_consumers = {}
    for data_file, payload in data_files.items():
        consumers = list(payload.get("consumers", []))
        for data_key in payload.get("keys", []):
            precise_consumers = [
                record
                for record in consumers
                if _source_references_data_key(
                    source_text_by_state.get(record.state_name, ""),
                    import_aliases_by_state.get(record.state_name, {}).get(data_file, set()),
                    data_key,
                )
            ]
            data_key_consumers[data_key] = precise_consumers or consumers

    for record in states_by_name.values():
        source_text = source_text_by_state.get(record.state_name, "")
        for macro_name in defined_macro_names:
            if _source_references_macro(source_text, macro_name):
                macro_calls.setdefault(macro_name, []).append(record)

    for consumers in macro_calls.values():
        consumers.sort(key=lambda item: item.state_name)

    return ReverseIndex(
        states_by_name=states_by_name,
        states_by_id=states_by_id,
        data_files=data_files,
        data_key_consumers=data_key_consumers,
        macro_calls=macro_calls,
    )


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    lookup = parser.add_mutually_exclusive_group(required=True)
    lookup.add_argument("--state")
    lookup.add_argument("--state-id")
    lookup.add_argument("--data-file")
    lookup.add_argument("--data-key")
    lookup.add_argument("--macro")
    parser.add_argument("--json", action="store_true", dest="as_json")
    return parser


def _resolve_query(
    index: ReverseIndex, args: argparse.Namespace
) -> tuple[str, str, list[dict[str, object]]]:
    if args.state:
        match = index.lookup_state(args.state)
        matches = [] if match is None else [_serialize_state(match)]
        return "state", args.state, matches
    if args.state_id:
        matches = [_serialize_state(record) for record in index.lookup_state_id(args.state_id)]
        return "state_id", args.state_id, matches
    if args.data_file:
        match = index.lookup_data_file(args.data_file)
        matches = [] if match is None else [_serialize_data_match(match)]
        return "data_file", args.data_file, matches
    if args.data_key:
        match = index.lookup_data_key(args.data_key)
        matches = [] if match is None else [_serialize_data_match(match)]
        return "data_key", args.data_key, matches
    matches = [_serialize_state(record) for record in index.lookup_macro(args.macro)]
    return "macro", args.macro, matches


def _print_text(kind: str, value: str, matches: list[dict[str, object]]) -> None:
    if not matches:
        print(f"No provenance found for {kind} '{value}'")
        return

    print(f"Provenance for {kind} '{value}':")
    for match in matches:
        if kind in {"state", "state_id", "macro"}:
            print(f"- {match['state_name']} ({match['relpath']})")
            if match["imported_yaml"]:
                print(f"  imports: {', '.join(match['imported_yaml'])}")
        else:
            print(f"- {match['data_file']}")
            consumers = ", ".join(record["state_name"] for record in match["consumers"])
            print(f"  consumers: {consumers or 'none'}")


def main() -> None:
    args = _build_parser().parse_args()
    index = build_reverse_index()
    kind, value, matches = _resolve_query(index, args)

    if args.as_json:
        print(json.dumps({"query": {"kind": kind, "value": value}, "matches": matches}, indent=2))
    else:
        _print_text(kind, value, matches)

    raise SystemExit(0 if matches else 1)


if __name__ == "__main__":
    main()
