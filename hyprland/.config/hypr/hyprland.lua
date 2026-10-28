-- HyprPunk's Hyprland setup. This file only loads the pieces in order, each about
-- one thing; what the shell's settings saved is read by the *_state.lua files.

pcall(require, "personal") -- Your own tweaks in ~/.config/hypr/personal.lua, skipped if it doesn't exist
require("monitors")        -- Screens
require("workspaces")      -- Which workspace lives on which screen, per machine
require("input")           -- Keyboard, mouse, touchpad and gestures
require("looknfeel")       -- Gaps, borders, blur, animations and layout
require("rules")           -- Where apps open, and the shell's blurred layers
require("keybindings")     -- Shortcuts
require("env")             -- Environment variables
require("autostart")       -- What starts with the session, and screen hotplug
