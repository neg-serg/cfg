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
