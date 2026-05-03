# Managed Telegram Bots (Bot API 9.6)

**Branch**: `001-managed-telegram-bots`
**Created**: 2026-05-03
**Status**: Draft

## Input Description

Implement a manager bot using Telegram Bot API 9.6 Managed Bots feature that programmatically creates and controls child bots without BotFather. Users click a button → Telegram creates a bot → manager bot receives the token and can deploy/control it. This replaces manual BotFather token creation with automated multi-bot orchestration managed via Salt.

---

## User Stories

| # | Title | Priority | Why |
|---|-------|----------|-----|
| US-1 | Create managed bot via button | P1 | Core feature: no value without bot creation flow |
| US-2 | Manager receives and stores bot token | P1 | Token is the credential needed for all child bot operations |
| US-3 | Manager bot replaces/rotates child bot tokens | P2 | Security requirement for token lifecycle |
| US-4 | Manager bot lists and reports managed bots | P2 | Visibility into what bots exist and their status |
| US-5 | Self-service bot provisioning for end users | P3 | Allows non-operator users to provision bots for themselves |

### US-1: Create managed bot via button

**Priority**: P1
**Description**: A user in a private chat with the manager bot taps a "Create Bot" button. Telegram presents bot creation dialog (name, username). Upon completion, the manager bot receives the new bot's identity and token.

**Independent test**: Send `/start` to the manager bot, tap "Create Bot", complete creation flow, verify manager bot acknowledges the new bot.

**Acceptance Scenarios**:
- **Given** user starts private chat with manager bot, **when** manager bot sends keyboard with `request_managed_bot` button, **then** user sees "Create Bot" button
- **Given** user taps "Create Bot" button, **when** Telegram shows creation dialog and user completes it, **then** manager bot receives `ManagedBotUpdated` update with new bot user object
- **Given** bot creation succeeds, **when** manager bot receives the update, **then** manager bot calls `getManagedBotToken` and receives the token

### US-2: Manager receives and stores bot token

**Priority**: P1
**Description**: After a managed bot is created, the manager bot retrieves its token via `getManagedBotToken` and persists it securely (gopass, config file) for subsequent Salt deployment.

**Independent test**: Create a test managed bot, verify the token is stored in gopass under `telegram/managed-bots/<bot_username>`.

**Acceptance Scenarios**:
- **Given** a `ManagedBotUpdated` update is received, **when** manager bot calls `getManagedBotToken(new_bot_user_id)`, **then** token is returned and stored
- **Given** token is stored in gopass, **when** Salt state runs for a managed bot, **then** the state resolves the token from gopass and deploys the bot

### US-3: Manager bot replaces/rotates child bot tokens

**Priority**: P2
**Description**: Owner can trigger token rotation for any managed bot. The manager bot calls `replaceManagedBotToken`, stores the new token, and triggers redeployment of the affected bot.

**Independent test**: Select a managed bot, send `/rotate_token <bot_username>`, verify new token is stored and old token is revoked.

**Acceptance Scenarios**:
- **Given** a managed bot exists with known token, **when** owner sends `/rotate_token <username>`, **then** manager bot calls `replaceManagedBotToken`, stores new token, reports success
- **Given** token rotation succeeds, **when** affected bot's Salt state redeploys, **then** bot uses new token and old token no longer works

### US-4: Manager bot lists and reports managed bots

**Priority**: P2
**Description**: Owner can query the manager bot for a list of all managed bots, their usernames, creation dates, and operational status.

**Independent test**: Send `/bots` command to manager bot, verify response lists all managed bots with correct metadata.

**Acceptance Scenarios**:
- **Given** multiple managed bots have been created, **when** owner sends `/bots` command, **then** manager bot replies with list of bots (username, creation date, status)
- **Given** no managed bots exist, **when** owner sends `/bots`, **then** manager bot replies "No managed bots"

### US-5: Self-service bot provisioning for end users

**Priority**: P3
**Description**: Non-owner users (members of allowed UID list) can create their own managed bots via the manager bot, subject to rate limits and naming constraints.

**Independent test**: Allowlisted user starts chat with manager bot, creates a bot, verifies it appears in their personal scope.

**Acceptance Scenarios**:
- **Given** an allowlisted user starts private chat, **when** they tap "Create Bot" and complete flow, **then** bot is created and associated with their UID
- **Given** a non-allowlisted user attempts to create a bot, **when** they tap "Create Bot", **then** manager bot rejects with "Not authorized"

---

## Edge Cases

| # | Scenario | Description |
|---|----------|-------------|
| EC-1 | Bot creation cancelled by user | User opens creation dialog but cancels — manager bot receives no update, nothing happens |
| EC-2 | Duplicate username | User picks a taken username — Telegram UI handles rejection natively, manager bot never sees it |
| EC-3 | Rate limit on bot creation | Telegram imposes per-user limit on managed bot creation (currently unknown) — manager bot surfaces the error to user |
| EC-4 | Manager bot token revoked | If manager bot's own token is revoked, all managed bots become orphaned — need alerting |
| EC-5 | `getManagedBotToken` fails | Network error, API change, or bot ownership lost — retry with backoff, alert on persistent failure |
| EC-6 | Managed bot deleted externally | Bot deleted via BotFather instead of manager — next token fetch fails, manager marks bot as "deleted" |
| EC-7 | Token rotation during Salt deployment | Race between token rotation and Salt applying old token — Salt state handles "invalid token" gracefully |
| EC-8 | Multiple manager bots | Two manager bots with same `can_manage_bots` flag? Not applicable — only one manager bot per token |

---

## Functional Requirements

| ID | Description | Must |
|----|-------------|------|
| FR-001 | Manager bot sends `KeyboardButton` with `request_managed_bot` field on `/start` command | Yes |
| FR-002 | Manager bot processes `Update.managed_bot` and extracts `user` (creator) and `bot` (new bot) objects | Yes |
| FR-003 | Manager bot calls `getManagedBotToken` API endpoint with child bot's `user_id` | Yes |
| FR-004 | Received token is stored in gopass under `telegram/managed-bots/<bot_username>` | Yes |
| FR-005 | Manager bot supports `/bots` command listing all managed bots with metadata | Yes |
| FR-006 | Manager bot supports `/rotate_token <username>` command calling `replaceManagedBotToken` | Yes |
| FR-007 | Owner UIDs are validated before executing privileged commands (`/rotate_token`, `/bots`) | Yes |
| FR-008 | Manager bot logs all bot creation, token rotation, and deletion events to system journal | Yes |
| FR-009 | Manager bot runs as a systemd user service managed by Salt | Yes |
| FR-010 | Managed bot tokens are resolvable by Salt states via gopass secrets | Yes |
| FR-011 | Manager bot validates `can_manage_bots: true` from `getMe` at startup, exits if false | Yes |
| FR-012 | Self-service provisioning respects an allowlist of user IDs that can create bots (US-5) | No |

---

## Key Entities

| Entity | Description | Relationships |
|--------|-------------|---------------|
| ManagerBot | The parent bot with `can_manage_bots: true`, interacts with Telegram Bot API, stores tokens | Creates 0..N ManagedBot |
| ManagedBot | A child bot created by ManagerBot; has `user_id`, `username`, `token`, `creator_uid`, `created_at` | Belongs to ManagerBot, deployed via Salt |
| BotOwner | A Telegram user authorized to operate the ManagerBot (privileged commands) | Owns ManagerBot, creates ManagedBots (if self-service) |

---

## Success Criteria

| ID | Metric | Type |
|----|--------|------|
| SC-001 | User can create a managed bot within 3 interactions (tap button → pick name → done) | performance |
| SC-002 | Token is stored in gopass within 2 seconds of bot creation | performance |
| SC-003 | Token rotation completes in under 10 seconds with no downtime for the child bot | performance |
| SC-004 | Manager bot startup self-check (`can_manage_bots`) completes within 1 second | performance |
| SC-005 | 100% of managed bot tokens are stored in gopass, not in plaintext files | quality |
| SC-006 | All bot lifecycle events (create, rotate, delete) appear in system journal within 1 second | quality |
