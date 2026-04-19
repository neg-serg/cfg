# Implementation Plan: Revise pw-tools Interactive CLI

**Branch**: `088-revise-pw-tools` | **Date**: 2026-04-13 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/088-revise-pw-tools/spec.md`

## Summary

Full revision of `pw-tools` — a 305-line zsh interactive CLI for PipeWire audio routing. The current script suffers from interactive input hangs (especially after `l`/links), fragile error handling (`ERR_EXIT` + `PIPE_FAIL` causing silent exits), and inconsistent terminal state management. The rewrite replaces `vared` with `read -k` for single-key input, removes `ERR_EXIT`/`PIPE_FAIL` in favor of explicit error handling per command, and adds proper terminal state cleanup between menu cycles.

## Technical Context

**Language/Version**: Zsh (system default, `#!/usr/bin/env zsh`)  
**Primary Dependencies**: `pw-cli`, `pw-link`, `pactl` (from `pipewire` package), `jq` (JSON parsing), `fzf` (optional, for fuzzy selection)  
**Storage**: N/A (runtime state only, no persistence)  
**Testing**: Manual testing with PipeWire running; shellcheck validation  
**Target Platform**: Linux (CachyOS/Arch), PipeWire ≥1.0  
**Project Type**: CLI tool (single script)  
**Performance Goals**: Menu responds within 100ms of keypress; subcommands complete in <2s for normal output  
**Constraints**: Must preserve existing subcommand interface (`pw-tools nodes`, `pw-tools links`, etc.) and RME virtual sink definitions  
**Scale/Scope**: Single file — `dotfiles/dot_local/bin/executable_pw-tools` (~305 lines → ~350 lines after revision)

### Root Causes Identified

1. **`ERR_EXIT` + `PIPE_FAIL`**: Any non-zero exit in a subcommand (e.g., `grep -q` finding no links, `jq` on empty JSON) kills the entire script. This is the primary cause of the "press `l` and it hangs/exits" behavior.
2. **`vared` terminal state**: `vared` is a full line-editor that depends on clean terminal state. After subcommand output (especially from `pw-link -l` which may leave terminal in an inconsistent state), `vared` can deadlock or require extra Enter.
3. **No error isolation in menu loop**: Subcommand failures propagate out of the `while` loop instead of being caught.
4. **`cmd_move` fragile fzf matching**: String-based index matching breaks with special characters in stream names.

### Fixes

1. Replace `setopt ERR_EXIT NO_UNSET PIPE_FAIL` with explicit error handling per subcommand
2. Replace `vared` with `read -k` for single-character menu input (FR-002)
3. Add `|| true` guards around all `grep`, `jq`, and `awk` pipelines
4. Add terminal reset (`stty sane` or `print -n '\e[0m'`) between menu cycles
5. Rewrite `cmd_move` fzf selection to use line-number-based matching instead of string comparison

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Idempotency | N/A | No Salt states modified; this is a CLI tool revision |
| II. Network Resilience | N/A | No network access |
| III. Secrets Isolation | N/A | No secrets involved |
| IV. Macro-First | N/A | Not using macros; this is a standalone CLI script, not Salt infrastructure |
| V. Minimal Change | PASS | Scope limited to fixing interactive reliability and error handling; no new features |
| VI. Convention Adherence | PASS | `#!/usr/bin/env zsh` shebang preserved; zsh reserved variable names respected |
| VII. Verification Gate | PASS | Will run `just` (default target) to confirm Salt renders successfully |
| VIII. CI Gate | PASS | Will run CI before marking complete |

## Project Structure

### Documentation (this feature)

```text
specs/088-revise-pw-tools/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # N/A (no data model)
├── quickstart.md        # Phase 1 output
├── contracts/           # N/A (internal CLI tool)
└── tasks.md             # Phase 2 output (not created by /speckit.plan)
```

### Source Code (repository root)

```text
dotfiles/dot_local/bin/executable_pw-tools    # Revised script (single file)
```

**Structure Decision**: Single-file change. The script lives in the dotfiles tree managed by chezmoi (`executable_` prefix tells chezmoi to set the executable bit). No new files, no new directories — just a rewrite of the existing script.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations. This is a single-file revision within an existing script.
