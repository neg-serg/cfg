# Neovim AI Setup

- Last updated: 2026-04-23
- Status: Active (Gemini AI integration removed)

## Current AI Integrations

### Completion
- **blink.cmp**: LSP-based completion with support for:
  - Language Server Protocol (LSP) sources
  - Buffer words
  - Path completion
  - Snippets (via LuaSnip)
- **No external AI completion providers** (Google Gemini AI removed)

### Removed Components
- **minuet-ai.nvim**: Plugin providing Gemini AI completions — removed
- **Gemini API configuration** — removed from `minuet.lua` and `blink.lua`
- **ProxyPilot rules for Gemini** — removed from `config.yaml`
- **OpenCode Gemini models** — removed from `opencode.json.tmpl`

## Configuration Files

- `dotfiles/dot_config/nvim/lua/plugins/completion/blink.lua` — main completion config
- `dotfiles/dot_config/nvim/lua/plugins/completion/lspconfig.lua` — LSP setup

## Adding New AI Providers

To add a new AI completion provider:

1. Install the plugin (e.g., `llm.nvim`, `codeium.nvim`, etc.)
2. Configure it in `blink.lua` under `sources`
3. Ensure any required API keys are stored in `gopass` and loaded via environment variables
4. Update this document

## Notes

- The `ai` state group (`just group ai`) includes `opencode` but no longer contains Gemini‑related states.
- AI‑related secret management (API keys) continues to use `gopass` with `age`/`Yubikey` backend.
- Future AI integrations should follow the same pattern: plugin → configuration → secret management.