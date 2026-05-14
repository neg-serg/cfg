#!/usr/bin/env python3
"""Mechanically replace Jinja macro calls with salt['module.func'] in .sls files.
After this script runs, macro files can be emptied.

Usage: python3 scripts/migrate-sls-to-python.py [--dry-run]
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.pretty import pretty

REPO_ROOT = Path(__file__).resolve().parent.parent
DRY_RUN = "--dry-run" in sys.argv

# Macro function → salt['module.func'] mapping
FUNC_MAP: dict[str, str] = {
    "feature_enabled": "host.feature_enabled",
    "feature_default": "host.feature_default",
    "gopass_secret": "secrets.get",
    "proxypilot_key": "secrets.proxypilot_key",
    "tg_secret": "secrets.tg_secret",
    "download_cached": "installer.download_cached",
    "ver_stamp": "installer.ver_stamp",
    "config_file_edit": "config.config_file_edit",
    "container_service": "container.deploy",
    "browser_extensions": "desktop.browser_extensions",
    "hyprpm_update": "desktop.hyprpm_update",
    "hyprpm_add": "desktop.hyprpm_add",
    "hyprpm_enable": "desktop.hyprpm_enable",
    "dconf_settings": "desktop.dconf_settings",
    "go_pkg": "installer.go_pkg",
    "curl_bin": "installer.curl_bin",
    "cargo_pkg": "installer.cargo_pkg",
    "pip_pkg": "installer.pip_pkg",
    "http_file": "installer.http_file",
    "git_clone_deploy": "installer.git_clone_deploy",
    "git_clone_build": "installer.git_clone_build",
    "download_font_zip": "installer.download_font_zip",
    "github_release_to": "installer.github_release_to",
    "npm_build_workflow": "installer.npm_build_workflow",
    "curl_extract_tar": "installer.curl_extract_tar",
    "curl_extract_zip": "installer.curl_extract_zip",
    "huggingface_file": "installer.huggingface_file",
    "firefox_extension": "installer.firefox_extension",
    "install_catalog": "installer.install_catalog",
    "paru_install": "pkg.paru_install",
    "simple_service": "pkg.simple_service",
    "pkgbuild_install": "pkg.pkgbuild_install",
    "flatpak_install": "pkg.flatpak_install",
    "ensure_dir": "service.ensure_dir",
    "remove_native_unit": "service.remove_native_unit",
    "remove_native_package": "service.remove_native_package",
    "ensure_running": "service.ensure_running",
    "service_stopped": "service.service_stopped",
    "unit_override": "service.unit_override",
    "udev_rule": "service.udev_rule",
    "service_with_unit": "service.service_with_unit",
    "service_with_healthcheck": "service.service_with_healthcheck",
    "env_block": "service.env_block",
    "managed_resource_value": "service.managed_resource_value",
    "managed_mode_value": "service.managed_mode_value",
    "managed_sysusers_line": "service.managed_sysusers_line",
    "managed_tmpfiles_line": "service.managed_tmpfiles_line",
    "managed_identity_guard": "service.managed_identity_guard",
    "managed_path_guard": "service.managed_path_guard",
    "user_service_file": "user_service.user_service_file",
    "user_unit_override": "user_service.user_unit_override",
    "user_service_enable": "user_service.user_service_enable",
    "user_service_with_unit": "user_service.user_service_with_unit",
    "user_service_restart": "user_service.user_service_restart",
    "user_service_disable": "user_service.user_service_disable",
    "user_linger": "user_service.user_linger",
}

# Functions that stay as Jinja macros (keep import)
KEEP_AS_MACROS = {"render_service", "ipv6_tunnel", "_tilde_expand", "_cs_fail"}

# Import line patterns
MACRO_IMPORT_RE = re.compile(
    r'\{%-?\s*from\s+[\'"]_macros_\w+\.jinja[\'"]\s+import\s+(.*?)\s*-?%\}'
)

# All function names sorted by length descending so longer names match first
ALL_FUNC_NAMES = sorted(FUNC_MAP.keys(), key=len, reverse=True)


def migrate_sls(path: Path) -> str | None:
    content = path.read_text()
    original = content

    changes = []

    # 1. Process import lines from _macros_*.jinja
    for match in MACRO_IMPORT_RE.finditer(content):
        full_line = match.group(0)
        imported_names = [n.strip() for n in match.group(1).split(",")]

        keep = [n for n in imported_names if n in KEEP_AS_MACROS]
        remove = [n for n in imported_names if n in FUNC_MAP]

        if not remove:
            continue

        if keep:
            new_line = f"{{#- from '_macros_service.jinja' import {', '.join(keep)} -#}}"
            content = content.replace(full_line, new_line, 1)
        else:
            content = content.replace(full_line, "", 1)

        changes.append(f"import: removed {remove}, kept {keep}")

    # 2. Replace macro function calls with salt[...]()
    for func_name in ALL_FUNC_NAMES:
        salt_path = FUNC_MAP[func_name]
        if func_name == "gopass_secret":
            pattern = r"(?<!\w)gopass_secret\("
        else:
            pattern = rf"(?<!\w){re.escape(func_name)}\("

        count = len(re.findall(pattern, content))
        if count > 0:
            replacement = f"salt['{salt_path}']("
            content = re.sub(pattern, replacement, content)
            changes.append(f"func: {count}x {func_name}() → salt['{salt_path}']()")

    # 3. Fix feature_enabled call signature: salt['host.feature_enabled'](host, name)
    #    but Python expects salt['host.feature_enabled'](name, host=host)
    #    We need to swap args. For now, just replace; signature stays same.
    #    Actually the Python host_features.feature_enabled takes (name, host=None)
    #    and the .sls calls it as feature_enabled(host, 'mpd')
    #    So args need reordering: (host, 'mpd') → ('mpd', host=host)
    #    This is tricky with regex. Let me do it:
    if "salt['host.feature_enabled'](" in content:
        count2 = len(re.findall(r"salt\['host\.feature_enabled'\]\([^)]+\)", content))
        # Simple case: salt['host.feature_enabled'](host, 'x') → swap positional args
        # Replace the call pattern manually
        modified2 = re.sub(
            r"salt\['host\.feature_enabled'\]\((\w+)\s*,\s*'([^']+)'\)",
            r"salt['host.feature_enabled']('\2', host=\1)",
            content,
        )
        if modified2 != content:
            changes.append(f"fix: reordered feature_enabled args for {count2} calls")
            content = modified2

    if content != original:
        if not DRY_RUN:
            path.write_text(content)
        return "\n".join(changes)
    return None


def main():
    sls_files = sorted(REPO_ROOT.glob("states/**/*.sls"))
    total = 0

    for path in sls_files:
        result = migrate_sls(path)
        if result:
            rel = path.relative_to(REPO_ROOT)
            status = f"[{'DRY' if DRY_RUN else 'OK'}] {rel}"
            if DRY_RUN:
                pretty.info(status)
            else:
                pretty.ok(status)
            for line in result.split("\n"):
                print(f"    {line}")
            total += 1

    if total == 0:
        pretty.info("No .sls files needed changes.")
        return

    pretty.ok(f"{total} files modified.")

    if not DRY_RUN:
        for f in REPO_ROOT.glob("states/_macros_*.jinja"):
            f.write_text(
                "{# All business logic migrated to states/_modules/. "
                "File kept for backward compatibility. #}\n"
            )
            pretty.info(f"[CLEAR] {f.name}")

    followup = (
        " Use 'git diff' to review changes." if not DRY_RUN else " Run without --dry-run to apply."
    )
    pretty.info(f"Done.{followup}")


if __name__ == "__main__":
    main()
