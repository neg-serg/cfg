# Managed Telegram Bots — Operator Guide

## Overview

Managed Bots (Bot API 9.6) allows one "manager" bot to programmatically create and control child bots without BotFather. The manager bot runs as a systemd user service on `telfir`.

## Setup

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

## Usage

### Creating a managed bot

1. Open private chat with the manager bot
2. Send `/start`
3. Tap "Create Bot" button
4. Telegram presents bot creation dialog — pick name and username
5. Manager bot confirms creation and stores the token in gopass

### Listing managed bots

```
/bots
```

Replies with list of all managed bots: username, bot ID, creator UID, creation date.

### Rotating a bot token

```
/rotate_token <username>
```

Calls `replaceManagedBotToken`, stores the new token in gopass, revokes the old one.

### Self-service provisioning

Allowlisted users (non-owners) can also create bots via `states/data/telegram_managed_bots.yaml`:

```yaml
allowlist_uids:
  - "123456789"
```

These users can create up to 1 bot each.

## Token storage

Child bot tokens are stored in gopass at:

```
telegram/managed-bots/<bot_username>
```

Salt states for child bots resolve tokens via:
```
gopass show -o telegram/managed-bots/<bot_username>
```

## Monitoring

- Service: `managed-bots` (pgrep -f managed-bots-runner)
- Logs: `journalctl --user -u managed-bots -f`
- Health check: service should be `active (running)`

## Secrets

| Secret | Purpose |
|--------|---------|
| `api/opencode-telegram-bot` | Manager bot token |
| `api/nanoclaw-telegram-uid` | Owner UID |
| `api/telegram-uid-levra` | Owner UID |
| `telegram/managed-bots/<username>` | Child bot tokens (auto-created) |

## Troubleshooting

- **can_manage_bots is False**: Bot management not enabled in @BotFather
- **getManagedBotToken failed**: Network error or bot management not enabled
- **Token missing from gopass**: Run `gopass show telegram/managed-bots/<username>` to verify
