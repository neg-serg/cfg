#!/usr/bin/env python3
"""Managed Telegram Bots — Bot API 9.6 manager bot.

Creates and controls child bots via request_managed_bot / getManagedBotToken.
Runs as a long-polling daemon behind SOCKS5 proxy.
"""

import argparse
import logging
import os
import random
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional
from urllib.parse import quote

import yaml
from telegram import (
    Bot,
    ReplyKeyboardMarkup,
    ReplyKeyboardRemove,
    Update,
)

try:
    from telegram import KeyboardButtonRequestManagedBot  # Bot API 9.6
    _managed_bot_supported = True
except ImportError:
    _managed_bot_supported = False
from telegram.ext import (
    Application,
    CommandHandler,
    ContextTypes,
    MessageHandler,
    filters,
)

logger = logging.getLogger("managed-bots")

REGISTRY_FIELDS = ["bot_user_id", "username", "creator_uid", "created_at",
                   "last_rotated_at", "token_gopass_path"]


def load_config(path: str) -> dict:
    with open(path) as f:
        return yaml.safe_load(f)


def gopass_read(path: str) -> str:
    result = subprocess.run(
        ["gopass", "show", "-o", path],
        capture_output=True, text=True, check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(f"gopass read failed for {path}: {result.stderr.strip()}")
    return result.stdout.strip()


def gopass_insert(path: str, value: str) -> None:
    result = subprocess.run(
        ["gopass", "insert", path],
        input=value, capture_output=True, text=True, check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(f"gopass insert failed for {path}: {result.stderr.strip()}")
    logger.info("Token stored in gopass: %s", path)


class BotRegistry:
    def __init__(self, path: str):
        self.path = Path(path)
        self._data: dict[str, dict] = {}
        self._load()

    def _load(self):
        if self.path.exists():
            with open(self.path) as f:
                self._data = yaml.safe_load(f) or {}

    def _save(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with open(self.path, "w") as f:
            yaml.dump(self._data, f, default_flow_style=False, allow_unicode=True)

    def add(self, username: str, bot_user_id: int, creator_uid: int,
            token_gopass_path: str):
        self._data[username] = {
            "bot_user_id": bot_user_id,
            "username": username,
            "creator_uid": creator_uid,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "last_rotated_at": None,
            "token_gopass_path": token_gopass_path,
        }
        self._save()
        logger.info("Bot registered: @%s (id=%d) by uid=%d",
                    username, bot_user_id, creator_uid)

    def get(self, username: str) -> Optional[dict]:
        return self._data.get(username)

    def update_rotation(self, username: str):
        entry = self._data.get(username)
        if entry:
            entry["last_rotated_at"] = datetime.now(timezone.utc).isoformat()
            self._save()

    def list_all(self) -> list[dict]:
        return list(self._data.values())

    def count_for_user(self, uid: int) -> int:
        return sum(1 for e in self._data.values() if e["creator_uid"] == uid)


class AppState:
    config: dict
    registry: BotRegistry
    gopass_prefix: str
    manager_username: str


state = AppState()


def owner_only(uid: int) -> bool:
    return uid in state.config.get("owner_uids", [])


def allowlisted(uid: int) -> bool:
    return uid in state.config.get("allowlist_uids", [])


def authorized(uid: int) -> bool:
    return owner_only(uid) or allowlisted(uid)


# ── US5: /start handler with self-service gating ────────────────────────

async def start_handler(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    if not update.message or not update.effective_user:
        return
    uid = update.effective_user.id
    if not authorized(uid):
        await update.message.reply_text("Not authorized.",
                                        reply_markup=ReplyKeyboardRemove())
        return
    max_bots = 1 if allowlisted(uid) and not owner_only(uid) else None
    if max_bots is not None and state.registry.count_for_user(uid) >= max_bots:
        await update.message.reply_text(
            f"You already have a managed bot. Maximum is {max_bots}.")
        return
    if not _managed_bot_supported:
        await update.message.reply_text(
            "Managed bot creation is not yet supported — "
            "python-telegram-bot library update pending.",
            reply_markup=ReplyKeyboardRemove())
        return
    button = KeyboardButtonRequestManagedBot(
        request_id=0,
        suggested_name="My Helper Bot",
    )
    keyboard = ReplyKeyboardMarkup.from_button(
        "Create Bot",
        request_managed_bot=button,
    )
    keyboard.resize_keyboard = True
    keyboard.one_time_keyboard = False
    await update.message.reply_text(
        "Tap the button below to create a new managed bot.",
        reply_markup=keyboard,
    )


# ── US6: /newbot handler (t.me/newbot/ link flow) ──────────────────────

async def newbot_handler(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    if not update.message or not update.effective_user:
        return
    uid = update.effective_user.id
    if not authorized(uid):
        await update.message.reply_text("Not authorized.",
                                        reply_markup=ReplyKeyboardRemove())
        return
    max_bots = 1 if allowlisted(uid) and not owner_only(uid) else None
    if max_bots is not None and state.registry.count_for_user(uid) >= max_bots:
        await update.message.reply_text(
            f"You already have a managed bot. Maximum is {max_bots}.")
        return
    parts = (update.message.text or "").split()
    if len(parts) > 1:
        suggested = parts[1].lstrip("@").strip()
    else:
        suggested = "".join(random.choices("abcdefghijklmnopqrstuvwxyz", k=6)) + "_bot"
    name = update.effective_user.full_name or "My Helper Bot"
    link = f"t.me/newbot/{state.manager_username}/{suggested}?name={quote(name)}"
    await update.message.reply_text(
        f"Tap the link below to create your managed bot:\n{link}")

# ── US1: ManagedBotUpdated handler ─────────────────────────────────────

async def on_managed_bot_update(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    managed = getattr(update, "managed_bot", None)
    if not managed:
        return
    creator = managed.get("user")
    new_bot = managed.get("bot")
    if not new_bot or not creator:
        logger.warning("ManagedBotUpdated missing user/bot: %s", managed)
        return
    bot_id = new_bot.get("id")
    username = (new_bot.get("username") or f"bot{bot_id}").lstrip("@")
    creator_uid = creator.get("id")
    if not bot_id or not creator_uid:
        logger.warning("ManagedBotUpdated missing ids: %s", managed)
        return
    logger.info("ManagedBotUpdated: @%s (id=%d) created by uid=%d",
                username, bot_id, creator_uid)
    await handle_new_bot(username, bot_id, creator_uid, update, ctx)


# ── US1: managed_bot_created message handler (duplicate notif) ──────────

async def on_managed_bot_message(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    if not update.message:
        return
    mbc = getattr(update.message, "managed_bot_created", None)
    if mbc:
        logger.info("managed_bot_created message received (duplicate notification, ignoring)")


# ── US2: getManagedBotToken + gopass + registry ────────────────────────

async def handle_new_bot(username: str, bot_user_id: int, creator_uid: int,
                          update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    gopass_path = f"{state.gopass_prefix}/{username}"
    if state.registry.get(username):
        logger.info("Bot @%s already registered, skipping token fetch", username)
        return
    app = ctx.application
    try:
        token = await app.bot.get_managed_bot_token(bot_user_id)
    except Exception as e:
        logger.error("getManagedBotToken failed for @%s: %s", username, e)
        if update.message:
            await update.message.reply_text(
                f"Failed to fetch token for @{username}: {e}")
        return
    if not token:
        logger.error("getManagedBotToken returned empty token for @%s", username)
        return
    try:
        gopass_insert(gopass_path, token)
    except Exception as e:
        logger.error("gopass insert failed: %s", e)
        if update.message:
            await update.message.reply_text(
                f"Bot @{username} created but token storage failed: {e}")
        return
    state.registry.add(
        username=username,
        bot_user_id=bot_user_id,
        creator_uid=creator_uid,
        token_gopass_path=gopass_path,
    )
    msg = f"Bot @{username} created and token stored."
    if update.message:
        await update.message.reply_text(msg)
    logger.info(msg)


# ── Startup: can_manage_bots check ─────────────────────────────────────

def check_can_manage_bots(config: dict) -> bool:
    bot = Bot(token=config["telegram"]["token"],
              base_url="https://api.telegram.org/bot")
    proxy = config["telegram"].get("proxy", {})
    if proxy:
        os.environ["HTTPS_PROXY"] = (
            f"{proxy['scheme']}://{proxy['host']}:{proxy['port']}"
        )
    import asyncio
    me = asyncio.run(bot.get_me())
    state.manager_username = me.username
    can_manage = getattr(me, "can_manage_bots", False)
    logger.info("Bot @%s can_manage_bots=%s", me.username, can_manage)
    return can_manage


# ── US2: Startup registry reconciliation ───────────────────────────────

def reconcile_registry(config: dict, registry: BotRegistry):
    gopass_pfx = config["gopass"]["token_prefix"]
    for entry in registry.list_all():
        username = entry["username"]
        gopass_path = entry.get("token_gopass_path", f"{gopass_pfx}/{username}")
        try:
            gopass_read(gopass_path)
        except RuntimeError:
            logger.warning("Bot @%s token missing from gopass: %s", username, gopass_path)


# ── US4: /bots handler ─────────────────────────────────────────────────

async def bots_handler(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    if not update.message or not update.effective_user:
        return
    uid = update.effective_user.id
    if not owner_only(uid):
        await update.message.reply_text("Not authorized.")
        return
    entries = state.registry.list_all()
    if not entries:
        await update.message.reply_text("No managed bots.")
        return
    lines = ["Managed bots:"]
    for e in entries:
        status = ""
        lines.append(f"  @{e['username']} (id: {e['bot_user_id']}) "
                      f"created {e['created_at'][:10]} by uid {e['creator_uid']}"
                      f"{status}")
    await update.message.reply_text("\n".join(lines))


# ── US3: /rotate_token handler ─────────────────────────────────────────

async def rotate_handler(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    if not update.message or not update.effective_user:
        return
    uid = update.effective_user.id
    if not owner_only(uid):
        await update.message.reply_text("Not authorized.")
        return
    parts = (update.message.text or "").split()
    if len(parts) < 2:
        await update.message.reply_text("Usage: /rotate_token <username>")
        return
    username = parts[1].lstrip("@")
    entry = state.registry.get(username)
    if not entry:
        await update.message.reply_text(f"Bot @{username} not found.")
        return
    bot_user_id = entry["bot_user_id"]
    app = ctx.application
    try:
        new_token = await app.bot.replace_managed_bot_token(bot_user_id)
    except Exception as e:
        logger.error("replaceManagedBotToken failed for @%s: %s", username, e)
        await update.message.reply_text(f"Token rotation failed: {e}")
        return
    if not new_token:
        await update.message.reply_text(f"Token rotation returned empty token for @{username}")
        return
    gopass_path = entry["token_gopass_path"]
    try:
        gopass_insert(gopass_path, new_token)
    except Exception as e:
        logger.error("gopass insert failed during rotation: %s", e)
        await update.message.reply_text(f"Token rotated but storage failed: {e}")
        return
    state.registry.update_rotation(username)
    await update.message.reply_text(f"Token for @{username} rotated and stored.")
    logger.info("Token rotated for @%s", username)


# ── Build application ──────────────────────────────────────────────────

def build_application(config: dict, registry: BotRegistry) -> Application:
    builder = Application.builder()
    builder.token(config["telegram"]["token"])
    proxy = config["telegram"].get("proxy", {})
    if proxy:
        builder.proxy_url(
            f"{proxy['scheme']}://{proxy['host']}:{proxy['port']}"
        )
    app = builder.build()
    app.add_handler(CommandHandler("start", start_handler))
    app.add_handler(CommandHandler("newbot", newbot_handler))
    app.add_handler(CommandHandler("bots", bots_handler))
    app.add_handler(CommandHandler("rotate_token", rotate_handler))
    app.add_handler(MessageHandler(
        filters.StatusUpdate.NEW_CHAT_MEMBERS | filters.StatusUpdate.LEFT_CHAT_MEMBER,
        lambda u, c: None,
    ))
    app.add_handler(MessageHandler(filters.ALL, on_managed_bot_message), group=-1)
    return app


def main():
    parser = argparse.ArgumentParser(
        description="Managed Telegram Bots — Bot API 9.6 manager")
    parser.add_argument("--config", default=os.path.expanduser(
        "~/.config/opencode/managed-bots.yaml"),
        help="Path to YAML config")
    parser.add_argument("--check", action="store_true",
        help="Check can_manage_bots and exit")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )

    config = load_config(args.config)
    state.config = config
    state.gopass_prefix = config["gopass"]["token_prefix"]

    if not check_can_manage_bots(config):
        logger.error("can_manage_bots is False — exiting")
        sys.exit(1)

    if args.check:
        print("can_manage_bots: True")
        sys.exit(0)

    registry = BotRegistry(config["registry"]["path"])
    state.registry = registry
    reconcile_registry(config, registry)

    app = build_application(config, registry)
    app.add_error_handler(lambda update, ctx: logger.error("Unhandled error", exc_info=ctx.error))
    logger.info("Manager bot starting (long polling)")
    app.run_polling(allowed_updates=["message", "managed_bot"])


if __name__ == "__main__":
    main()
