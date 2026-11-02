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
  { class = "org.kde.dolphin",      workspace = "6" },
}

-- Opens an app on its workspace. Also for personal/rules.lua: a second call for the
-- same app wins, so it moves one of these elsewhere too.
function hyprpunk.app(class, workspace)
  hl.window_rule({ match = { class = class }, workspace = tostring(workspace) })
end

for _, home in ipairs(homes) do
  hyprpunk.app(home.class, home.workspace)
end

-- Bitwarden's little popup is its own Chromium app: float it so it doesn't cut Brave in half
hl.window_rule({ match = { class = "brave-nngceckbapebfimnlniiiahkandclblb-Default" }, float = true })

-- Floats every window of an app but its main one, picked by the title it opens with.
-- For the apps whose dialogs don't say they belong to their main window, so they'd get
-- tiled: cut off when they need more room than the tile, or drawn small in a tile
-- blurred all around. Also for personal/rules.lua.
function hyprpunk.float_dialogs(class, main_title)
  hl.window_rule({ match = { class = class, initial_title = "negative:" .. main_title }, float = true })
end

-- GIMP's preferences and splash, among others
hyprpunk.float_dialogs("^gimp$", "^(GNU Image Manipulation Program|.* – GIMP)$")

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

-- The shell's see-through panels: blur only what is drawn, not the empty space around it
local glassLayers = {
  { namespace = "hyprpunk-notifications" },
  { namespace = "hyprpunk-notification-center" },
  { namespace = "hyprpunk-osd" },
  { namespace = "hyprpunk-control-center" },
  { namespace = "hyprpunk-tray",               blur_popups = true },
  -- The island's panels (session menu, wallpaper picker) bring their own animation
  { namespace = "hyprpunk-island",             no_anim = true },
  -- In the classic style the bar's pills are opaque, so the blur only shows behind the island and the player
  { namespace = "hyprpunk-bar",                blur_popups = true },
}

for _, layer in ipairs(glassLayers) do
  hl.layer_rule({
    match = { namespace = layer.namespace },
    blur = true,
    blur_popups = layer.blur_popups,
    ignore_alpha = glass.ignore_alpha,
    no_anim = layer.no_anim,
  })
end

-- Screenshot selection appears right away over the frozen screen, no fade
hl.layer_rule({ match = { namespace = "hyprpunk-screenshot" }, no_anim = true })
