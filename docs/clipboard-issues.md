# Clipboard Issues Analysis and Solutions

## Problem Summary
During the implementation of dynamic proxy switching for Zen Browser, multiple clipboard-related issues were discovered that affected clipboard functionality in Hyprland/Wayland environment.

## Root Causes Identified

### 1. Multiple Clipboard Manager Conflicts
- **vicinae-server** running as systemd user service (`vicinae.service`)
- **wl-paste --watch cliphist store** configured in Hyprland autostart
- **clipcat** (PID file exists but process dead)
- Multiple managers trying to intercept clipboard events caused deadlocks

### 2. Stuck Processes
- **4+ vicinae dmenu processes** hanging after menu invocations
- **clipcat daemon PID 498127** with stale PID file (`/run/user/1000/clipcatd.pid`)
- Processes not cleaning up properly after execution

### 3. Wayland/X11 Clipboard Synchronization Issues
- `wl-copy` writes to Wayland clipboard
- `wl-paste` reads from Wayland clipboard  
- X11 applications (some rofi/vicinae instances) use X11 clipboard
- No automatic synchronization between the two protocols

### 4. Temporary Directory Quotas
- `wl-copy` failed with "Disk quota exceeded" when writing to `/tmp`
- `/tmp` mount has per-user disk quotas
- Large clipboard content or frequent operations could exceed limits

## Symptoms Observed

1. **Clipboard menu (`Super+C`)** shows history but doesn't copy selected items
2. **Rofi-clipboard** displays entries but copy function fails
3. **Manual `wl-copy`/`wl-paste`** sometimes hangs/timeouts
4. **Clipboard history not updating** - `wl-paste --watch` not capturing new copies
5. **Hyprland keybindings** for clipboard not working reliably

## Solutions Implemented

### 1. Fallback Clipboard Functions
Added robust `copy_to_clipboard()` and `get_clipboard_content()` functions in:
- `~/.local/bin/clip`
- `~/.local/bin/rofi-clipboard`

These functions:
- Try Wayland (`wl-copy`/`wl-paste`) first with `TMPDIR=~/tmp` to avoid quota issues
- Fall back to X11 (`xclip`) if Wayland fails
- Handle both `clipboard` and `primary` X11 selections

### 2. Process Cleanup
- Killed hanging `vicinae dmenu` processes
- Removed stale clipcat PID file
- Ensured only one clipboard manager runs at a time

### 3. TMPDIR Workaround
```bash
mkdir -p ~/tmp
echo "text" | TMPDIR=~/tmp wl-copy --foreground
```

### 4. Unified Clipboard Scripts
- **Primary**: `~/.local/bin/clip` (vicinae + cliphist)
- **Alternative**: `~/.local/bin/rofi-clipboard` (rofi + cliphist)
- **Monitor**: `~/.local/bin/wayland-clipboard-monitor` (background watcher)

## Current Working State

✅ **Working:**
- `wl-copy` / `wl-paste` direct commands
- Clipboard history saving to `cliphist`
- `vicinae-server` receiving and indexing clipboard events
- `Super+C` menu showing history from `cliphist`

⚠️ **Remaining Issues:**
- Occasional process hangs need monitoring
- Need reliable autostart of clipboard manager
- Wayland/X11 sync could be more robust

## Prevention Recommendations

1. **Single Clipboard Manager**: Choose one - either `vicinae-server` OR `wl-paste --watch cliphist store`

2. **Process Monitor Script**:
```bash
#!/bin/bash
# Kill vicinae dmenu processes older than 30 seconds
ps aux | grep "vicinae dmenu" | grep -v grep | while read line; do
    pid=$(echo $line | awk '{print $2}')
    age=$(ps -o etimes= -p "$pid" 2>/dev/null)
    if [[ "$age" -gt 30 ]]; then
        kill -9 "$pid"
    fi
done
```

3. **Autostart Configuration** (`~/.config/hypr/autostart.conf`):
```bash
# Ensure clipboard manager starts
exec-once = wl-paste --watch cliphist store &
# OR
exec-once = systemctl --user start --no-block vicinae.service
```

4. **Regular Cleanup**:
```bash
# Clean stale PID files
rm -f /run/user/1000/clipcatd.pid
# Clear /tmp if quotas are hit
find /tmp -user $USER -type f -mtime +1 -delete
```

## Related Files

- `~/.local/bin/clip` - Main clipboard menu script
- `~/.local/bin/rofi-clipboard` - Alternative rofi-based menu
- `~/.config/hypr/autostart.conf` - Autostart configuration
- `~/.config/hypr/bindings.conf` - `Super+C` keybinding
- `~/.cache/cliphist/db` - Clipboard history database
- `/run/user/1000/clipcatd.pid` - Clipcat PID file (often stale)

## Debug Commands

```bash
# Check running processes
ps aux | grep -E "(vicinae|clipcat|cliphist|wl-paste)"

# Test clipboard functionality
echo "test" | wl-copy && sleep 0.5 && timeout 1 wl-paste

# Check cliphist entries
cliphist list | tail -5

# Check Wayland display
echo $WAYLAND_DISPLAY

# Check /tmp usage
df -h /tmp
```

---

*Document created: 2026-04-21*
*Related work: Dynamic proxy switching implementation, Zen Browser integration*