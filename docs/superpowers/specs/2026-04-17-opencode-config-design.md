# OpenCode Config Source-Of-Truth Design

## Goal

Stop `just apply` and `chezmoi apply --force` from overwriting the working OpenCode configuration with an outdated minimal config, while keeping the configuration reproducible and safe to store in git.

## Problem

Today, `~/.config/opencode/opencode.json` is managed by chezmoi and always re-rendered from `dotfiles/dot_config/opencode/opencode.json`.
The repo version is a minimal config, while the working config lives outside the repo in `~/dw/Telegram Desktop/opencode.json`.
This creates two sources of truth for the same target file, so every deploy reverts the live config back to the outdated repo version.

## Constraints

- Do not commit secrets or tokens into git.
- Keep `baseURL` set to `http://192.168.2.166:8317/v1`.
- Remove unused machine-specific fields rather than preserving them.
- Keep the final config managed by chezmoi so deploy remains reproducible.

## Current Findings

Safe to commit:

- plugin list
- model/provider definitions
- static `baseURL` at `http://192.168.2.166:8317/v1`
- MCP entries that do not contain secrets

Do not carry forward as-is:

- `/home/me/MyProjects/opencode-tg/skills`
- `/home/me/.config/opencode/youtube-cookies.txt`

These were found in the working config but are not currently used and are machine-specific.

No literal API keys or tokens were found in the working `opencode.json` snapshot that was inspected.

## Chosen Approach

Use a chezmoi template as the single source of truth:

- Replace `dotfiles/dot_config/opencode/opencode.json` with `dotfiles/dot_config/opencode/opencode.json.tmpl`.
- Move the useful working config into that template.
- Remove the unused `skills.paths` and `YTDLP_COOKIES_FILE` settings.
- Keep the configured `baseURL` in the template.
- Continue managing `~/.config/opencode/opencode.json` through chezmoi.

## Why This Approach

This keeps deploy reproducible, removes the split-brain config ownership problem, and leaves room for future secret-bearing fields to be expressed safely via template variables or environment references instead of literal values in git.

## Data Flow After Change

`dotfiles/dot_config/opencode/opencode.json.tmpl`
-> `chezmoi apply --force --source dotfiles`
-> `~/.config/opencode/opencode.json`

The file in `~/dw/Telegram Desktop/` stops being a hidden alternate source of truth and becomes only a historical reference.

## Validation Plan

After implementation, verify all of the following:

1. `chezmoi managed` still lists `.config/opencode/opencode.json`
2. rendered `~/.config/opencode/opencode.json` contains the expected provider/model/plugin configuration
3. rendered config does not contain removed unused path fields
4. the rendered config keeps `http://192.168.2.166:8317/v1`
5. re-running `chezmoi apply --force --source dotfiles` does not revert the config to the old minimal version

## Risks

- The working config is much larger than the current repo config, so the migration must avoid accidental loss of useful sections.
- If OpenCode has strict config parsing, malformed template output could break startup.

## Non-Goals

- No attempt to preserve unused path fields.
- No attempt to automatically sync from `~/dw/Telegram Desktop/opencode.json` in the future.
- No secret storage redesign beyond keeping secrets out of git.
