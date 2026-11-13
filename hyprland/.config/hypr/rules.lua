-- Where each app opens and how windows behave, then how Hyprland blurs and animates
-- the shell's own layers. Loaded by hyprland.lua, before your personal/rules.lua.

package.loaded["glass_state"] = nil -- Glass style, read again on every reload
local linked, glass = pcall(__require, "glass_state")
-- Classic until glass_state.lua is linked, so a git pull without stow can't break the config
if not linked then
  glass = { liquid = false, ignore_alpha = 0.5 }
end

------------------
-- WINDOW RULES --
------------------

-- Every app has its home
local homes = {
  { class = "kitty",                workspace = "1" },
  { class = "brave-browser",        workspace = "2" },
  { class = "Spotify",              workspace = "3" },
  { class = "md.obsidian.Obsidian", workspace = "4" },
  { class = "thunar",               workspace = "6" },
}

-- Opens an app on its workspace. Also for personal/rules.lua: a second call for the
-- same app wins, so it moves one of these elsewhere too.
function hyprpunk.app(class, workspace)
  hl.window_rule({ match = { class = class }, workspace = tostring(workspace) })
end

for _, home in ipairs(homes) do
  hyprpunk.app(home.class, home.workspace)
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

-- The shell's window, with the bar and every card: blur only what is drawn, not the
-- empty space around it, and its tooltips too
hl.layer_rule({
  match = { namespace = "hyprpunk-shell" },
  blur = true,
  blur_popups = true,
  ignore_alpha = glass.ignore_alpha,
})

-- Screenshot selection appears right away over the frozen screen, no fade
hl.layer_rule({ match = { namespace = "hyprpunk-screenshot" }, no_anim = true })
