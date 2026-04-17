# OpenCode Config Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move OpenCode config ownership to a single chezmoi template so deploy no longer overwrites the working config with the old minimal one.

**Architecture:** Replace the static chezmoi-managed `opencode.json` with a template generated from the validated working configuration. Keep only safe, required settings; remove unused machine-specific fields; validate both repository contracts and rendered live output.

**Tech Stack:** chezmoi, JSON config, Just/Salt deploy flow, pytest contract tests

---

### Task 1: Replace the static OpenCode config with a chezmoi template

**Files:**
- Create: `dotfiles/dot_config/opencode/opencode.json.tmpl`
- Delete: `dotfiles/dot_config/opencode/opencode.json`
- Test: `tests/test_render_contracts.py`

- [ ] **Step 1: Write the failing test**

Add a render-contract assertion that the chezmoi source contains `opencode.json.tmpl` and no longer relies on the old static `opencode.json`.

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_render_contracts.py -q`
Expected: FAIL because the test still expects the old state.

- [ ] **Step 3: Write minimal implementation**

Create `dotfiles/dot_config/opencode/opencode.json.tmpl` from the approved working config, keep `http://192.168.2.166:8317/v1`, remove unused `skills.paths` and `YTDLP_COOKIES_FILE`, and delete the obsolete static file.

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_render_contracts.py -q`
Expected: PASS.

### Task 2: Validate rendered live output and deploy safety

**Files:**
- Modify: `tests/test_render_contracts.py`
- Test: `tests/test_render_contracts.py`

- [ ] **Step 1: Write the failing test**

Add assertions that the rendered target should keep the configured `baseURL` and should not include the removed machine-specific path fields.

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_render_contracts.py -q`
Expected: FAIL before the render is refreshed.

- [ ] **Step 3: Write minimal implementation**

Apply chezmoi from `dotfiles`, render the new target config, and adjust the contract test to match the intended managed state.

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_render_contracts.py -q`
Expected: PASS.

- [ ] **Step 5: Verify rendered target manually**

Run: `chezmoi apply --force --source dotfiles && chezmoi managed | rg "\.config/opencode/opencode.json" && rg -n "192\.168\.2\.166:8317/v1|/home/me/MyProjects/opencode-tg/skills|YTDLP_COOKIES_FILE" ~/.config/opencode/opencode.json`
Expected: managed target present, `baseURL` present, removed path fields absent.
