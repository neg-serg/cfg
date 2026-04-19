# Research: pw-tools Interactive CLI Revision

## Decision: Replace `vared` with `read -k` for menu input

**Rationale**: `vared` is zsh's variable editor — it launches a full line-editor session with its own terminal state management. After subcommand output (especially commands that manipulate terminal state like `pw-link`), `vared` can deadlock because it expects a clean terminal. `read -k` reads a single keystroke directly without line-editing overhead, which is exactly what a single-character menu needs.

**Alternatives considered**:
- `vared -h` (history mode) — still a line-editor, same terminal state issues
- `read -q` (quiet mode, reads one char) — similar to `read -k` but doesn't echo; `read -k` is more appropriate since we want the character visible
- `zle` (Zsh Line Editor) widget — overkill for a simple menu

## Decision: Remove `ERR_EXIT` and `PIPE_FAIL`, use explicit error handling

**Rationale**: `setopt ERR_EXIT` causes the script to exit on ANY non-zero return, including expected "not found" results from `grep -q`, `jq` on empty JSON, or `pactl` when no streams exist. These are normal operational states, not errors. `PIPE_FAIL` compounds this by killing the script when any element of a pipeline fails (e.g., `echo "" | grep -q "x"` — grep returns 1 on no match, killing the whole pipeline).

The fix is to remove both options and handle errors explicitly:
- Use `|| true` on pipelines where non-zero is expected
- Use `if ! command ...; then` for commands where failure should be handled
- Keep `NO_UNSET` — catching unset variables is still valuable

**Alternatives considered**:
- Keep `ERR_EXIT` but wrap every subcommand in `{ ... } || true` — verbose and error-prone; easy to miss one
- Use `set +e` before subcommands and `set -e` after — fragile in zsh, especially with functions

## Decision: Use `read -k 1` with `REPLY` for menu input

**Rationale**: `read -k 1` reads exactly one keystroke into `$REPLY`. It doesn't require Enter, doesn't launch a line editor, and doesn't depend on terminal state beyond basic character input. After each subcommand, a simple `print ""` provides visual separation before the next menu display.

Pattern:
```zsh
local key
while true; do
    show_menu
    read -k 1 key || return 0  # EOF → exit
    print ""  # consume the newline after keypress
    case "$key" in
        n) cmd_nodes ;;
        ...
    esac
done
```

## Decision: Terminal state cleanup between menu cycles

**Rationale**: Some subcommands (especially those involving `pw-link` or `pactl`) may leave terminal in a non-default state (e.g., raw mode, altered colors). Adding a lightweight terminal reset before each `show_menu` call ensures `read -k` always operates on a clean terminal.

Pattern:
```zsh
# Before show_menu in the loop:
print -n '\e[0m'  # reset colors/attributes
stty sane 2>/dev/null || true  # reset terminal settings
```

## Decision: `cmd_move` fzf selection via line numbers

**Rationale**: Current implementation matches fzf output back to array indices via string comparison, which breaks when stream names contain special characters (parentheses, pipes, etc.). The fix is to prefix each line with a number, let fzf select the full line, then extract the number.

Pattern:
```zsh
# Build numbered list
local -a menu_lines
for i in {1..${#input_ids[@]}}; do
    menu_lines+=("${i}|${input_names[$i]} (sink: ${input_sinks[$i]})")
done

# fzf selects a full line
local selection="${menu_lines[@]}" | fzf --header="Select stream to move"
# Extract the number before the pipe
chosen_idx="${selection%%|*}"
```

## Decision: Preserve `NO_UNSET`

**Rationale**: Catching unset variable references is still valuable for code quality. The bugs it catches (typos in variable names) outweigh the inconvenience. All `grep`/`jq` pipelines that might produce empty output will be guarded with `|| true` or `|| :` to prevent triggering `ERR_EXIT`-like behavior.

## Dependencies Verified

- `pw-cli`, `pw-link`, `pactl` — all ship with `pipewire` package (already installed via `states/data/packages.yaml`)
- `jq` — already installed (used by `cmd_sinks` and `cmd_move`)
- `fzf` — optional, already installed on this system
- `stty` — ships with coreutils, always available
