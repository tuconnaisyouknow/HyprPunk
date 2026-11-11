-- Every shortcut, each with the description the shell's keybindings panel shows
-- (Super+Ctrl+K). Loaded by hyprland.lua, before your personal/keybindings.lua.

--------------
-- PROGRAMS --
--------------

-- The apps the shortcuts below open, and the terminal and editor everything else
-- uses. Change one in personal/keybindings.lua (hyprpunk.programs.music = "...") and
-- what opens it follows.
hyprpunk.programs = {
  terminal = "kitty",
  editor = "nvim",
  files = "dolphin",
  browser = "brave",
  notes = "obsidian",
  music = "spotify-launcher",
}

-- Read when the key is pressed rather than now, so a change made after this file still counts
local function launch(program)
  return function()
    hl.dispatch(hl.dsp.exec_cmd(hyprpunk.programs[program]))
  end
end

local menu = "qs -c hyprpunk ipc call launcher toggle"
local keyboard = __require("keyboard_state")

local binds = require("lib.bind")
local bind = binds.bind
hyprpunk.bind = binds.bind
hyprpunk.rebind = binds.rebind
hyprpunk.unbind = binds.unbind

-- Floating windows slide by a few pixels, tiled ones swap places with their neighbour
local function move_active_window_or_dispatch(direction, delta)
  return function()
    local activeWindow = hl.get_active_window()

    if activeWindow ~= nil and activeWindow.floating then
      hl.dispatch(hl.dsp.window.move({
        x = delta.x,
        y = delta.y,
        relative = true,
      }))
      return
    end

    hl.dispatch(hl.dsp.window.move({ direction = direction }))
  end
end

-----------------
-- KEYBINDINGS --
-----------------

local mainMod = "SUPER" -- The Windows key
local shell = "qs -c hyprpunk ipc call "

----------
-- APPS --
----------

bind(mainMod .. " + T", launch("terminal"), "Open the terminal")
bind(mainMod .. " + E", launch("files"), "Open the file manager")
bind(mainMod .. " + B", launch("browser"), "Open the web browser")
bind(mainMod .. " + O", launch("notes"), "Open the notes")
bind(mainMod .. " + P", launch("music"), "Open the music player")
-- What's playing, in the bar's card rather than the app. Nothing while Spotify isn't running.
bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd(shell .. "player toggle"), "Show the music player card")

-----------
-- SHELL --
-----------

-- What you reach for all day sits on Super alone, on the keys Windows uses for it
bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu), "Open the application launcher")
bind(mainMod .. " + V", hl.dsp.exec_cmd(shell .. "clipboard toggle"), "Open the clipboard history")
-- Both, like Windows: ; needs no Shift on AZERTY, where . does
bind(mainMod .. " + period", hl.dsp.exec_cmd(shell .. "emoji toggle"), "Open the emoji selector")
bind(mainMod .. " + semicolon", hl.dsp.exec_cmd(shell .. "emoji toggle"), "Open the emoji selector")
bind(mainMod .. " + N", hl.dsp.exec_cmd(shell .. "notifications toggle"), "Toggle the calendar and notifications")
bind(mainMod .. " + C", hl.dsp.exec_cmd(shell .. "controlcenter toggle"), "Toggle the control center")
bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"), "Pick a color from the screen")

-- What you open now and then takes Ctrl too
bind(mainMod .. " + CTRL + SPACE", hl.dsp.exec_cmd(shell .. "menu toggle"), "Open the main menu")
bind(mainMod .. " + CTRL + W", hl.dsp.exec_cmd(shell .. "wallpaper toggle"), "Open the wallpaper selector")
bind(mainMod .. " + CTRL + T", hl.dsp.exec_cmd(shell .. "theme toggle"), "Choose the theme")
bind(mainMod .. " + CTRL + K", hl.dsp.exec_cmd(shell .. "keybindings toggle"), "Show all keybindings")
-- The keys of Windows' Task Manager, which every hand already knows
bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd(shell .. "systemmonitor toggle"), "Show the system monitor")

-----------------------------
-- SCREENSHOTS AND RECORDS --
-----------------------------

bind("Print", hl.dsp.exec_cmd(shell .. "screenshot screen"), "Capture the active monitor")
bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(shell .. "screenshot region"),
  "Capture a screen region or a window")
bind(mainMod .. " + CTRL + S", hl.dsp.exec_cmd(shell .. "screenshot annotate"),
  "Capture and annotate a screen region")
-- The same keys start and stop a recording
bind("SHIFT + Print", hl.dsp.exec_cmd(shell .. "screenshot record"),
  "Record the active monitor, or stop recording")
bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd(shell .. "screenshot recordRegion"),
  "Record a screen region or a window, or stop recording")

-------------
-- WINDOWS --
-------------

bind(mainMod .. " + Q", hl.dsp.window.close(), "Close the focused window")
-- One key to give a window the whole screen, the bar staying; F11 hides the bar too,
-- but it's often behind Fn on laptops
bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized" }), "Maximize the focused window")
bind("F11", hl.dsp.window.fullscreen(), "Toggle fullscreen mode")
bind(mainMod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }),
  "Toggle floating mode for the focused window")
bind(mainMod .. " + S", hl.dsp.layout("togglesplit"), "Toggle the split direction")

-- Vim-style arrows, shifted one key right on AZERTY (see keyboard_state.lua), and the
-- real arrows for whoever doesn't think in Vim. Add Shift to move the window instead.
local directions = {
  { keys = { keyboard.left, "left" },   direction = "l", delta = { x = -30, y = 0 }, focus = "Focus the window on the left",  move = "Move the active window left" },
  { keys = { keyboard.right, "right" }, direction = "r", delta = { x = 30, y = 0 },  focus = "Focus the window on the right", move = "Move the active window right" },
  { keys = { keyboard.up, "up" },       direction = "u", delta = { x = 0, y = -30 }, focus = "Focus the window above",        move = "Move the active window up" },
  { keys = { keyboard.down, "down" },   direction = "d", delta = { x = 0, y = 30 },  focus = "Focus the window below",        move = "Move the active window down" },
}

for _, way in ipairs(directions) do
  for _, key in ipairs(way.keys) do
    bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = way.direction }), way.focus)
    bind(mainMod .. " + SHIFT + " .. key, move_active_window_or_dispatch(way.direction, way.delta), way.move,
      { repeating = true })
  end
end

-- Hold Super and drag: left click moves, right click resizes
bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), "Drag to move a window", { mouse = true })
bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), "Drag to resize a window", { mouse = true })

----------------
-- WORKSPACES --
----------------

-- The number row, read by position so it works on AZERTY too (code:10 is 1, code:19 is 0)
for number = 1, 10 do
  bind(mainMod .. " + code:" .. (number + 9), hl.dsp.focus({ workspace = number }),
    "Switch to workspace " .. number)
end

-- Add Shift to send the focused window there
for number = 1, 10 do
  bind(mainMod .. " + SHIFT + code:" .. (number + 9), hl.dsp.window.move({ workspace = number }),
    "Move the focused window to workspace " .. number)
end

-- Back and forth between two tasks, like Alt+Tab between windows
bind(mainMod .. " + Tab", hl.dsp.focus({ workspace = "previous" }), "Switch back to the previous workspace")
-- A look before you go, on the one you were on last: the arrows or Tab go through the
-- others, Enter takes you there. Nothing happens while they're all empty.
bind(mainMod .. " + W", hl.dsp.exec_cmd(shell .. "workspaces toggle"), "Preview your other workspaces")

-- Scroll through the workspaces in use
bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "Switch to the next workspace")
bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), "Switch to the previous workspace")

-------------
-- SESSION --
-------------

bind(mainMod .. " + CTRL + L", hl.dsp.exec_cmd(shell .. "lock lock"), "Lock the screen")
bind(mainMod .. " + Escape", hl.dsp.exec_cmd(shell .. "session toggle"),
  "Open the session menu (lock, logout, reboot, shutdown)")

-- Upkeep: restart what misbehaves, update everything. Alt keeps them out of a slip's reach.
bind(mainMod .. " + ALT + Q", hl.dsp.exec_cmd("killall qs ; qs -c hyprpunk"), "Reload Quickshell")
bind(mainMod .. " + ALT + I", hl.dsp.exec_cmd("killall hypridle ; hypridle"), "Reload Hypridle")
bind(mainMod .. " + ALT + U", hl.dsp.exec_cmd("$TERMINAL -e yay -Syu --removemake"), "Update all packages")

-------------------
-- HARDWARE KEYS --
-------------------

-- They keep working on the lock screen

-- Sound
bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
  "Increase the output volume", { locked = true, repeating = true })
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
  "Decrease the output volume", { locked = true, repeating = true })
bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
  "Mute or unmute the audio output", { locked = true })
bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
  "Mute or unmute the microphone", { locked = true })

-- Screen and touchpad
bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -c backlight -q set 5%+"),
  "Increase the screen brightness", { locked = true, repeating = true })
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -c backlight -q set 5%-"),
  "Decrease the screen brightness", { locked = true, repeating = true })
bind("XF86TouchpadToggle", hl.dsp.exec_cmd("~/Scripts/touchpadctl.sh toggle"),
  "Enable or disable the touchpad", { locked = true })

-----------
-- MEDIA --
-----------

-- Next and previous go through the shell first, so the player's animation follows
local nextTrack = shell .. "music next || playerctl next"
local previousTrack = shell .. "music previous || playerctl previous"

-- Media keys
bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), "Toggle media playback", { locked = true })
bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), "Toggle media playback", { locked = true })
bind("XF86AudioNext", hl.dsp.exec_cmd(nextTrack), "Play the next track", { locked = true })
bind("XF86AudioPrev", hl.dsp.exec_cmd(previousTrack), "Play the previous track", { locked = true })

-- The same for keyboards without them, plus shuffle, on the Vim arrows so previous and
-- next stay left and right whatever the layout
bind(mainMod .. " + SHIFT + CTRL + " .. keyboard.down, hl.dsp.exec_cmd("playerctl play-pause"),
  "Toggle media playback", { locked = true })
bind(mainMod .. " + SHIFT + CTRL + " .. keyboard.right, hl.dsp.exec_cmd(nextTrack), "Play the next track",
  { locked = true })
bind(mainMod .. " + SHIFT + CTRL + " .. keyboard.left, hl.dsp.exec_cmd(previousTrack), "Play the previous track",
  { locked = true })
bind(mainMod .. " + SHIFT + CTRL + " .. keyboard.up, hl.dsp.exec_cmd("playerctl shuffle toggle"),
  "Toggle shuffle mode", { locked = true })
