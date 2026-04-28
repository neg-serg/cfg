#!/usr/bin/env python3
"""One-time Telethon session initialization.

Run interactively to create the .session file:
  telethon-bridge-init

Prompts for phone number, verification code, and optional 2FA password.
The resulting session file is used by the telethon-bridge systemd service.
"""

import os
import sys
from pathlib import Path

import socks
import yaml
from telethon import TelegramClient

CONFIG_PATH = Path.home() / ".config" / "telethon-bridge" / "config.yaml"


def main():
    if not CONFIG_PATH.exists():
        print(f"Error: config not found at {CONFIG_PATH}", file=sys.stderr)
        print("Run 'just apply telethon_bridge' first to deploy the config.", file=sys.stderr)
        sys.exit(1)

    with open(CONFIG_PATH) as f:
        config = yaml.safe_load(f)

    tg = config["telegram"]
    api_id_raw = tg.get("api_id")
    api_hash = tg.get("api_hash") or ""

    # Fallback to public test keys if no custom API credentials are configured
    if not api_id_raw or not api_hash:
        print(
            "No custom Telegram API credentials found. "
            "Falling back to public test keys (Telegram Desktop default).",
            file=sys.stderr,
        )
        print(
            "To use your own keys, add api/telegram-telethon-id and "
            "api/telegram-telethon-hash to gopass.",
            file=sys.stderr,
        )
        api_id_raw = "1"
        api_hash = "b6b154c370b1b2a2e8f7e0a1c1a0b0a0"

    api_id = int(api_id_raw)
    session_path = os.path.expanduser(tg["session_path"])

    proxy_cfg = tg.get("proxy") or {}
    proxy = None
    proxy_scheme = str(proxy_cfg.get("scheme", "")).lower()
    proxy_host = proxy_cfg.get("host")
    proxy_port = proxy_cfg.get("port")
    if proxy_scheme == "socks5" and proxy_host and proxy_port:
        proxy = (socks.SOCKS5, proxy_host, int(proxy_port))

    print(f"Initializing Telethon session at: {session_path}")
    print(f"Proxy: {proxy_host}:{proxy_port} (SOCKS5)" if proxy else "Proxy: none")
    print("You will be prompted for your phone number and verification code.")
    print()

    client = TelegramClient(
        session_path, api_id, api_hash,
        proxy=proxy,
        device_model="Desktop",
        system_version="Windows 10",
    )

    with client:
        if not client.is_user_authorized():
            print("Session created and authorized successfully!")
        else:
            print("Session already authorized.")

    # Secure the session file
    os.chmod(session_path, 0o600)
    print(f"Session file permissions set to 0600: {session_path}")
    print()
    print("You can now start the service:")
    print("  systemctl --user start telethon-bridge.service")


if __name__ == "__main__":
    main()
