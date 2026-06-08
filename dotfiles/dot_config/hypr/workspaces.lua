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
