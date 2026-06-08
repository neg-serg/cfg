border_size = 1

col_border_active_base = "rgba(00285981)"
col_border_inactive = "rgba(00000000)"

rounding = 0
rounding_power = 0

opacity_active = 1.0
opacity_inactive = 1.0

shadow_color = 0xaa005faf

blur_size = 9
blur_passes = 2
blur_vibrancy = 0

daw = "^(REAPER|Renoise)$"
dev = "^nwim$"
doc = "^org%.pwmt%.zathura$"
dw = "^org%.nicotine_plus%.Nicotine$"
games = "^(steam|Steam|steam_app_%d+|gamescope)$"
im = "^im%.riot%.Riot$"
keyboard = "^(Bazecor|wootility-lekker|Vial|via)$"
notes = "^Obsidian$"
obs = "^obs$"
patchbay = "^(qpwgraph|Carla2)$"
pic = "^swayimg$"
remote = "^(Vmware-view|xfreerdp|remmina|org%.remmina%.Remmina)$"
term = "^term$"
vid = "^mpv$"
vm = "^(%.virt-manager-wrapped|qemu-system-x86_64|Qemu-system-x86_64)$"
web_browsers = "^(zen|floorp|one%.ablaze%.floorp|floorpdeveloperedition|firefox" ..
    "(?:[ -]?developer[ -]?edition)?|org%.mozilla%.firefox" ..
    "(?:[ -]?developer[ -]?edition)?|librewolf|io%.gitlab%.librewolf-community" ..
    "|chromium(?:-browser)?|org%.chromium%.chromium|ungoogled-chromium(?:-dev)?" ..
    "|brave(?:-browser(?:-(?:beta|nightly))?)?|com%.brave%.browser" ..
    "|vivaldi(?:-(?:stable|snapshot))?|opera(?:-(?:beta|developer))?" ..
    "|thorium-browser|com%.thorium%.thorium|mullvad-browser" ..
    "|com%.mullvad%.browser|palemoon|net%.palemoon%.palemoon" ..
    "|qutebrowser|org%.qutebrowser%.qutebrowser|falkon|org%.kde%.falkon" ..
    "|midori|epiphany|org%.gnome%.epiphany" ..
    "|google-chrome(?:-(?:stable|beta|unstable))?|com%.google%.chrome" ..
    "|microsoft-edge(?:-(?:beta|dev|canary))?|com%.microsoft%.edge)$"
wine = "^com%.usebottles%.bottles$"
winboat = "^(winboat|WinBoat)$"

hl.env("GDK_SCALE", "2")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_ENABLE_HIGHDPI_SCALING", "1")
hl.env("XCURSOR_SIZE", "23")

hl.env("GDK_BACKEND", "wayland")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("CLUTTER_BACKEND", "wayland")

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")

hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QML_XHR_ALLOW_FILE_READ", "1")

hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
hl.env("QT_STYLE_OVERRIDE", "kvantum")
hl.env("QT_XDG_DESKTOP_PORTAL", "1")
hl.env("GTK_USE_PORTAL", "1")

hl.env("GTK_THEME", "Flight-Dark-GTK")
hl.env("XCURSOR_THEME", "Alkano-aio")

local terminal = "kitty --single-instance --class term"
local clipboard_manager = "zsh -c 'pkill \"wl-paste --watch cliphist store\"; wl-paste --watch cliphist store'"

hl.on("hyprland.start", function()
  hl.exec_cmd("~/.local/bin/unlock")
  hl.exec_cmd("dunst")
  hl.exec_cmd("hyprpm reload")
  hl.exec_cmd("systemctl --user start --no-block hyprpolkitagent.service")
  hl.exec_cmd("systemctl --user restart --no-block hyprscratch.service")
  hl.exec_cmd("systemctl --user restart --no-block wl.service || wl-daemon &")
  hl.exec_cmd(terminal)
  hl.exec_cmd("swayosd-server")
  hl.exec_cmd(clipboard_manager)
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE && systemctl --user restart --no-block quickshell.service")
  hl.exec_cmd("nicotine")
  hl.exec_cmd("~/.local/bin/hypr-focus-hist")
  hl.exec_cmd("~/.local/bin/gpg-warmup")
  hl.exec_cmd("systemctl --user start --no-block vicinae.service")
  hl.exec_cmd("systemctl --user start --no-block surfingkeys-server.service")
  hl.exec_cmd("qs -c overview")
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE QT_XDG_DESKTOP_PORTAL GTK_THEME QT_STYLE_OVERRIDE QT_QPA_PLATFORMTHEME")
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE QT_XDG_DESKTOP_PORTAL GTK_THEME QT_STYLE_OVERRIDE QT_QPA_PLATFORMTHEME")
end)

hl.window_rule({
  name = "nm-connection-editor",
  match = { class = "^(nm-connection-editor)$" },
  float = true,
  size = "45% 45%",
  center = true,
  tag = "nm-connection-editor",
})

hl.window_rule({
  name = "pip-float",
  match = { title = "^([Pp]icture[- ]?[Ii]n[- ]?[Pp]icture)(.*)$" },
  float = true,
  keep_aspect_ratio = true,
  move = "73% 72%",
  size = "25% 25%",
  pin = true,
  tag = "pip",
})

hl.window_rule({
  name = "file-dialog",
  match = { title = "^(Open File|Select a File|Choose wallpaper|Open Folder|Save As|Library|File Upload)(.*)$" },
  center = true,
  float = true,
  tag = "file-dialog",
})

hl.window_rule({
  name = "yazi-chooser",
  match = { class = "^(yazi-chooser)$" },
  float = true,
  center = true,
  size = "65% 75%",
  tag = "yazi-chooser",
})

hl.window_rule({
  name = "telegram-wrapped",
  match = { class = "^(.telegram-desktop-wrapped)$" },
  center = true,
  float = true,
  tag = "telegram",
})

hl.window_rule({
  name = "telegram-org",
  match = { class = "^(org%.telegram%.desktop)$" },
  float = true,
  tag = "telegram",
})

hl.window_rule({
  name = "utility-float",
  match = { class = "^(qt5ct|wine|steamwebhelper|sun-awt-X11-XFramePeer|install4j-roomeqwizard-RoomEQ_Wizard|xdg-desktop-portal-gtk)$" },
  float = true,
  tag = "utility",
})

hl.window_rule({
  name = "mpd-add",
  match = { class = "^(mpd-add)(.*)$" },
  float = true,
  size = "35% 35%",
  move = "64% 59%",
  tag = "mpd-add",
})

hl.window_rule({
  name = "wine-exe",
  match = { title = ".*%.exe" },
  immediate = true,
  tag = "wine-exe",
})

hl.window_rule({
  name = "steam-app-gaming",
  match = { class = "^(steam_app_.*)$" },
  immediate = true,
  render_unfocused = true,
  no_blur = true,
  no_anim = true,
  tag = "steam-app",
})

hl.window_rule({
  name = "vicinae-float",
  match = { class = "^(vicinae)$" },
  float = true,
  no_anim = true,
  move = "575 408",
  stay_focused = true,
})

hl.window_rule({
  name = "fix-xwayland-drags",
  match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
  no_focus = true,
})

hl.window_rule({
  name = "xwayland-no-blur",
  match = { xwayland = true },
  no_blur = true,
  tag = "xwayland",
})

hl.window_rule({
  name = "pinentry",
  match = { class = "^(pinentry-)(.*)$" },
  stay_focused = true,
  tag = "pinentry",
})

hl.window_rule({
  name = "file-manager-opacity",
  match = { class = "^(nemo)$" },
  opacity = 0.92,
  tag = "file-manager",
})

hl.window_rule({
  name = "xwaylandvideobridge",
  match = { class = "^(xwaylandvideobridge)$" },
  opacity = 0.0,
  no_anim = true,
  no_initial_focus = true,
  max_size = "1 1",
  no_blur = true,
  tag = "xwaylandvideobridge",
})

hl.window_rule({
  name = "swayimg-float",
  match = { class = "^(swayimg)$" },
  float = true,
  size = "1200 800",
  move = "100 100",
})

hl.window_rule({
  name = "winboat-float",
  match = { class = winboat },
  float = true,
})

-- Scratchpad classes (float)
local scratchpad_classes = {
  "^(KotatogramDesktop|Skype|Slack|TelegramDesktop|org%.telegram%.desktop|zoom)$",
  "^(ncmpcpp|rmpc|music)$",
  "^(mixer|pipemixer)$",
  "^(torrment)$",
  "^(teardown)$",
}

for i, cls in ipairs(scratchpad_classes) do
  hl.window_rule({
    name = "scratchpad-float-" .. i,
    match = { class = cls },
    float = true,
  })
end

-- Layer rules
local layer_blur_alpha = {
  "gtk-layer-shell", "launcher", "notifications",
  "bar[0-9]*", "qs-panel",
  "barcorner.*", "dock[0-9]*",
  "overview[0-9]*", "cheatsheet[0-9]*",
  "sideright[0-9]*", "sideleft[0-9]*",
  "indicator.*", "osk[0-9]*",
}

for _, ns in ipairs(layer_blur_alpha) do
  hl.layer_rule({
    name = "blur-" .. ns:gsub("[^%w]", "_"),
    match = { namespace = ns },
    blur = true,
    ignore_alpha = 1.0,
  })
end

local layer_blur_only = {
  "logout_dialog", "session[0-9]*",
}

for _, ns in ipairs(layer_blur_only) do
  hl.layer_rule({
    name = "blur-" .. ns:gsub("[^%w]", "_"),
    match = { namespace = ns },
    blur = true,
  })
end

local layer_no_anim = { "selection", "indicator.*", "hyprpicker", "qs-panel" }

for _, ns in ipairs(layer_no_anim) do
  hl.layer_rule({
    name = "noanim-" .. ns:gsub("[^%w]", "_"),
    match = { namespace = ns },
    no_anim = true,
  })
end

hl.layer_rule({
  name = "anim-sideleft",
  match = { namespace = "sideleft.*" },
  animation = "slide left",
})

hl.layer_rule({
  name = "anim-sideright",
  match = { namespace = "sideright.*" },
  animation = "slide right",
})

local M4 = "SUPER"
local M1 = "Alt"
local C = "Control"
local SHIFT = "Shift"

hl.bind(M4 .. "+S", hl.dsp.exec_cmd("hyprctl switchxkblayout current next"))

hl.bind(M1 .. "+Tab", hl.dsp.exec_cmd("~/.local/bin/hypr-focus-hist --switch"))
hl.bind(M4 .. "+Tab", hl.dsp.exec_cmd("qs ipc -c overview call overview toggle"))
hl.bind(M4 .. "+" .. C .. "+backslash", hl.dsp.window.resize({ x = 640, y = 480 }))
hl.bind(M4 .. "+" .. SHIFT .. "+Tab", hl.dsp.window.cycle_next({ next = true }))
hl.bind(M4 .. "+" .. SHIFT .. "+Tab", hl.dsp.window.bring_to_top())

hl.bind(M4 .. "+c", hl.dsp.exec_cmd("~/.local/bin/clip"))
hl.bind(M4 .. "+Escape", hl.dsp.window.close())
hl.bind(M4 .. "+r", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

hl.bind(M4 .. "+equal", hl.dsp.layout("colresize +conf"))
hl.bind(M4 .. "+" .. SHIFT .. "+equal", hl.dsp.layout("fit all"))
hl.bind(M4 .. "+h", hl.dsp.layout("focus l"))
hl.bind(M4 .. "+j", hl.dsp.layout("focus d"))
hl.bind(M4 .. "+k", hl.dsp.layout("focus u"))
hl.bind(M4 .. "+l", hl.dsp.layout("focus r"))

hl.bind(M4 .. "+" .. SHIFT .. "+h", hl.dsp.window.move({ direction = "l" }))
hl.bind(M4 .. "+" .. SHIFT .. "+j", hl.dsp.window.move({ direction = "d" }))
hl.bind(M4 .. "+" .. SHIFT .. "+k", hl.dsp.window.move({ direction = "u" }))
hl.bind(M4 .. "+" .. SHIFT .. "+l", hl.dsp.window.move({ direction = "r" }))

hl.bind(M4 .. "+Return", hl.dsp.exec_cmd("kitty --single-instance"), { locked = true })
hl.bind(M4 .. "+p", hl.dsp.exec_cmd("pkill rofi || ~/.local/bin/rofi-pass-2col"), { locked = true })
hl.bind(M4 .. "+" .. SHIFT .. "+p", hl.dsp.exec_cmd("pkill rofi || tessen"), { locked = true })

hl.bind(M4 .. "+mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(M4 .. "+mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(M4 .. "+mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(M4 .. "+mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Scratchpad app toggles
hl.bind(M4 .. "+d", hl.dsp.exec_cmd("~/.local/bin/scratchpad-toggle teardown"))
hl.bind(M4 .. "+e", hl.dsp.exec_cmd("~/.local/bin/scratchpad-toggle im"))
hl.bind(M4 .. "+f", hl.dsp.exec_cmd("~/.local/bin/scratchpad-toggle music"))
hl.bind(M4 .. "+t", hl.dsp.exec_cmd("~/.local/bin/scratchpad-toggle torrment"))
hl.bind(M4 .. "+" .. C .. "+p", hl.dsp.exec_cmd("~/.local/bin/scratchpad-toggle mixer"))

-- App launchers
local function raise(cmd, match, fallback)
  return "raise --match " .. match .. " --launch " .. fallback
end

hl.bind(M4 .. "+w", hl.dsp.exec_cmd(raise("browser",
  '"class:regex=(?i)^(zen|floorp|one%.ablaze%.floorp|floorpdeveloperedition|firefox' ..
  '(?:[ -]?developer[ -]?edition)?|org%.mozilla%.firefox' ..
  '(?:[ -]?developer[ -]?edition)?|librewolf|io%.gitlab%.librewolf-community' ..
  '|chromium(?:-browser)?|org%.chromium%.chromium|ungoogled-chromium(?:-dev)?' ..
  '|brave(?:-browser(?:-(?:beta|nightly))?)?|com%.brave%.browser' ..
  '|vivaldi(?:-(?:stable|snapshot))?|opera(?:-(?:beta|developer))?' ..
  '|thorium-browser|com%.thorium%.thorium|mullvad-browser' ..
  '|com%.mullvad%.browser|palemoon|net%.palemoon%.palemoon' ..
  '|qutebrowser|org%.qutebrowser%.qutebrowser|falkon|org%.kde%.falkon' ..
  '|midori|epiphany|org%.gnome%.epiphany' ..
  '|google-chrome(?:-(?:stable|beta|unstable))?|com%.google%.chrome' ..
  '|microsoft-edge(?:-(?:beta|dev|canary))?|com%.microsoft%.edge)$"',
  "zen-browser")))

hl.bind(M4 .. "+" .. SHIFT .. "+w", hl.dsp.exec_cmd(
  'raise --match "class:regex=^(floorp|one%.ablaze%.floorp|floorpdeveloperedition)$" --launch floorp'))
hl.bind(M4 .. "+x", hl.dsp.exec_cmd(
  'raise --match "class:regex=^term$" --launch "kitty --single-instance --class term"'))
hl.bind(M4 .. "+q", hl.dsp.exec_cmd(
  'raise --match "class:regex=^nwim$" --launch "kitty --single-instance --class nwim -e v"'))
hl.bind(M4 .. "+b", hl.dsp.exec_cmd(
  'raise --match "class:regex=^mpv$" --launch "~/.local/bin/pl video"'))
hl.bind(M4 .. "+" .. C .. "+c", hl.dsp.exec_cmd(
  'raise --match "class:regex=^swayimg$" --launch "swayimg ~/dw"'))
hl.bind(M4 .. "+" .. SHIFT .. "+c", hl.dsp.exec_cmd("wl random ~/pic/wl"))
hl.bind(M4 .. "+" .. C .. "+v", hl.dsp.exec_cmd(
  'raise --match "class:regex=^Bazecor$" --launch "bazecor"'))
hl.bind(M4 .. "+g", hl.dsp.exec_cmd(
  'raise --match "class:regex=^(steam|steam_app.*|gamescope)$" --launch steam'))
hl.bind(M4 .. "+" .. SHIFT .. "+g", hl.dsp.exec_cmd(
  'raise --match "class:regex=^(lutris|net%.lutris%.Lutris)$" --launch "flatpak run net.lutris.Lutris"'))
hl.bind(M4 .. "+o", hl.dsp.exec_cmd(
  'raise --match "class:regex=^org%.pwmt%.zathura$" --launch "zathura"'))
hl.bind(M4 .. "+" .. C .. "+o", hl.dsp.exec_cmd(
  'raise --match "class:regex=^(obs|com%.obsproject%.Studio)$" --launch "obs"'))
hl.bind(M4 .. "+" .. C .. "+n", hl.dsp.exec_cmd(
  'raise --match "class:regex=^(Obsidian|md%.obsidian%.Obsidian)$" --launch "flatpak run md.obsidian.Obsidian"'))

-- Media keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("swayosd-client --output-volume +5"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("swayosd-client --output-volume -5"), { repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), { repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("swayosd-client --input-volume mute-toggle"), { repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("swayosd-client --brightness +10"), { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness -10"), { repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind(M4 .. "+" .. SHIFT .. "+w", hl.dsp.exec_cmd("~/.local/bin/pl cmd play-pause"), { locked = true })
hl.bind(M4 .. "+comma", hl.dsp.exec_cmd("~/.local/bin/pl cmd previous"), { locked = true })
hl.bind(M4 .. "+period", hl.dsp.exec_cmd("~/.local/bin/pl cmd next"), { locked = true })
hl.bind(M4 .. "+" .. SHIFT .. "+i", hl.dsp.exec_cmd("~/.local/bin/pl vol mute"), { locked = true })
hl.bind(M4 .. "+" .. SHIFT .. "+o", hl.dsp.exec_cmd("~/.local/bin/pl vol unmute"), { locked = true })
hl.bind(M4 .. "+m", hl.dsp.exec_cmd("~/.local/bin/music-rename current"), { locked = true })

-- Misc
hl.bind(M1 .. "+g", hl.dsp.exec_cmd("~/.local/bin/hypr-win-list"))
hl.bind(M1 .. "+backslash", hl.dsp.exec_cmd("~/.local/bin/hypr-win-list"))
hl.bind(M4 .. "+" .. SHIFT .. "+m", hl.dsp.exec_cmd("~/.local/bin/main-menu"))
hl.bind(M4 .. "+slash", hl.dsp.exec_cmd("~/.local/bin/hypr-shortcuts"))
hl.bind(M4 .. "+" .. SHIFT .. "+S", hl.dsp.exec_cmd("hyprquickframe"))
hl.bind(M4 .. "+" .. SHIFT .. "+r", hl.dsp.exec_cmd(
  'shot="$HOME/pic/shots/satty-$(date \'+%Y%m%d-%H.%M.%S\').png"; grim "$shot" && pic-info "$shot"'))
hl.bind(M4 .. "+" .. SHIFT .. "+" .. C .. "+r", hl.dsp.exec_cmd(
  'shot="$HOME/pic/shots/satty-$(date \'+%Y%m%d-%H.%M.%S\').png"; grim -g "$(slurp)" "$shot" && pic-info "$shot"'))
hl.bind(M4 .. "+" .. SHIFT .. "+v", hl.dsp.exec_cmd("~/.local/bin/screenrec screen"))
hl.bind(M4 .. "+" .. SHIFT .. "+" .. C .. "+v", hl.dsp.exec_cmd("~/.local/bin/screenrec area"))
hl.bind(M1 .. "+q", hl.dsp.exec_cmd("vicinae toggle"))
hl.bind("Caps_Lock", hl.dsp.exec_cmd("swayosd-client --caps-lock"))
hl.bind(M4 .. "+apostrophe", hl.dsp.exec_cmd("~/.local/bin/hypr-fix"))
hl.bind(M4 .. "+" .. SHIFT .. "+apostrophe", hl.dsp.exec_cmd("~/.local/bin/sys-relief"))
hl.bind(M4 .. "+i", hl.dsp.exec_cmd("wlr-which-key"))
hl.bind(M4 .. "+" .. M1 .. "+p", hl.dsp.exec_cmd("~/.local/bin/switch-proxy"))

-- Notifications
hl.bind(M4 .. "+n", hl.dsp.exec_cmd("dunstctl history-pop"))
hl.bind(M4 .. "+space", hl.dsp.exec_cmd("dunstctl close-all"), { locked = true })

-- Tiling helpers
hl.bind(M4 .. "+" .. C .. "+d", hl.dsp.layout("splitratio -0.1"), { release = true })
hl.bind(M4 .. "+" .. C .. "+f", hl.dsp.layout("splitratio +0.1"), { release = true })

local function submap_resets()
  hl.bind("escape", hl.dsp.submap("reset"))
  hl.bind(C .. "+c", hl.dsp.submap("reset"))
  hl.bind(C .. "+q", hl.dsp.submap("reset"))
  hl.bind("q", hl.dsp.submap("reset"))
end

local function bind_reset(key, dispatch_fn)
  hl.bind(key, dispatch_fn)
  hl.bind(key, hl.dsp.submap("reset"))
end

local function binde_reset(key, dispatch_fn)
  hl.bind(key, dispatch_fn, { release = true })
  hl.bind(key, hl.dsp.submap("reset"), { release = true })
end

-- Submap: resize
hl.bind(M4 .. "+" .. M1 .. "+r", hl.dsp.submap("resize"))
hl.define_submap("resize", "reset", function()
  submap_resets()
  hl.bind("right",  hl.dsp.window.resize({ x = 10, y = 0, relative = true }), { release = true })
  hl.bind("left",   hl.dsp.window.resize({ x = -10, y = 0, relative = true }), { release = true })
  hl.bind("up",     hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { release = true })
  hl.bind("down",   hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { release = true })
  hl.bind("l",      hl.dsp.window.resize({ x = 10, y = 0, relative = true }), { release = true })
  hl.bind("h",      hl.dsp.window.resize({ x = -10, y = 0, relative = true }), { release = true })
  hl.bind("k",      hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { release = true })
  hl.bind("j",      hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { release = true })
  hl.bind(SHIFT .. "+l", hl.dsp.window.resize({ x = -10, y = 0, relative = true }), { release = true })
  hl.bind(SHIFT .. "+h", hl.dsp.window.resize({ x = 10, y = 0, relative = true }), { release = true })
  hl.bind(SHIFT .. "+k", hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { release = true })
  hl.bind(SHIFT .. "+j", hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { release = true })
  hl.bind("equal",  hl.dsp.exec_cmd("~/.local/bin/hypr-resize-proportional +10"), { release = true })
  hl.bind("minus",  hl.dsp.exec_cmd("~/.local/bin/hypr-resize-proportional -10"), { release = true })
  hl.bind(SHIFT .. "+equal", hl.dsp.exec_cmd("~/.local/bin/hypr-resize-proportional +25"), { release = true })
  hl.bind(SHIFT .. "+minus", hl.dsp.exec_cmd("~/.local/bin/hypr-resize-proportional -25"), { release = true })
  hl.bind("Return", hl.dsp.submap("reset"))
end)

-- Submap: selectors
hl.bind(M4 .. "+Alt+S", hl.dsp.submap("selectors"))
hl.define_submap("selectors", "reset", function()
  submap_resets()
  bind_reset("w", hl.dsp.exec_cmd("hyde-selector wallpaper"))
  bind_reset("t", hl.dsp.exec_cmd("hyde-selector theme"))
  bind_reset("a", hl.dsp.exec_cmd("hyde-selector animation"))
  bind_reset("e", hl.dsp.exec_cmd('vicinae "vicinae://extensions/vicinae/core/search-emojis"'))
  bind_reset("c", hl.dsp.exec_cmd('vicinae "vicinae://extensions/vicinae/calculator/index"'))
  hl.bind("Return", hl.dsp.submap("reset"))
  hl.bind("escape", hl.dsp.submap("reset"))
end)

-- Submap: special
hl.bind(M1 .. "+e", hl.dsp.submap("special"))
hl.define_submap("special", "reset", function()
  submap_resets()
  binde_reset("r", hl.dsp.exec_cmd('raise --match "class:regex=^REAPER$" --launch "GDK_BACKEND=x11 reaper"'))
  binde_reset("q", hl.dsp.exec_cmd('raise --match "class:regex=^qpwgraph$" --launch "qpwgraph"'))
  binde_reset("d", hl.dsp.exec_cmd('raise --match "class:regex=^org%.nicotine_plus%.Nicotine$" --launch "nicotine"'))
  binde_reset(SHIFT .. "+q", hl.dsp.exec_cmd('raise --match "class:regex=^Carla2$" --launch "carla"'))
  binde_reset(SHIFT .. "+l", hl.dsp.exec_cmd("hyprctl switchxkblayout current 0 && hyprlock"))
  binde_reset("e", hl.dsp.window.float({ action = "toggle" }))
  binde_reset("f", hl.dsp.window.fullscreen_state({ internal = 0, client = 3, action = "toggle" }))
  binde_reset("z", hl.dsp.window.fullscreen_state({ internal = 0, client = 3, action = "toggle" }))
  hl.bind("semicolon", hl.dsp.submap("reset"), { release = true })
  binde_reset(SHIFT .. "+w", hl.dsp.exec_cmd("pkill iwmenu || iwmenu --launcher rofi"))
  binde_reset("o", hl.dsp.exec_cmd('raise --match "match:title ^(Open File|Select a File|Choose wallpaper|Open Folder|Save As|Library|File Upload)(.*)$"'))
end)

-- Submap: tiling
hl.bind(M4 .. "+minus", hl.dsp.submap("tiling"))
hl.define_submap("tiling", "reset", function()
  submap_resets()
  hl.bind(SHIFT .. "+h", hl.dsp.window.move({ direction = "l" }))
  hl.bind(SHIFT .. "+j", hl.dsp.window.move({ direction = "d" }))
  hl.bind(SHIFT .. "+k", hl.dsp.window.move({ direction = "u" }))
  hl.bind(SHIFT .. "+l", hl.dsp.window.move({ direction = "r" }))
  hl.bind("equal", hl.dsp.layout("colresize +conf"))
  hl.bind("minus", hl.dsp.layout("colresize -conf"))
  hl.bind("1", hl.dsp.layout("colresize exact 0.25"))
  hl.bind("2", hl.dsp.layout("colresize exact 0.33"))
  hl.bind("3", hl.dsp.layout("colresize exact 0.5"))
  hl.bind("4", hl.dsp.layout("colresize exact 0.66"))
  hl.bind("5", hl.dsp.layout("colresize exact 0.75"))
  hl.bind("6", hl.dsp.layout("colresize exact 1.0"))
  hl.bind("bracketright", hl.dsp.layout("colresize +50"), { release = true })
  hl.bind("bracketleft", hl.dsp.layout("colresize -50"), { release = true })
  hl.bind("p", hl.dsp.layout("promote"))
  hl.bind(C .. "+h", hl.dsp.layout("swapcol l"))
  hl.bind(C .. "+l", hl.dsp.layout("swapcol r"))
  hl.bind("f", hl.dsp.layout("fit active"))
  hl.bind(SHIFT .. "+f", hl.dsp.layout("fit all"))
  hl.bind("h", hl.dsp.layout("move -200"), { release = true })
  hl.bind("l", hl.dsp.layout("move +200"), { release = true })
  hl.bind(SHIFT .. "+bracketleft", hl.dsp.layout("move -600"), { release = true })
  hl.bind(SHIFT .. "+bracketright", hl.dsp.layout("move +600"), { release = true })
  hl.bind("t", hl.dsp.layout("togglefit"))
end)

-- Submap: wallpaper
hl.bind(M4 .. "+" .. SHIFT .. "+y", hl.dsp.submap("wallpaper"))
hl.define_submap("wallpaper", "reset", function()
  submap_resets()
  hl.bind("y", hl.dsp.exec_cmd("wl random ~/pic/wl"))
  hl.bind(M4 .. "+y", hl.dsp.exec_cmd("wl random ~/pic/wl"))
  hl.bind(SHIFT .. "+w", hl.dsp.submap("reset"))
end)

-- Submap: vpn
hl.bind(M4 .. "+v", hl.dsp.submap("vpn"))
hl.define_submap("vpn", "reset", function()
  submap_resets()
  binde_reset("h", hl.dsp.exec_cmd("~/.local/bin/scratchpad-toggle hiddify"))
  binde_reset("a", hl.dsp.exec_cmd("~/.local/bin/scratchpad-toggle amnezia"))
  binde_reset("f", hl.dsp.exec_cmd("~/.local/bin/scratchpad-toggle flclashx"))
  binde_reset("n", hl.dsp.exec_cmd("~/.local/bin/scratchpad-toggle v2rayn"))
end)

local ws_defs = {
  { workspace = "1",  default_name = "𐌰:term" },
  { workspace = "2",  default_name = "𐌱:web" },
  { workspace = "3",  default_name = "𐌲:dev" },
  { workspace = "4",  default_name = "𐌸:games", gaps_out = 0, gaps_in = 0, layout = "monocle" },
  { workspace = "5",  default_name = "𐌳:doc" },
  { workspace = "6",  default_name = "𐌴:draw" },
  { workspace = "7",  default_name = "𐌵:vid" },
  { workspace = "8",  default_name = "𐌶:obs" },
  { workspace = "9",  default_name = "𐌷:pic" },
  { workspace = "10", default_name = "𐌹:sys" },
  { workspace = "11", default_name = "𐌺:vm" },
  { workspace = "12", default_name = "𐌻:wine" },
  { workspace = "13", default_name = "𐌼:patchbay" },
  { workspace = "14", default_name = "𐌽:daw" },
  { workspace = "15", default_name = "𐌾:dw" },
  { workspace = "16", default_name = "𐌿:keyboard" },
  { workspace = "17", default_name = "𐍀:im" },
  { workspace = "18", default_name = "𐍁:remote" },
  { workspace = "19", default_name = "Ⲣ:notes" },
  { workspace = "20", default_name = "𐍅:winboat" },
}

for _, ws in ipairs(ws_defs) do
  hl.workspace_rule(ws)
end

hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]", gaps_out = 0, gaps_in = 0 })

hl.window_rule({
  name = "hide-borders-tiled",
  match = { float = false },
  border_size = 0,
})

hl.window_rule({
  name = "route-term-noblur",
  match = { class = term },
  no_blur = true,
  workspace = "1",
})

hl.window_rule({
  name = "route-zen",
  match = { initial_class = "^(zen)$" },
  workspace = "2 silent",
})

hl.window_rule({
  name = "route-web",
  match = { class = web_browsers },
  workspace = "2 silent",
})

local route_rules = {
  { class = dev,     ws = "3" },
  { class = games,   ws = "4" },
  { class = doc,     ws = "5" },
  { class = vid,     ws = "7" },
  { class = obs,     ws = "8" },
  { class = pic,     ws = "9" },
  { class = patchbay, ws = "13" },
  { class = daw,     ws = "14" },
  { class = dw,      ws = "15" },
  { class = keyboard, ws = "16" },
  { class = im,      ws = "17" },
  { class = remote,  ws = "18" },
  { class = notes,   ws = "19" },
  { class = vm,      ws = "11" },
  { class = wine,    ws = "12" },
  { class = winboat, ws = "20" },
}

for _, r in ipairs(route_rules) do
  hl.window_rule({
    name = "route-" .. r.class,
    match = { class = r.class },
    workspace = r.ws,
  })
end

hl.window_rule({
  name = "pic-fullscreen",
  match = { class = pic },
  fullscreen = true,
})

hl.monitor({
  output = "DP-2",
  mode = "3840x2160@240",
  position = "0x0",
  scale = 2,
  vrr = 3,
  bitdepth = 10,
  cm = "auto",
})

hl.monitor({
  output = "DP-1",
  disabled = true,
})

hl.config({
  xwayland = {
    force_zero_scaling = true,
    use_nearest_neighbor = true,
  },
  general = {
    gaps_in = 0,
    gaps_out = 0,
    border_size = border_size,
    col = {
      active_border = { colors = { col_border_active_base, col_border_active_base }, angle = 45 },
      inactive_border = col_border_inactive,
    },
    resize_on_border = false,
    allow_tearing = true,
    layout = "scrolling",
  },
  cursor = {
    sync_gsettings_theme = true,
    no_hardware_cursors = true,
    min_refresh_rate = 240,
    inactive_timeout = 1,
    hide_on_key_press = true,
    warp_on_change_workspace = false,
  },
  render = {
    direct_scanout = 2,
  },
  decoration = {
    rounding = rounding,
    rounding_power = rounding_power,
    active_opacity = opacity_active,
    inactive_opacity = opacity_inactive,
    shadow = {
      enabled = false,
      range = 4,
      render_power = 1,
      color = shadow_color,
    },
    blur = {
      enabled = true,
      size = blur_size,
      passes = blur_passes,
      vibrancy = blur_vibrancy,
    },
  },
  dwindle = {
    preserve_split = true,
    smart_resizing = false,
    smart_split = false,
  },
  master = {
    new_status = "master",
    mfact = 0.7,
  },
  scrolling = {
    column_width = 0.5,
    fullscreen_on_one_column = true,
    explicit_column_widths = "0.5, 1.0",
    focus_fit_method = 1,
    follow_focus = true,
    follow_min_visible = 0.5,
    direction = "right",
  },
  misc = {
    disable_hyprland_logo = false,
    enable_anr_dialog = false,
    force_default_wallpaper = 0,
    font_family = "Iosevka",
    splash_font_family = "Iosevka",
    vrr = 3,
    enable_swallow = true,
    middle_click_paste = false,
    disable_autoreload = 0,
  },
  input = {
    kb_layout = "us,ru",
    kb_variant = "",
    kb_model = "",
    kb_options = "",
    kb_rules = "",
    follow_mouse = 1,
    sensitivity = 0,
    repeat_rate = 35,
    repeat_delay = 250,
    touchpad = {
      natural_scroll = true,
      disable_while_typing = true,
      clickfinger_behavior = true,
    },
  },
})

hl.curve("myBezier",   { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.curve("linear",     { type = "bezier", points = { {0, 0}, {1, 1} } })
hl.curve("md3_standard", { type = "bezier", points = { {0.2, 0}, {0, 1} } })
hl.curve("md3_decel",  { type = "bezier", points = { {0.05, 0.7}, {0.1, 1} } })
hl.curve("md3_accel",  { type = "bezier", points = { {0.3, 0}, {0.8, 0.15} } })
hl.curve("overshot",   { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.1} } })
hl.curve("crazyshot",  { type = "bezier", points = { {0.1, 1.5}, {0.76, 0.92} } })
hl.curve("hyprnostretch", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.0} } })
hl.curve("menu_decel", { type = "bezier", points = { {0.1, 1}, {0, 1} } })
hl.curve("menu_accel", { type = "bezier", points = { {0.38, 0.04}, {1, 0.07} } })
hl.curve("easeInOutCirc", { type = "bezier", points = { {0.85, 0}, {0.15, 1} } })
hl.curve("easeOutCirc", { type = "bezier", points = { {0, 0.55}, {0.45, 1} } })
hl.curve("easeOutExpo", { type = "bezier", points = { {0.16, 1}, {0.3, 1} } })
hl.curve("md2",        { type = "bezier", points = { {0.4, 0}, {0.2, 1} } })

hl.animation({ leaf = "borderangle",      enabled = true, speed = 8,     bezier = "default" })
hl.animation({ leaf = "windows",          enabled = true, speed = 0.1875, bezier = "md3_decel",     style = "popin 60%" })
hl.animation({ leaf = "windowsIn",        enabled = true, speed = 0.1875, bezier = "md3_decel",     style = "popin 60%" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 0.1875, bezier = "md3_accel",     style = "popin 60%" })
hl.animation({ leaf = "border",           enabled = true, speed = 0.625,  bezier = "default" })
hl.animation({ leaf = "fade",             enabled = true, speed = 0.1875, bezier = "md3_decel" })
hl.animation({ leaf = "layersIn",         enabled = true, speed = 0.1875, bezier = "menu_decel",    style = "slide" })
hl.animation({ leaf = "layersOut",        enabled = true, speed = 0.1,    bezier = "menu_accel" })
hl.animation({ leaf = "fadeLayersIn",     enabled = true, speed = 0.125,  bezier = "menu_decel" })
hl.animation({ leaf = "fadeLayersOut",    enabled = true, speed = 0.03125, bezier = "menu_accel" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 0.125,  bezier = "menu_decel",    style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 0.1875, bezier = "md3_decel",     style = "slidefadevert 15%" })
