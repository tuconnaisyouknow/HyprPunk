-- HyprPunk's Hyprland setup. This file only loads the pieces in order, each about
-- one thing; what the shell's settings saved is read by the *_state.lua files.
-- Your own changes go in ~/.config/hypr/personal/, which install.sh starts from the
-- examples in the dotfiles' personal.example folder.

-- What the modules share with your personal files: programs, bind, app, autostart…
hyprpunk = {}

require("monitors")    -- Screens
require("workspaces")  -- Which workspace lives on which screen, per machine
require("input")       -- Keyboard, mouse, touchpad and gestures
require("looknfeel")   -- Gaps, borders, blur, animations and layout
require("rules")       -- Where apps open, and the shell's blurred layers
require("keybindings") -- Shortcuts
require("env")         -- Environment variables
require("autostart")   -- What starts with the session, and screen hotplug

-- Your files come last, so whatever they set wins. Each one is skipped if it doesn't exist.
for _, name in ipairs({ "input", "rules", "keybindings", "autostart" }) do
  if package.searchpath("personal." .. name, package.path) then
    require("personal." .. name)
  end
end
