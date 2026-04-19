# Tasks: Revise pw-tools Interactive CLI

**Input**: Design documents from `/specs/088-revise-pw-tools/`
**Prerequisites**: plan.md, spec.md, research.md, quickstart.md

**Tests**: No automated tests requested — manual testing with PipeWire running + shellcheck validation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story. Since this is a single-file rewrite, tasks within each phase target specific sections of `dotfiles/dot_local/bin/executable_pw-tools`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies) — not applicable for single-file sequential rewrite
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Single file: `dotfiles/dot_local/bin/executable_pw-tools`

---

## Phase 1: Foundation — Error Handling Framework

**Purpose**: Replace `ERR_EXIT`/`PIPE_FAIL` with explicit error handling; preserve `NO_UNSET`. This is the blocking prerequisite for all user stories — without it, subcommands will silently kill the script.

**Independent Test**: After this phase, running `pw-tools links` with no active links should print "No active links." and return to shell (not exit silently).

- [x] T001 Replace `setopt ERR_EXIT NO_UNSET PIPE_FAIL` with `setopt NO_UNSET` in `dotfiles/dot_local/bin/executable_pw-tools` (line 21)
- [x] T002 Add `|| true` guard to `node_prop()` pipeline (`grep -m1 | sed`) in `dotfiles/dot_local/bin/executable_pw-tools` (line 45)
- [x] T003 Add `|| true` guard to `available_rme_sinks()` `grep -qxF` pipeline in `dotfiles/dot_local/bin/executable_pw-tools` (line 54)
- [x] T004 Add `|| true` guard to `cmd_sinks()` `pactl info | awk` pipeline for default_sink detection in `dotfiles/dot_local/bin/executable_pw-tools` (line 119)
- [x] T005 Add `|| true` guard to `cmd_sinks()` `pactl list sinks short | awk | grep -qxF` pipeline in `dotfiles/dot_local/bin/executable_pw-tools` (line 129)
- [x] T006 Add `|| true` guard to `cmd_sinks()` `pactl -f json list sink-inputs | jq` pipeline in `dotfiles/dot_local/bin/executable_pw-tools` (lines 148-150)
- [x] T007 Add `|| true` guard to `cmd_move()` `pactl -f json list sink-inputs | jq` pipeline in `dotfiles/dot_local/bin/executable_pw-tools` (lines 188-189)
- [x] T008 Add `|| true` guard to `pw-cli list-objects Node | awk` pipeline in `cmd_nodes()` in `dotfiles/dot_local/bin/executable_pw-tools` (line 66)
- [x] T009 Add `|| true` guard to `pw-cli list-objects Link | awk` pipeline in `cmd_graph()` in `dotfiles/dot_local/bin/executable_pw-tools` (line 98)

**Checkpoint**: Foundation ready — all subcommands now handle empty results and non-zero exits without killing the script.

---

## Phase 2: User Story 1 — Reliable Interactive Menu (Priority: P1) 🎯 MVP

**Goal**: Replace `vared` with `read -k` for single-character menu input, add terminal state cleanup between menu cycles, add non-interactive terminal detection.

**Independent Test**: Launch `pw-tools`, press `l`, verify output appears and menu returns immediately. Repeat for all menu options. Press `q` to exit cleanly.

- [x] T010 [US1] Replace `vared -p "Choice: " -c key` with `read -k 1 key` in `interactive_loop()` in `dotfiles/dot_local/bin/executable_pw-tools` (line 268), add `print ""` after to consume the newline
- [x] T011 [US1] Add terminal reset (`print -n '\e[0m'` and `stty sane 2>/dev/null || true`) before `show_menu` call in `interactive_loop()` in `dotfiles/dot_local/bin/executable_pw-tools`
- [x] T012 [US1] Add non-interactive terminal detection at entry point — if `[[ ! -t 0 ]]`, print help text and exit in `dotfiles/dot_local/bin/executable_pw-tools`
- [x] T013 [US1] Add SIGINT trap (`trap 'print ""; return 0' INT`) in `interactive_loop()` for clean Ctrl+C exit in `dotfiles/dot_local/bin/executable_pw-tools`
- [x] T014 [US1] Add EOF handling — `read -k 1 key || return 0` to exit gracefully on EOF in `dotfiles/dot_local/bin/executable_pw-tools`

**Checkpoint**: Interactive menu is reliable — no hangs, clean exit on `q`/Ctrl+C/EOF, works in non-interactive terminal.

---

## Phase 3: User Story 2 — Subcommand Reliability (Priority: P2)

**Goal**: Ensure each subcommand handles errors gracefully within the menu loop (failures don't crash the loop) and produces clear messages for empty results and missing dependencies.

**Independent Test**: Run each subcommand directly (`pw-tools nodes`, `pw-tools links`, etc.) and verify correct output or clear error messages. Verify subcommand failure inside menu doesn't crash the loop.

- [x] T015 [US2] Wrap `cmd_nodes()` body in error handling — if `pw-cli list-objects Node` produces no output, print "No nodes found." in `dotfiles/dot_local/bin/executable_pw-tools`
- [x] T016 [US2] Wrap `cmd_links()` body — already handles empty output correctly; add `|| true` to `pw-link -l` call to prevent non-zero exit in `dotfiles/dot_local/bin/executable_pw-tools` (line 86)
- [x] T017 [US2] Wrap `cmd_graph()` body — if `pw-cli list-objects Link` produces no output, print "No active links in graph." in `dotfiles/dot_local/bin/executable_pw-tools`
- [x] T018 [US2] Wrap `cmd_sinks()` body — if `pactl info` fails (PipeWire not running), print clear error message in `dotfiles/dot_local/bin/executable_pw-tools`
- [x] T019 [US2] Wrap `cmd_restore()` — already handles missing `pw-restore-links`; add `|| true` to the `pw-restore-links` call so failure doesn't crash menu in `dotfiles/dot_local/bin/executable_pw-tools` (line 163)
- [x] T020 [US2] Add error isolation in `interactive_loop()` case statement — wrap each subcommand call so failures don't propagate (e.g., `cmd_nodes || true`) in `dotfiles/dot_local/bin/executable_pw-tools`

**Checkpoint**: All subcommands produce correct output or clear errors; subcommand failures inside menu don't crash the loop.

---

## Phase 4: User Story 3 — Stream Move Workflow (Priority: P3)

**Goal**: Rewrite `cmd_move()` to use line-number-based fzf selection (robust against special characters) and replace `vared` with `read` in text-mode fallback.

**Independent Test**: With a stream playing, run `pw-tools move`, select stream via fzf, select target sink, verify stream moved. Test with stream names containing parentheses/special chars.

- [x] T021 [US3] Rewrite fzf stream selection in `cmd_move()` to use numbered lines (`N|name` format), extract index via `${selection%%|*}` in `dotfiles/dot_local/bin/executable_pw-tools` (lines 198-210)
- [x] T022 [US3] Replace `vared -p "Stream number: " -c chosen_idx` with `read -p "Stream number: " chosen_idx` in text-mode fallback in `dotfiles/dot_local/bin/executable_pw-tools` (line 216)
- [x] T023 [US3] Replace `vared -p "Sink number: " -c sink_num` with `read -p "Sink number: " sink_num` in text-mode fallback in `dotfiles/dot_local/bin/executable_pw-tools` (line 237)
- [x] T024 [US3] Add input validation for `read` responses — check numeric, within range, re-prompt on invalid in `dotfiles/dot_local/bin/executable_pw-tools`
- [x] T025 [US3] Add `|| true` to `pactl move-sink-input` call so failure prints error but doesn't crash in `dotfiles/dot_local/bin/executable_pw-tools` (line 245)

**Checkpoint**: Stream move works with special characters in names, both fzf and text modes, with clean cancellation handling.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Final validation, shellcheck, and testing.

- [x] T026 Run `shellcheck -s zsh dotfiles/dot_local/bin/executable_pw-tools` and fix all warnings
- [x] T027 Run `zsh -n dotfiles/dot_local/bin/executable_pw-tools` to verify syntax
- [x] T028 Manual test: run `pw-tools` and cycle through all menu commands (n, l, g, m, s, r, q) verifying no hangs
- [x] T029 Manual test: run each subcommand directly (`pw-tools nodes`, `pw-tools links`, etc.) verifying output
- [x] T030 Manual test: press Ctrl+C during interactive menu, verify clean exit
- [x] T031 Run `just` (default target) to confirm Salt renders successfully per Constitution Principle VII

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Foundation)**: No dependencies — can start immediately. **BLOCKS all user stories.**
- **Phase 2 (US1)**: Depends on Phase 1 completion.
- **Phase 3 (US2)**: Depends on Phase 1 completion. Can start after Phase 2 or in parallel.
- **Phase 4 (US3)**: Depends on Phase 1 completion. Can start after Phase 2/3 or in parallel.
- **Phase 5 (Polish)**: Depends on all user story phases being complete.

### User Story Dependencies

- **US1 (P1)**: Depends on Foundation (Phase 1) — no dependencies on other stories
- **US2 (P2)**: Depends on Foundation (Phase 1) — independently testable from US1
- **US3 (P3)**: Depends on Foundation (Phase 1) — independently testable from US1/US2

### Within Each Phase

- Tasks within a phase are sequential (single file) — no parallel opportunities
- Foundation tasks (T001-T009) should be done in order (T001 first, then pipeline guards)
- Polish tasks (T026-T031) can be done in any order after implementation is complete

### Parallel Opportunities

- None within phases (single file). If multiple developers were available, Phases 2, 3, and 4 could proceed in parallel after Phase 1 completes, each working on their respective sections of the file (with merge coordination).

---

## Parallel Example: Not Applicable

This is a single-file rewrite. All tasks within a phase must be sequential. Parallel work is only possible across user story phases with careful section isolation and merge coordination.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Foundation (T001-T009)
2. Complete Phase 2: US1 — Reliable Interactive Menu (T010-T014)
3. **STOP and VALIDATE**: Test `pw-tools` interactively — press `l`, verify no hang, menu returns
4. Deploy if ready (`chezmoi apply` or copy to `~/.local/bin/pw-tools`)

### Incremental Delivery

1. Complete Phase 1 → Foundation ready (no more silent exits)
2. Add Phase 2 → Interactive menu works reliably (MVP!)
3. Add Phase 3 → All subcommands handle errors gracefully
4. Add Phase 4 → Stream move robust against special characters
5. Add Phase 5 → Shellcheck clean, manual tests pass

### Sequential Strategy (Recommended for Single Developer)

1. T001 → T009 (Foundation)
2. T010 → T014 (US1)
3. T015 → T020 (US2)
4. T021 → T025 (US3)
5. T026 → T031 (Polish)

---

## Notes

- No `[P]` tasks — single file means all tasks are sequential within their phase
- `[Story]` label maps task to specific user story for traceability
- Each user story is independently completable and testable
- Commit after each phase or logical group
- Stop at any checkpoint to validate story independently
- After all changes, verify the installed `~/.local/bin/pw-tools` is updated (chezmoi apply or manual copy)
