#!/usr/bin/env python3
"""Generate Hyprland shortcut search data and wlr-which-key config."""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path

import yaml

MODIFIER_NAMES = {
    "$ALT": "Alt",
    "$C": "Ctrl",
    "$M1": "Alt",
    "$M4": "Super",
    "$S": "Shift",
}

KEY_NAMES = {
    "apostrophe": "'",
    "backslash": "\\",
    "comma": ",",
    "equal": "=",
    "escape": "Escape",
    "minus": "-",
    "period": ".",
    "return": "Return",
    "semicolon": ";",
    "slash": "/",
    "space": "Space",
    "tab": "Tab",
}


class QuotedString(str):
    """Render YAML key fields with explicit double quotes."""


class QuotedKeyDumper(yaml.SafeDumper):
    pass


def _represent_quoted_string(dumper: yaml.SafeDumper, data: QuotedString) -> yaml.nodes.Node:
    return dumper.represent_scalar("tag:yaml.org,2002:str", str(data), style='"')


QuotedKeyDumper.add_representer(QuotedString, _represent_quoted_string)


@dataclass(frozen=True)
class BindingAction:
    source: str
    submap: str
    modifiers: tuple[str, ...]
    key: str
    dispatcher: str
    argument: str
    hotkey: str
    signature: str


def load_metadata(path: Path) -> dict:
    return yaml.safe_load(path.read_text()) or {}


def normalize_key(key: str) -> str:
    lowered = key.lower()
    if lowered in KEY_NAMES:
        return KEY_NAMES[lowered]
    return key.upper() if len(key) == 1 else key


def normalize_modifiers(raw: str) -> tuple[str, ...]:
    if not raw.strip():
        return ()
    tokens = raw.replace("+", " ").split()
    return tuple(MODIFIER_NAMES.get(token, token) for token in tokens)


def format_hotkey(modifiers: tuple[str, ...], key: str) -> str:
    parts = [*modifiers, normalize_key(key)]
    return "+".join(parts)


def resolve_source_path(root: Path, current: Path, source: str) -> Path:
    source = source.strip().strip('"')
    hypr_prefix = "~/.config/hypr/"

    if source.startswith(hypr_prefix):
        return root.parent / source.removeprefix(hypr_prefix)
    if source.startswith("/"):
        return Path(source)
    return current.parent / source


def iter_binding_files(root: Path) -> list[Path]:
    files: list[Path] = []
    seen: set[Path] = set()

    def walk(path: Path) -> None:
        resolved = path.resolve()
        if resolved in seen:
            return
        if not path.exists():
            raise SystemExit(f"binding source not found: {path}")

        seen.add(resolved)
        files.append(path)

        for raw_line in path.read_text().splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#") or not line.startswith("source ="):
                continue
            source = line.split("=", 1)[1].strip()
            walk(resolve_source_path(root, path, source))

    walk(root)
    return files


def load_bindings(root: Path) -> list[BindingAction]:
    raw_actions = []
    trigger_hotkeys: dict[str, str] = {}

    for path in iter_binding_files(root):
        active_submap = "root"
        for raw_line in path.read_text().splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("submap ="):
                active_submap = line.split("=", 1)[1].strip()
                continue
            if not line.startswith("bind"):
                continue

            payload = line.split("=", 1)[1].strip()
            parts = [part.strip() for part in payload.split(",", 3)]
            if len(parts) == 3:
                modifiers, key, dispatcher = parts
                argument = ""
            elif len(parts) == 4:
                modifiers, key, dispatcher, argument = parts
            else:
                raise SystemExit(f"unsupported binding syntax in {path}: {raw_line}")
            mod_tuple = normalize_modifiers(modifiers)
            local_hotkey = format_hotkey(mod_tuple, key)
            raw_actions.append(
                {
                    "source": str(path.relative_to(root.parent)),
                    "submap": active_submap,
                    "modifiers": mod_tuple,
                    "key": key,
                    "dispatcher": dispatcher,
                    "argument": argument,
                    "local_hotkey": local_hotkey,
                }
            )

            if active_submap == "root" and dispatcher == "submap" and argument != "reset":
                trigger_hotkeys[argument] = local_hotkey

    actions = []
    for item in raw_actions:
        hotkey = item["local_hotkey"]
        if item["submap"] != "root" and item["submap"] in trigger_hotkeys:
            hotkey = f"{trigger_hotkeys[item['submap']]}, {item['local_hotkey']}"

        actions.append(
            BindingAction(
                source=item["source"],
                submap=item["submap"],
                modifiers=item["modifiers"],
                key=item["key"],
                dispatcher=item["dispatcher"],
                argument=item["argument"],
                hotkey=hotkey,
                signature=f"{item['submap']}|{item['key']}|{item['dispatcher']}|{item['argument']}",
            )
        )
    return actions


def index_actions(actions: list[BindingAction]) -> dict[str, list[BindingAction]]:
    index: dict[str, list[BindingAction]] = {}
    for action in actions:
        index.setdefault(action.signature, []).append(action)
    return index


def resolve_action(
    index: dict[str, list[BindingAction]], match: str, context: str
) -> BindingAction:
    matches = index.get(match, [])
    if not matches:
        raise SystemExit(f"{context} match not found: {match}")
    if len(matches) > 1:
        raise SystemExit(f"{context} match is ambiguous: {match}")
    return matches[0]


def resolve_search_binding(entry: dict, index: dict[str, list[BindingAction]]) -> tuple[str, str]:
    has_match = "match" in entry
    has_explicit = "command" in entry or "hotkey" in entry

    if has_match and has_explicit:
        raise SystemExit(f"search entry mixes match and explicit fields: {entry['id']}")
    if has_match:
        action = resolve_action(index, entry["match"], "metadata")
        return action.argument, action.hotkey
    if "command" not in entry or "hotkey" not in entry:
        raise SystemExit(f"search entry requires match or command+hotkey: {entry['id']}")
    return entry["command"], entry["hotkey"]


def resolve_which_key_command(section: dict, index: dict[str, list[BindingAction]]) -> str:
    has_match = "match" in section
    has_cmd = "cmd" in section

    if has_match and has_cmd:
        raise SystemExit(f"which-key entry mixes match and cmd fields: {section['desc']}")
    if has_match:
        return resolve_action(index, section["match"], "which-key").argument
    if not has_cmd:
        raise SystemExit(f"which-key entry requires match or cmd: {section['desc']}")
    return section["cmd"]


def build_search_entries(actions: list[BindingAction], metadata: dict) -> list[dict]:
    action_index = index_actions(actions)
    entries = []
    entry_ids: set[str] = set()

    for entry in metadata.get("entries", []):
        if entry["id"] in entry_ids:
            raise SystemExit(f"duplicate search entry id: {entry['id']}")
        entry_ids.add(entry["id"])
        command, hotkey = resolve_search_binding(entry, action_index)
        label = f"{entry['group']} / {entry['title']}  {hotkey}"
        entries.append(
            {
                "id": entry["id"],
                "title": entry["title"],
                "group": entry["group"],
                "hotkey": hotkey,
                "command": command,
                "mode": entry.get("mode", "launchable"),
                "keywords": entry.get("keywords", []),
                "label": label,
            }
        )

    entries.sort(key=lambda entry: (entry["group"], entry["title"], entry["hotkey"]))
    return entries


def render_which_key_config(actions: list[BindingAction], metadata: dict) -> str:
    action_index = index_actions(actions)
    document = {
        "font": "Iosevka 12",
        "background": "#1a1b26e6",
        "color": "#c0caf5",
        "border": "#7aa2f7",
        "separator": " → ",
        "border_width": 2,
        "corner_r": 10,
        "padding": 15,
        "rows_per_column": 8,
        "column_padding": 25,
        "anchor": "center",
        "namespace": "wlr_which_key",
        "menu": [],
    }

    for section in metadata.get("which_key", []):
        node = {"key": QuotedString(section["key"]), "desc": section["desc"]}
        if "entries" in section:
            node["submenu"] = []
            for item in section["entries"]:
                node["submenu"].append(
                    {
                        "key": QuotedString(item["key"]),
                        "desc": item["desc"],
                        "cmd": resolve_which_key_command(item, action_index),
                    }
                )
        else:
            node["cmd"] = resolve_which_key_command(section, action_index)
        document["menu"].append(node)

    return yaml.dump(
        document,
        Dumper=QuotedKeyDumper,
        sort_keys=False,
        allow_unicode=False,
    )


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bindings", type=Path, required=True)
    parser.add_argument("--metadata", type=Path, required=True)
    parser.add_argument("--search-output", type=Path, required=True)
    parser.add_argument("--which-key-output", type=Path, required=True)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    actions = load_bindings(args.bindings)
    metadata = load_metadata(args.metadata)
    search_entries = build_search_entries(actions, metadata)
    args.search_output.parent.mkdir(parents=True, exist_ok=True)
    args.search_output.write_text(json.dumps(search_entries, indent=2) + "\n")
    args.which_key_output.parent.mkdir(parents=True, exist_ok=True)
    args.which_key_output.write_text(render_which_key_config(actions, metadata))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
