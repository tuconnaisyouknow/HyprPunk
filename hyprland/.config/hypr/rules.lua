-- Where each app opens and how windows behave, then how Hyprland blurs and animates
-- the shell's own layers. Loaded by hyprland.lua, before your personal/rules.lua.

local glass = __require("glass_state") -- The shell's glass style

------------------
-- WINDOW RULES --
------------------

-- Opens an app on a workspace of its own, for personal/rules.lua: apps open where you
-- are until you give them one
function hyprpunk.app(class, workspace)
  hl.window_rule({ match = { class = class }, workspace = tostring(workspace) })
end

-- Floats every window of an app but its main one, picked by the title it opens with.
-- For the apps whose dialogs don't say they belong to their main window, so they'd get
-- tiled: cut off when they need more room than the tile, or drawn small in a tile
-- blurred all around. Also for personal/rules.lua.
function hyprpunk.float_dialogs(class, main_title)
  hl.window_rule({ match = { class = class, initial_title = "negative:" .. main_title }, float = true })
end

-- GIMP's preferences and splash, among others
hyprpunk.float_dialogs("^gimp$", "^(GNU Image Manipulation Program|.* – GIMP)$")

-- The shell's settings float over your work, at the size the shell asks for
hl.window_rule({ match = { class = "^org\\.quickshell$", title = "^HyprPunk Settings$" }, float = true })

-- Floating windows open in the middle of the screen
hl.window_rule({ match = { float = true }, center = true })

-- Apps don't get to maximize themselves, the layout decides
hl.window_rule({
  name = "suppress-maximize-events",
  match = { class = ".*" },
  suppress_event = "maximize",
})

-----------------
-- LAYER RULES --
-----------------

-- The shell asks for the blur behind its pills and cards itself, shape by shape. Its
-- tooltips can't: blur what they draw, not the empty space around
hl.layer_rule({
  match = { namespace = "hyprpunk-shell" },
  blur_popups = true,
  ignore_alpha = glass.ignore_alpha,
})

-- Screenshot selection appears right away over the frozen screen, no fade
hl.layer_rule({ match = { namespace = "hyprpunk-screenshot" }, no_anim = true })

-- The island the lock leaves behind stands in for the bar's at once and goes unseen
hl.layer_rule({ match = { namespace = "hyprpunk-relay" }, no_anim = true })
