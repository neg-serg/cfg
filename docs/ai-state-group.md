# AI State Group

- Last updated: 2026-04-23
- Group name: `ai`
- Command: `just group ai`
- Run time: ~0.4 seconds

## Included States

| State | Purpose |
|-------|---------|
| `ollama` | Local LLM server (Ollama) |
| `llama_embed` | Embedding models for RAG |
| `nanoclaw` | Code navigation and analysis |
| `opencode` | AI‑assisted development (OpenCode) |
| `image_gen` | Image generation (Stable Diffusion, Flux) — feature‑gated |

## Changes

- **Google Gemini AI integration removed** (2026‑04‑23)
  - Removed `minuet-ai.nvim` plugin from Neovim
  - Removed Gemini API configuration from `blink.lua`
  - Removed Gemini rules from ProxyPilot (`config.yaml`)
  - Removed Gemini models from OpenCode (`opencode.json.tmpl`)
  - Updated agent scripts and tests

## Secret Management

AI‑related secrets (API keys, access tokens) are stored in `gopass` with `age`/`Yubikey` backend.

- `ai/ollama/api_key` (if required)
- `ai/opencode/...`
- `ai/image_gen/...`

## Applying the Group

```bash
just group ai
```

This applies all AI‑related states in the correct order.

## Adding New AI States

1. Create the state in `states/` (e.g., `states/new_ai.sls`)
2. Add it to `states/group/ai.sls`
3. Update this document
4. Ensure any secrets are integrated with `gopass`