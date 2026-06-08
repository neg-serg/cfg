local function load(name)
  dofile(os.getenv("HOME") .. "/.config/hypr/" .. name .. ".lua")
end

load("env")
load("vars")
load("classes")
load("autostart")
load("rules")
load("bindings")
load("workspaces")
load("init")
