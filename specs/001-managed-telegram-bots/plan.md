# Implementation Plan: Managed Telegram Bots (Bot API 9.6)

**Branch**: `001-managed-telegram-bots`
**Date**: 2026-05-03
**Spec**: specs/001-managed-telegram-bots/spec.md

## Input Description

Implement a manager bot using Telegram Bot API 9.6 Managed Bots feature that programmatically creates and controls child bots without BotFather. Users click a button → Telegram creates a bot → manager bot receives the token and can deploy/control it. This replaces manual BotFather token creation with automated multi-bot orchestration managed via Salt.

---

## Summary

A single Python Bot API bot runs as a systemd user service on host `telfir`. It presents a `request_managed_bot` button in private chat. When a user creates a bot, the manager stores the child bot's identity and token in gopass (for Salt) and in a local YAML registry (for `/bots` listing). Owner commands (`/bots`, `/rotate_token`) are gated on allowlisted Telegram UIDs. The manager bot replaces the need for manual BotFather token provisioning.

---

## Technical Context

| Field | Value |
|-------|-------|
| language_version | Python 3.11+ |
| primary_dependencies | `python-telegram-bot` (AUR), `PyYAML` |
| storage | YAML registry file (`~/.config/opencode/managed-bots.yaml`), gopass for tokens |
| testing | pytest |
| target_platform | Linux (CachyOS/Arch), systemd user service |
| project_type | CLI daemon (bot runner) |
| performance_goals | Bot responds within 2s; token storage within 1s of creation |
| constraints | SOCKS5 proxy for Telegram API access; single manager bot per token |
| scale_scope | ~10 managed bots per manager |

---

## Constitution Check

| Gate | Passed | Notes |
|------|--------|-------|
| I. Idempotency | Yes | Salt state uses `unless:` on package install, `creates:` on file deploy, service enabled via `module.run` |
| II. Network Resilience | Yes | Bot API calls wrapped with retry; Salt state uses standard `retry:` from `_imports.jinja` |
| III. Secrets Isolation | Yes | Manager bot token stored in `api/opencode-telegram-bot` (existing); child bot tokens stored in `telegram/managed-bots/<username>` via gopass; Salt states resolve via `gopass show` |
| IV. Macro-First | Yes | Salt state uses `_macros_pkg.jinja` for package install, `_macros_config.jinja` for config deploy |
| V. Minimal Change | Yes | One new `.sls` file, one new script, one new systemd unit; no modifications to existing states beyond `system_description.sls` include |
| VI. Convention Adherence | Yes | State ID: `managed_bots_config`; commit style: `[telegram] ...`; script: `#!/usr/bin/env zsh` for helper, Python for bot |
| VII. Verification Gate | Yes | `just` (default target) runs after Salt state changes |

---

## Project Structure

### Docs Layout

```
specs/001-managed-telegram-bots/
├── plan.yaml               # this file
├── research.yaml            # Phase 0
├── data-model.yaml          # Phase 1
├── quickstart.yaml          # Phase 1
├── contracts/               # Phase 1: bot command API
│   └── bot-commands.yaml    # /start, /bots, /rotate_token contract
└── tasks.yaml               # Phase 2 (speckit.tasks)
```

### Source Layout

```
states/
├── managed_bots.sls               # Salt state: package, config, secrets, service
├── data/
│   └── telegram_managed_bots.yaml  # allowlist UIDs, owner UIDs, config refs
├── configs/
│   └── managed-bots.yaml.j2        # Jinja2 config template
├── scripts/
│   └── managed-bots-runner.py      # Python Bot API bot daemon
└── units/user/
    └── managed-bots.service        # systemd user unit

docs/
└── managed-bots-ops.md             # operator guide

tests/
└── test_managed_bots.py            # unit + contract tests
```

**Decision rationale**: Single-project layout matching existing Salt repo conventions. All bot logic in a single Python script (consistent with `telethon-bridge.py`). Config in `configs/`, data in `data/`, unit in `units/user/`.

---

## Complexity Tracking

No violations. All gates pass.
