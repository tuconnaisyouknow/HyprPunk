-- Every shortcut, each with the description the shell's keybindings panel shows
-- (Super+Ctrl+K). Loaded by hyprland.lua, before your personal/keybindings.lua.

--------------
-- PROGRAMS --
--------------

-- The apps the shortcuts below open. Change one in personal/keybindings.lua
-- (hyprpunk.programs.music = "...") and its shortcut follows.
hyprpunk.programs = {
  terminal = "kitty",
  files = "dolphin",
  browser = "brave",
  notes = "obsidian",
  music = "spotify-launcher",
  chat = "discord",
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
bind(mainMod .. " + D", launch("chat"), "Open the chat")

-----------
-- SHELL --
-----------

-- Launchers and pickers
bind("ALT + SPACE", hl.dsp.exec_cmd(menu), "Open the application launcher")
bind("CTRL + ALT + SPACE", hl.dsp.exec_cmd(shell .. "menu toggle"), "Open the main menu")
-- Bound by position, the key right of the home row: ù on AZERTY, ' on QWERTY
bind("CTRL + code:48", hl.dsp.exec_cmd(shell .. "clipboard toggle"), "Open the clipboard history")
bind(mainMod .. " + semicolon", hl.dsp.exec_cmd(shell .. "emoji toggle"), "Open the emoji selector")
bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"), "Pick a color from the screen")

-- Side panels
bind(mainMod .. " + N", hl.dsp.exec_cmd(shell .. "notifications toggle"), "Toggle the notification center")
bind(mainMod .. " + C", hl.dsp.exec_cmd(shell .. "controlcenter toggle"), "Toggle the control center")

-- Making it yours
bind(mainMod .. " + CTRL + W", hl.dsp.exec_cmd(shell .. "wallpaper toggle"), "Open the wallpaper selector")
bind(mainMod .. " + CTRL + G", hl.dsp.exec_cmd(shell .. "sddm toggle"), "Open the SDDM theme selector")
bind(mainMod .. " + CTRL + K", hl.dsp.exec_cmd(shell .. "keybindings toggle"), "Show all keybindings")

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
bind(mainMod .. " + F", hl.dsp.window.float({ action = "toggle" }), "Toggle floating mode for the focused window")
bind("F11", hl.dsp.window.fullscreen(), "Toggle fullscreen mode", { locked = true, repeating = true })
bind(mainMod .. " + S", hl.dsp.layout("togglesplit"), "Toggle the split direction")

-- Vim-style arrows, shifted one key right on AZERTY (see keyboard_state.lua)
bind(mainMod .. " + " .. keyboard.left, hl.dsp.focus({ direction = "l" }), "Focus the window on the left")
bind(mainMod .. " + " .. keyboard.right, hl.dsp.focus({ direction = "r" }), "Focus the window on the right")
bind(mainMod .. " + " .. keyboard.up, hl.dsp.focus({ direction = "u" }), "Focus the window above")
bind(mainMod .. " + " .. keyboard.down, hl.dsp.focus({ direction = "d" }), "Focus the window below")

-- Add Shift to move the window instead
bind(mainMod .. " + SHIFT + " .. keyboard.left, move_active_window_or_dispatch("l", { x = -30, y = 0 }),
  "Move the active window left", { repeating = true })
bind(mainMod .. " + SHIFT + " .. keyboard.right, move_active_window_or_dispatch("r", { x = 30, y = 0 }),
  "Move the active window right", { repeating = true })
bind(mainMod .. " + SHIFT + " .. keyboard.up, move_active_window_or_dispatch("u", { x = 0, y = -30 }),
  "Move the active window up", { repeating = true })
bind(mainMod .. " + SHIFT + " .. keyboard.down, move_active_window_or_dispatch("d", { x = 0, y = 30 }),
  "Move the active window down", { repeating = true })

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

-- Scroll through the workspaces in use
bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "Switch to the next workspace")
bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), "Switch to the previous workspace")

-------------
-- SESSION --
-------------

bind(mainMod .. " + CTRL + l", hl.dsp.exec_cmd(shell .. "lock lock"), "Lock the screen")
bind(mainMod .. " + Escape", hl.dsp.exec_cmd(shell .. "session toggle"),
  "Open the session menu (lock, logout, reboot, shutdown)")

-- Upkeep: restart what misbehaves, update everything
bind(mainMod .. " + ALT + Q", hl.dsp.exec_cmd("killall qs ; qs -c hyprpunk"), "Reload Quickshell")
bind(mainMod .. " + ALT + I", hl.dsp.exec_cmd("killall hypridle ; hypridle"), "Reload Hypridle")
bind(mainMod .. " + U", hl.dsp.exec_cmd("kitty -e yay -Syu --noconfirm --removemake"), "Update all packages")

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
  "Mute or unmute the audio output", { locked = true, repeating = true })
bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
  "Mute or unmute the microphone", { locked = true, repeating = true })

-- Screen and touchpad
bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -c backlight -q set 5%+"),
  "Increase the screen brightness", { locked = true, repeating = true })
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -c backlight -q set 5%-"),
  "Decrease the screen brightness", { locked = true, repeating = true })
bind("XF86TouchpadToggle", hl.dsp.exec_cmd("~/Scripts/touchpadctl.sh toggle"),
  "Enable or disable the touchpad", { locked = true, repeating = true })

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

-- The same for keyboards without them, plus shuffle
bind(mainMod .. " + SHIFT + CTRL + K", hl.dsp.exec_cmd("playerctl play-pause"), "Toggle media playback",
  { locked = true })
bind(mainMod .. " + SHIFT + CTRL + M", hl.dsp.exec_cmd(nextTrack), "Play the next track", { locked = true })
bind(mainMod .. " + SHIFT + CTRL + J", hl.dsp.exec_cmd(previousTrack), "Play the previous track", { locked = true })
bind(mainMod .. " + SHIFT + CTRL + L", hl.dsp.exec_cmd("playerctl shuffle toggle"), "Toggle shuffle mode",
  { locked = true })
