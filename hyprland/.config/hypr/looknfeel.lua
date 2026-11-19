-- How windows look and move: gaps, borders, blur, shadows, animations and the
-- tiling layout. Loaded by hyprland.lua.

local transparency = __require("transparency_state") -- Which windows are see-through

-------------------
-- LOOK AND FEEL --
-------------------

hl.config({
  general = {
    gaps_in = 5,
    gaps_out = 10,

    -- A thin line marks the window you're in (accent.lua colors it), the others have none
    border_size = 1,

    col = {
      inactive_border = "rgba(00000000)",
    },

    resize_on_border = false,

    allow_tearing = false,

    layout = "dwindle",
  },
})

hl.config({
  decoration = {
    -- The shell's cards' corners, so windows and cards match (Metrics.radius.card)
    rounding = 19,
    rounding_power = 2,

    -- See-through when the settings say all windows are, so the wallpaper shows behind the blur
    active_opacity = transparency.windows,
    inactive_opacity = transparency.windows,

    -- The windows you're not in fade back a little
    dim_inactive = true,
    dim_strength = 0.12,

    -- The glow around the window you're in, nothing around the others. accent.lua colors
    -- it and lights it in neon only.
    shadow = {
      range = 14,
      render_power = 4,
      color_inactive = "rgba(00000000)",
    },

    blur = {
      enabled = true,
      size = 1,
      passes = 4,
      contrast = 1.1,
      -- Darkens a light page far more than the dark wallpaper, so the shell's glass stays readable over it
      brightness = 0.9,
      vibrancy = 0.2,
      vibrancy_darkness = 0.2,
      noise = 0.03,
      ignore_opacity = true,
    },
  },
})

-- Off for the reload that moves the screens, so the windows land in their new places
-- at once (displayctl.sh, which turns them back on right after)
local still = io.open((os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/hyprpunk-still-reload")
if still ~= nil then
  still:close()
end

hl.config({
  animations = {
    enabled = still == nil,
  },
})

-- Windows move like the shell's cards (theme/Motion.qml). The spring runs on real time
-- and keeps its momentum, so a move cut short by another flows on into it.

-- Straight into place, never past it: no bounce
hl.curve("glide", { type = "spring", mass = 1, stiffness = 400, damping = 40 })
-- Appearing decelerates, going away accelerates
hl.curve("enter", { type = "bezier", points = { { 0.215, 0.61 }, { 0.355, 1 } } })
hl.curve("leave", { type = "bezier", points = { { 0.55, 0.055 }, { 0.675, 0.19 } } })
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1.0 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

-- A spring takes the time its physics give it: its speed is only there because
-- Hyprland asks for one
hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
-- A window grows out into its place from half its size, and shrinks back quicker than
-- it came, gone as it gets small. The ones around it make room on the same spring.
hl.animation({ leaf = "windows", enabled = true, speed = 1, spring = "glide" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 1, spring = "glide", style = "popin 55%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "leave", style = "popin 50%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.4, bezier = "enter" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 2, bezier = "leave" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
-- Snappy on the way in, quicker on the way out
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
-- Popups close at once. The shell already folds its cards back into their pill, and
-- Hyprland's fade, drawn without the blur, flashed the liquid glass darker after it
hl.animation({ leaf = "fadePopupsOut", enabled = false })
-- The workspaces lie side by side like their buttons in the bar: you travel along them
-- the way three fingers swipe, the one you leave and the one you reach moving as one
hl.animation({ leaf = "workspaces", enabled = true, speed = 1, spring = "glide", style = "slide" })

hl.config({
  dwindle = {
    preserve_split = true, -- A split keeps its direction when windows come and go
    force_split = 2,       -- New windows always open to the right or below, wherever the mouse is
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
