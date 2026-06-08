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

require("animations.neg")
