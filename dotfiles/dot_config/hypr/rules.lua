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
