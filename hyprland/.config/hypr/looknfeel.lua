-- How windows look and move: gaps, borders, blur, shadows, animations and the
-- tiling layout. Loaded by hyprland.lua.

local colors = require("mocha") -- Catppuccin Mocha palette

-------------------
-- LOOK AND FEEL --
-------------------

hl.config({
  general = {
    gaps_in = 5,
    gaps_out = 10,

    border_size = 2,

    col = {
      active_border = colors.mauve,
      inactive_border = colors.lavender,
    },

    resize_on_border = false,

    allow_tearing = false,

    layout = "dwindle",
  },
})

hl.config({
  decoration = {
    rounding = 18,
    rounding_power = 2,

    -- Slightly see-through, so the wallpaper shows behind the blur
    active_opacity = 0.9,
    inactive_opacity = 0.9,

    shadow = {
      enabled = true,
      range = 4,
      render_power = 3,
      color = "rgba(1a1a1aee)",
    },

    blur = {
      enabled = true,
      size = 1,
      passes = 4,
      contrast = 1.1,
      brightness = 1.1,
      vibrancy = 0.2,
      vibrancy_darkness = 0.2,
      noise = 0.03,
      ignore_opacity = true,
    },
  },
})

hl.config({
  animations = {
    enabled = true,
  },
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1.0 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

-- Snappy on the way in, quicker on the way out
hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
-- Popups close at once. The shell already folds its cards back into their pill, and
-- Hyprland's fade, drawn without the blur, flashed the liquid glass darker after it
hl.animation({ leaf = "fadePopupsOut", enabled = false })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

hl.config({
  dwindle = {
    preserve_split = true, -- A split keeps its direction when windows come and go
    force_split = 2,       -- New windows always open to the right or below, wherever the mouse is
  },
})

hl.config({
  master = {
    new_status = "master",
  },
})

hl.config({
  misc = {
    force_default_wallpaper = -1, -- Hyprland's own wallpaper; awww draws ours on top anyway
    disable_hyprland_logo = true, -- No logo or anime mascot behind the wallpaper
    -- If the shell crashes while locked, it can take the lock back once restarted
    allow_session_lock_restore = true,
  },
})
