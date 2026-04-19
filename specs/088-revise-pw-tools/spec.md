# Feature Specification: Revise pw-tools Interactive CLI

**Feature Branch**: `088-revise-pw-tools`  
**Created**: 2026-04-13  
**Status**: Draft  
**Input**: User description: "pw-tools сейчас не совсем корректно работает в интерактивном режиме например попробуй прожать l, там потом ввод команд просто застревает, такое впечатление что код написан неаккуратно. Нужно вообще провести ему полную ревизию"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Reliable Interactive Menu (Priority: P1)

User launches `pw-tools` with no arguments and gets a responsive, stable interactive menu. After selecting any command (e.g., `l` for links), the output displays cleanly and the prompt returns immediately, ready for the next input without hanging or requiring extra keypresses.

**Why this priority**: This is the primary interface — if the menu is unreliable, the entire tool is unusable.

**Independent Test**: Launch `pw-tools`, press `l`, verify output appears and the next prompt accepts input immediately. Repeat for every menu option in sequence.

**Acceptance Scenarios**:

1. **Given** user runs `pw-tools` with no arguments, **When** the menu is displayed, **Then** the prompt accepts a single keypress and responds immediately
2. **Given** user is at the menu prompt, **When** they press `l` (links), **Then** link output displays and the menu prompt returns without hanging
3. **Given** user just ran any subcommand, **When** the next command is entered, **Then** input is accepted without requiring extra Enter keypresses or terminal resets
4. **Given** user presses `q`, **Then** the tool exits cleanly with return code 0

---

### User Story 2 - Subcommand Reliability (Priority: P2)

Each subcommand (`nodes`, `links`, `graph`, `move`, `sinks`, `restore`) works correctly when invoked directly from the command line and when invoked from the interactive menu. Commands handle missing dependencies, empty results, and PipeWire service unavailability gracefully with clear error messages.

**Why this priority**: Subcommands must be reliable both standalone and within the menu; failures in one should not crash the menu loop.

**Independent Test**: Run each subcommand directly (`pw-tools nodes`, `pw-tools links`, etc.) and verify correct output or clear error messages.

**Acceptance Scenarios**:

1. **Given** PipeWire is running normally, **When** user runs `pw-tools nodes`, **Then** a formatted table of nodes is displayed
2. **Given** no active links exist, **When** user runs `pw-tools links` or presses `l` in menu, **Then** a clear "no links" message is shown (not an error)
3. **Given** PipeWire is not running, **When** user runs any subcommand, **Then** a clear error message explains the issue and the tool exits with non-zero code
4. **Given** a subcommand fails inside the interactive menu, **When** the command completes, **Then** the menu loop continues without crashing

---

### User Story 3 - Stream Move Workflow (Priority: P3)

User can interactively move audio streams between RME virtual sinks using either fzf (if available) or a numbered text menu. The selection workflow is robust against special characters in stream names, empty selections, and invalid input.

**Why this priority**: This is the most complex interactive workflow; it depends on P1 and P2 being solid first.

**Independent Test**: With at least one audio stream playing, run `pw-tools move`, select a stream, select a target sink, verify the stream is moved.

**Acceptance Scenarios**:

1. **Given** fzf is installed and streams are playing, **When** user runs `pw-tools move`, **Then** fzf presents stream selection followed by sink selection
2. **Given** fzf is not installed, **When** user runs `pw-tools move`, **Then** a numbered text menu is presented for both stream and sink selection
3. **Given** user cancels at any selection step (empty input or fzf escape), **Then** the command exits cleanly without errors
4. **Given** stream names contain special characters, **When** user selects them, **Then** names are displayed and matched correctly

---

### Edge Cases

- PipeWire daemon is not running — all commands should fail gracefully with a clear message
- No RME virtual sinks exist — `sinks` and `move` commands should explain this clearly
- `pw-cli`, `pw-link`, or `pactl` not in PATH — clear dependency error on startup
- JSON output from `pactl -f json` is empty or malformed — `cmd_sinks` and `cmd_move` should handle without crashing
- Terminal is non-interactive (piped/redirected) — interactive menu should detect and fall back to help text
- User sends SIGINT (Ctrl+C) during menu — should exit cleanly, not print a stack trace
- `vared` or `read` receives EOF — should exit gracefully, not loop infinitely

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display a text-based menu with options for nodes, links, graph, move, sinks, restore, and quit when launched without arguments
- **FR-002**: System MUST accept single-character menu input (n, l, g, m, s, r, q) and respond without requiring an extra Enter keypress
- **FR-003**: System MUST return to the menu prompt immediately after any subcommand completes, with terminal state fully restored
- **FR-004**: System MUST NOT exit unexpectedly due to non-zero return codes from subcommands or helper functions
- **FR-005**: System MUST display clear error messages when PipeWire services are unavailable or required commands are missing from PATH
- **FR-006**: System MUST handle empty results (no links, no streams, no sinks) with informative messages rather than errors or blank output
- **FR-007**: System MUST support both fzf-based and text-based interactive selection for the `move` command
- **FR-008**: System MUST handle user cancellation at any interactive selection step without printing errors
- **FR-009**: System MUST handle stream names containing special characters (spaces, parentheses, unicode) correctly in display and selection
- **FR-010**: System MUST exit cleanly with return code 0 when user selects quit or sends SIGINT
- **FR-011**: System MUST detect non-interactive terminal and either display help text or exit with a usage message
- **FR-012**: All subcommands MUST work identically when invoked directly from the command line and when invoked from the interactive menu

### Key Entities

- **PipeWire Node**: An audio source or sink endpoint in the PipeWire graph, identified by numeric ID, with properties including name, description, and media class
- **PipeWire Link**: An active connection between an output port and an input port in the PipeWire graph
- **RME Virtual Sink**: A named PipeWire sink (rme-out-1-2 through rme-out-7-8) representing a physical output channel pair on the RME ADI-2/4 Pro SE interface
- **Stream Input**: An active audio stream (sink-input) routed to a specific sink, identified by index and associated with an application

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: User can cycle through all 6 menu commands (n, l, g, m, s, r) in sequence without any input hang, freeze, or terminal state corruption
- **SC-002**: Menu prompt responds to user input within 100ms of keypress (no perceptible delay)
- **SC-003**: All subcommands produce correct output or clear error messages in 100% of tested scenarios (normal operation, empty results, PipeWire unavailable)
- **SC-004**: The `move` command correctly handles stream names with special characters in both fzf and text menu modes without selection errors
- **SC-005**: SIGINT (Ctrl+C) at any point during interactive use exits cleanly without error output or terminal corruption
- **SC-006**: No silent failures — every error condition produces a human-readable error message on stderr
