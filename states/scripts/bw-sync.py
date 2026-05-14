#!/usr/bin/env python3
"""One-way import from Vaultwarden (via Bitwarden CLI) to gopass.

gopass is authoritative — conflicts resolve in its favor.

Timer mode (systemd — no stdin):
  export BW_SESSION="$(bw unlock --raw)"  # in the oneshot ExecStart
  export BW_PASSWORD=<your-pw>            # OR: bw unlock --passwordenv BW_PASSWORD

Requires:
  - bitwarden-cli (AUR package)
  - bw CLI authenticated: BW_CLIENTID + BW_CLIENTSECRET in environment or gopass
  - gopass
"""

import json
import os
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
from lib.pretty import pretty

GOPASS_PREFIX = "bw"


def run(cmd, **kwargs):
    return subprocess.run(cmd, capture_output=True, text=True, check=True, **kwargs)


def bw_unlock():
    """Unlock Bitwarden vault; return session key."""
    bw_session = os.environ.get("BW_SESSION")
    if bw_session:
        return bw_session
    bw_password = os.environ.get("BW_PASSWORD")
    if bw_password:
        result = run(["bw", "unlock", "--passwordenv", "BW_PASSWORD", "--raw"])
        return result.stdout.strip()
    result = run(["bw", "unlock", "--raw"])
    return result.stdout.strip()


def bw_export(session):
    """Export all items from Vaultwarden as JSON."""
    env = os.environ.copy()
    env["BW_SESSION"] = session
    result = run(["bw", "export", "--format", "json"], env=env)
    return json.loads(result.stdout)


def gopass_list():
    """List all paths in gopass store."""
    result = run(["gopass", "ls", "--flat"])
    paths = result.stdout.strip()
    if not paths:
        return set()
    return {p for p in paths.split("\n") if p}


def gopass_insert(path, password, fields=None):
    """Insert or update a gopass entry."""
    content = password
    if fields:
        for k, v in sorted(fields.items()):
            content += f"\n{k}: {v}"
    run(["gopass", "insert", "--force", path], input=content)


def bw_item_to_gopass_path(item, folder_map=None):
    """Convert a Bitwarden item to a gopass path under the bw/ namespace."""
    name = item.get("name", "unknown")
    login = item.get("login", {})
    username = login.get("username", "")
    uris = login.get("uris", [])
    domain = ""
    for uri_info in uris:
        u = uri_info.get("uri", "")
        if u:
            parsed = urlparse(u)
            domain = parsed.netloc or parsed.path
            break
    folder_id = item.get("folderId", "")
    path_parts = [GOPASS_PREFIX]
    if folder_id and folder_map:
        folder_name = folder_map.get(folder_id, "")
        if folder_name:
            path_parts.append(folder_name.lower().replace(" ", "_"))
    if domain:
        path_parts.append(domain)
    else:
        path_parts.append(name.lower().replace(" ", "_").replace("/", "_"))
    if username:
        path_parts[-1] = username + "@" + path_parts[-1]
    return "/".join(path_parts)


def build_folder_map(items):
    """Build UUID → name mapping from Bitwarden export folders list."""
    return {f["id"]: f["name"] for f in items.get("folders", []) if "id" in f and "name" in f}


def sync_vaultwarden_to_gopass(session):
    """Import Vaultwarden items that don't exist in gopass."""
    items = bw_export(session)
    folder_map = build_folder_map(items)
    existing = gopass_list()
    imported = 0
    for item in items.get("items", []):
        if item.get("type") != 1:
            continue
        path = bw_item_to_gopass_path(item, folder_map)
        if path in existing:
            continue
        login = item.get("login", {})
        password = login.get("password", "")
        fields = {
            "username": login.get("username", ""),
            "note": item.get("notes", "") or "",
        }
        uris = login.get("uris", [])
        for i, uri_info in enumerate(uris):
            fields[f"uri_{i + 1}"] = uri_info.get("uri", "")
        gopass_insert(path, password, fields)
        print(f"  imported {path}")
        imported += 1
    return imported


def main():
    try:
        pretty.info("Starting sync Vaultwarden → gopass")
        session = bw_unlock()
        imported = sync_vaultwarden_to_gopass(session)
        pretty.ok(f"Done — imported {imported} new items")
        run(["gopass", "sync"])
    except subprocess.CalledProcessError as e:
        print(f"bw-sync: FAILED — {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"bw-sync: FAILED — {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
