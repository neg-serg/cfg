# Managed Telegram Bots (Bot API 9.6+)

## Overview

Bot API 9.6 (April 3, 2026) introduced **Managed Bots** — the ability for a bot to
programmatically create and control other bots without using BotFather.

This enables multi-bot runners: one manager bot creates, tokens, and manages
dozens of bots for different tasks without any manual interaction.

## How it works

1. The manager bot enables "bot management" in the @BotFather Mini App.
2. `getMe` returns `can_manage_bots: true`.
3. The bot presents a button or link to a user.
4. The user taps → Telegram asks them to create a bot → done.
5. The manager bot receives the new bot's token via `getManagedBotToken(user_id)`.

## Prerequisites

- The manager bot must have **bot management enabled** via the @BotFather Mini App
- Only bots with `can_manage_bots: true` (from `getMe`) can participate
- Managed bot creation works in **private chats only**

## API Reference

### User field: `can_manage_bots`

```
Field             Type      Description
can_manage_bots   Boolean   True if other bots can be created to be
                            controlled by this bot. Returned in getMe only.
```

### Triggering bot creation

**1. Keyboard button** — `KeyboardButton` with `request_managed_bot`:

```json
{
  "text": "Create a bot",
  "request_managed_bot": {
    "request_id": 0,
    "suggested_name": "My Helper",
    "suggested_username": "my_helper_bot"
  }
}
```

**2. Link** — send a `t.me` link:
```
https://t.me/newbot/{manager_username}/{suggested_username}?name={name}
```

**3. Mini App** — pre-save a managed-bot button via `savePreparedKeyboardButton`.

### Receiving the created bot

The manager bot receives two things:

1. **Update** with `managed_bot` → `ManagedBotUpdated`:
   - `user` — the User who created the bot
   - `bot` — the User object of the new bot

2. **Message** with `managed_bot_created` → `ManagedBotCreated`:
   - `bot` — the User object of the new bot

### Token management

```python
# Get the token
GET /bot<manager_token>/getManagedBotToken?user_id=<new_bot_user_id>
→ "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"

# Replace (revoke old, generate new)
GET /bot<manager_token>/replaceManagedBotToken?user_id=<new_bot_user_id>
→ "654321:XYZ-DEF5678ghIkl-zyx57W2v1u123ew11"
```

### Updates for token/owner changes

If the token or owner of a managed bot changes later, the manager bot
receives another `ManagedBotUpdated` update via the `managed_bot` field.

## Example workflow

```
1. Manager bot sends keyboard with request_managed_bot button
2. User taps button → Telegram shows bot creation dialog
3. User picks name/username → bot is created
4. Manager bot receives:
   - Update.managed_bot (user who created, bot info)
   - Message.managed_bot_created (bot info)
5. Manager bot calls getManagedBotToken → gets the token
6. Manager bot can now control the new bot (set webhook, etc.)
```

## Use cases for this project

- Multi-bot runner: one Salt-managed systemd service runs a manager bot
  that spins up task-specific bots on demand
- Self-service: users click a button → get a personal bot for monitoring,
  screenshots, secrets access, VPN control, etc.
- No more BotFather: token creation and rotation fully automated

## References

- [Telegram Bot API documentation](https://core.telegram.org/bots/api)
- [@BotNews](https://t.me/botnews) — official Bot API changelog
- [@BotFather](https://t.me/BotFather) — enable bot management

## Operator Guide

### Overview

Managed Bots (Bot API 9.6) allows one "manager" bot to programmatically create and control child bots without BotFather. The manager bot runs as a systemd user service on `telfir`.

### Setup

1. **Enable bot management in @BotFather**:
   - Open @BotFather, send `/mybots`, select the manager bot
   - Go to "Bot Management Settings" → enable "Allow creating bots"
   - Verify: `systemctl --user start managed-bots && journalctl -u managed-bots -f`
   - Should see `can_manage_bots=True`

2. **Deploy via Salt**:
   ```
   salt-call state.apply managed_bots --local
   ```

3. **Verify service**:
   ```
   systemctl --user status managed-bots
   ```

### Usage

#### Creating a managed bot

1. Open private chat with the manager bot
2. Send `/start`
3. Tap "Create Bot" button
4. Telegram presents bot creation dialog — pick name and username
5. Manager bot confirms creation and stores the token in gopass

#### Listing managed bots

```
/bots
```

Replies with list of all managed bots: username, bot ID, creator UID, creation date.

#### Rotating a bot token

```
/rotate_token <username>
```

Calls `replaceManagedBotToken`, stores the new token in gopass, revokes the old one.

#### Self-service provisioning

Allowlisted users (non-owners) can also create bots via `states/data/telegram_managed_bots.yaml`:

```yaml
allowlist_uids:
  - "123456789"
```

These users can create up to 1 bot each.

### Token storage

Child bot tokens are stored in gopass at:

```
telegram/managed-bots/<bot_username>
```

Salt states for child bots resolve tokens via:
```
gopass show -o telegram/managed-bots/<bot_username>
```

### Monitoring

- Service: `managed-bots` (pgrep -f managed-bots-runner)
- Logs: `journalctl --user -u managed-bots -f`
- Health check: service should be `active (running)`

### Secrets

| Secret | Purpose |
|--------|---------|
| `api/opencode-telegram-bot` | Manager bot token |
| `api/nanoclaw-telegram-uid` | Owner UID |
| `api/telegram-uid-levra` | Owner UID |
| `telegram/managed-bots/<username>` | Child bot tokens (auto-created) |

### Troubleshooting

- **can_manage_bots is False**: Bot management not enabled in @BotFather
- **getManagedBotToken failed**: Network error or bot management not enabled
- **Token missing from gopass**: Run `gopass show telegram/managed-bots/<username>` to verify
