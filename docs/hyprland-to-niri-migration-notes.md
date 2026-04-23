# Hyprland → Niri Migration Notes

## Overview

This migration replaces the Hyprland Wayland compositor with Niri while preserving the scrollable‑tiling workflow, VRR (Variable Refresh Rate), and 10‑bit color support. The goal is minimal performance regression and operational transparency.

**Status:** In development (tested in windowed mode only).  
**Target:** CachyOS workstation with AMD GPU, DP‑2 monitor (3840×2160 @240 Hz, scale 2.0).  
**Salt state:** `states/desktop/niri.sls` installs Niri and dependencies; config is managed via `dotfiles/dot_config/niri/config.kdl`.

## Installed Packages

- `niri‑bin` (AUR) – Niri compositor
- `xwayland‑satellite` – XWayland support
- `xdg‑desktop‑portal‑gnome`, `xdg‑desktop‑portal‑gtk` – portal integration

**Optional:** `zen‑browser‑bin` (already present), `surfingkeys‑extension` (browser extension).

## Configuration Differences

### Monitor/Output

| Hyprland (`monitorv2`) | Niri (`output`) |
|------------------------|-----------------|
| `output = DP‑2`        | `output "DP‑2"` |
| `mode = 3840x2160@240` | `mode "3840x2160@240"` |
| `position = 0x0`       | `position x=0 y=0` |
| `scale = 2`            | `scale 2.0` |
| `vrr = 3`              | `variable‑refresh‑rate` |
| `bitdepth = 10`        | *Not configurable* (relies on DRM/KMS auto‑detection) |

Disabled monitor (`DP‑1`) is set to `off`.

### Layout and Visuals

| Hyprland | Niri |
|----------|------|
| `gaps_in = 0`, `gaps_out = 0` | `gaps 0` |
| `border_size = $border_size` | `border { off; width 1; … }` |
| `col.active_border = …` | `focus‑ring { active‑color "#7fc8ff"; … }` |
| `col.inactive_border = …` | `focus‑ring { inactive‑color "#505050"; … }` |
| `rounding = $rounding` | *No direct equivalent* (Niri does not support window rounding) |
| `blur { enabled = true; … }` | `shadow { off; … }` (no blur support) |
| `allow_tearing = true` | *No equivalent* (may increase input lag) |
| `direct_scanout = true` | *No equivalent* |

**Scrolling‑layout specifics:**

| Hyprland (`scrolling`) | Niri |
|------------------------|------|
| `column_width = 0.5` | `default‑column‑width { proportion 0.5; }` |
| `explicit_column_widths = 0.5, 1.0` | `preset‑column‑widths { proportion 0.5; proportion 1.0; }` |
| `fullscreen_on_one_column = true` | *No equivalent* |
| `follow_focus = true` | *No equivalent* |
| `follow_min_visible = 0.5` | *No equivalent* |
| `direction = right` | *No equivalent* (Niri always scrolls horizontally) |

### Input and Keyboard

| Hyprland (`input`) | Niri (`input`) |
|--------------------|----------------|
| `kb_layout = us,ru` | `keyboard { xkb { layout "us,ru"; } }` |
| `repeat_rate = 35` | `repeat‑rate 35` |
| `repeat_delay = 250` | `repeat‑delay 250` |
| `touchpad { tap = true; natural_scroll = true; }` | `touchpad { tap; natural‑scroll; }` |

### Key Bindings

| Hyprland | Niri |
|----------|------|
| `$M4 = SUPER` | `Mod` (Super on TTY, Alt in windowed mode) |
| `$C = Control` | `Ctrl` |
| `$S = Shift` | `Shift` |
| `bind = $M4, h, layoutmsg, focus l` | `Mod+H { focus‑column‑left; }` |
| `bind = $M4, j, layoutmsg, focus d` | `Mod+J { focus‑window‑down; }` |
| `bind = $M4, k, layoutmsg, focus u` | `Mod+K { focus‑window‑up; }` |
| `bind = $M4, l, layoutmsg, focus r` | `Mod+L { focus‑column‑right; }` |
| `bind = $M4, mouse_down, workspace, e+1` | `Mod+Page_Down { focus‑workspace‑down; }` |
| `bind = $M4, mouse_up, workspace, e-1` | `Mod+Page_Up { focus‑workspace‑up; }` |
| `bindl = $M4, Return, exec, kitty …` | `Mod+Return { spawn "kitty" "--single‑instance"; }` |
| `$menu = vicinae toggle` | `Mod+D { spawn "vicinae" "toggle"; }` |
| `$browser = zen‑browser` | `Mod+Shift+D { spawn "zen‑browser"; }` |

Screenshot binds (`Print`, `Ctrl+Print`, `Alt+Print`) are Niri defaults.

### Window Rules

| Hyprland (`match:class`) | Niri (`app‑id`) |
|--------------------------|-----------------|
| `match:class ^(zen\|floorp\|…)` | `match app‑id=r#"^zen$"#` etc. |
| `match:class ^(qt5ct\|wine\|…)` | `match app‑id=r#"^qt5ct$"#` etc. with `open‑floating true` |
| `match:title "^Picture‑in‑Picture$"` | `match title="^Picture‑in‑Picture$"` with `open‑floating true` |

## Missing Features

1. **Explicit `bitdepth` setting** – Niri relies on DRM/KMS auto‑detection. 10‑bit color may still work if the display and GPU support it, but cannot be forced.

2. **`allow_tearing`** – No equivalent in Niri. This may increase input lag in fast‑paced games.

3. **`direct_scanout`** – No equivalent. Potential performance impact for full‑screen applications.

4. **Scrolling‑layout refinements** – `fullscreen_on_one_column`, `follow_focus`, `follow_min_visible`, `direction` have no direct counterparts. Niri’s scrolling layout is simpler.

5. **Window rounding and blur** – Niri does not support rounded corners or background blur.

6. **Per‑window opacity** – Niri has no `active_opacity`/`inactive_opacity` settings.

## Testing Checklist

- [ ] **10‑bit color gradients** – Visual comparison with Hyprland (use `mpv --vo=gpu --gpu‑context=wayland --target‑peak=auto` with a test gradient).
- [ ] **VRR enabled** – Run `niri msg outputs` and verify `vrr‑capable: true`.
- [ ] **All key binds work** – Test navigation, workspace switching, application launchers.
- [ ] **Window rules apply correctly** – Verify browser windows match, utility windows float, PiP floats.
- [ ] **Focus‑history script** – Run `niri‑focus‑hist` in background, open two windows, trigger `--switch`.
- [ ] **Input lag subjective assessment** – Compare feel of mouse movement and window switching.
- [ ] **XWayland applications** – Launch X11 apps (e.g., `xeyes`) and verify they work.
- [ ] **Portal integration** – Screenshot, file‑picker dialogs.

## Rollback Procedure

If critical regression is observed:

1. Revert Salt pillar to keep Hyprland as primary desktop.
2. Remove Niri packages (`yay -Rns niri‑bin xwayland‑satellite`).
3. Restore Hyprland config (already in place).

The migration is designed to be non‑destructive: Hyprland state remains installed and configured.

## Known Issues

- **Address regex assumption** – The focus‑history script assumes Niri window addresses are hex strings prefixed with `0x`. This must be verified during windowed‑mode testing (Task 9) and updated if needed.
- **Missing `window‑opened` subscription** – The script subscribes only to `window‑closed` and `window‑focused` events, which is sufficient for focus tracking.
- **No unit tests for focus‑history script** – Contract tests have been added (`tests/test_niri_focus_hist.py`) but integration tests require a running Niri instance.

## Next Steps

1. **Task 9** – Install Niri temporarily and test in windowed mode.
2. **Task 10** – Decide on full switch or rollback based on test results.
3. If proceeding: update Salt pillar to enable Niri, optionally disable Hyprland.
4. If rolling back: keep Hyprland as primary and archive Niri config for future evaluation.