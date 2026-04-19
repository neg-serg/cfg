# Quickstart: pw-tools

## Prerequisites

- PipeWire running (`systemctl --user status pipewire`)
- `pw-cli`, `pw-link`, `pactl` in PATH (from `pipewire` package)
- `jq` in PATH
- `fzf` (optional, for enhanced selection in `move` command)

## Usage

```bash
# Interactive menu (default)
pw-tools

# Direct subcommands
pw-tools nodes     # List all PipeWire nodes
pw-tools links     # Show current port links
pw-tools graph     # Show audio topology
pw-tools move      # Move app streams between sinks (interactive)
pw-tools sinks     # Show RME virtual sink status
pw-tools restore   # Run pw-restore-links
pw-tools help      # Show usage
```

## Interactive Menu

```
=== PipeWire Audio Tools ===

  [n] Nodes        — List all PipeWire nodes
  [l] Links        — Show current port links
  [g] Graph        — Show audio topology
  [m] Move stream  — Move app streams between sinks
  [s] Sink status  — RME virtual sinks + channel mappings
  [r] Restore      — Run pw-restore-links
  [q] Quit

Choice: _
```

Press a single letter to execute the corresponding command. Output displays, then the menu returns automatically. Press `q` to quit.

## Testing

1. Run `pw-tools` — verify menu appears and accepts input
2. Press `l` — verify links display and menu returns without hanging
3. Press each menu option in sequence — verify no hangs or crashes
4. Press `q` — verify clean exit
5. Run `pw-tools nodes` directly — verify same output as from menu
6. Press Ctrl+C during menu — verify clean exit
