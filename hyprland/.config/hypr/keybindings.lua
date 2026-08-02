-- ###################
-- ### MY PROGRAMS ###
-- ###################

local terminal = "kitty"
local fileManager = "thunar"
local codeEditor = "code"
local notepad = "obsidian"
local menu = 'rofi -show drun -show-icons -display-drun " Apps "'
local browser = "brave"
local music = "spotify-launcher"

local keybindingActions = {}

function run_keybinding(description)
  local action = keybindingActions[description]
  assert(action ~= nil, "unknown keybinding: " .. description)

  if type(action) == "function" then
    action()
  else
    hl.dispatch(action)
  end
end

local function bind(keys, dispatcher, description, opts)
  assert(type(description) == "string" and description ~= "", "keybinding description is required")
  keybindingActions[description] = dispatcher
  opts = opts or {}
  opts.description = description
  return hl.bind(keys, dispatcher, opts)
end

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

-- ###################
-- ### KEYBINDINGS ###
-- ###################

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal), "Open the terminal")
bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager), "Open the file manager")
bind(mainMod .. " + O", hl.dsp.exec_cmd(notepad), "Open Obsidian")
bind(mainMod .. " + C", hl.dsp.exec_cmd(codeEditor), "Open the code editor")
bind(mainMod .. " + B", hl.dsp.exec_cmd(browser), "Open the web browser")
bind(mainMod .. " + P", hl.dsp.exec_cmd(music), "Open Spotify")
bind(mainMod .. " + D", hl.dsp.exec_cmd("discord"), "Open Discord")

bind("ALT + SPACE", hl.dsp.exec_cmd(menu), "Open the application launcher")
bind("CTRL + ALT + SPACE", hl.dsp.exec_cmd("~/Scripts/Rofi/menu.sh"), "Open the main Rofi menu")
bind("CTRL + ugrave", hl.dsp.exec_cmd("~/Scripts/Rofi/cliphist.sh standalone"),
  "Open the clipboard history")
bind(mainMod .. " + CTRL + W", hl.dsp.exec_cmd("~/Scripts/Rofi/wallpaper.sh standalone"),
  "Open the wallpaper selector")
bind(mainMod .. " + semicolon",
  hl.dsp.exec_cmd(
    'rofi -modi emoji -show emoji -theme ~/.config/rofi/catppuccin-list.rasi -display-emoji "󰱨 Emoji " -kb-accept-entry "" -kb-custom-1 Return'),
  "Open the emoji selector")
bind(mainMod .. " + CTRL + K", hl.dsp.exec_cmd("~/Scripts/Rofi/keybindings.sh standalone"),
  "Show all keybindings")

bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region -o ~/Pictures/Screenshots"),
  "Capture a screen region")
bind(mainMod .. " + CTRL + S", hl.dsp.exec_cmd("hyprshot -m region --raw | satty --filename -"),
  "Capture and annotate a screen region")
bind("Print", hl.dsp.exec_cmd("hyprshot -m active -m output -o ~/Pictures/Screenshots"),
  "Capture the active monitor")
bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"), "Pick a color from the screen")
bind(mainMod .. " + N", hl.dsp.exec_cmd("swaync-client -t"), "Toggle the notification center")

bind(mainMod .. " + Q", hl.dsp.window.close(), "Close the focused window")
bind(mainMod .. " + F", hl.dsp.window.float({ action = "toggle" }), "Toggle floating mode for the focused window")
bind(mainMod .. " + S", hl.dsp.layout("togglesplit"), "Toggle the split direction") -- dwindle
bind("F11", hl.dsp.window.fullscreen(), "Toggle fullscreen mode",
  { locked = true, repeating = true })
bind(mainMod .. " + CTRL + l", hl.dsp.exec_cmd("hyprlock"), "Lock the screen")
bind(mainMod .. " + ALT + W", hl.dsp.exec_cmd("killall waybar ; waybar"), "Reload Waybar")
bind(mainMod .. " + ALT + I", hl.dsp.exec_cmd("killall hypridle ; hypridle"),
  "Reload Hypridle")

bind(mainMod .. " + j", hl.dsp.focus({ direction = "l" }), "Focus the window on the left")
bind(mainMod .. " + m", hl.dsp.focus({ direction = "r" }), "Focus the window on the right")
bind(mainMod .. " + l", hl.dsp.focus({ direction = "u" }), "Focus the window above")
bind(mainMod .. " + k", hl.dsp.focus({ direction = "d" }), "Focus the window below")

bind(mainMod .. " + SHIFT + j", move_active_window_or_dispatch("l", { x = -30, y = 0 }),
  "Move the active window left", { repeating = true })
bind(mainMod .. " + SHIFT + m", move_active_window_or_dispatch("r", { x = 30, y = 0 }),
  "Move the active window right", { repeating = true })
bind(mainMod .. " + SHIFT + l", move_active_window_or_dispatch("u", { x = 0, y = -30 }),
  "Move the active window up", { repeating = true })
bind(mainMod .. " + SHIFT + k", move_active_window_or_dispatch("d", { x = 0, y = 30 }),
  "Move the active window down", { repeating = true })

bind(mainMod .. " + code:10", hl.dsp.focus({ workspace = 1 }),
  "Switch to workspace 1")
bind(mainMod .. " + code:11", hl.dsp.focus({ workspace = 2 }),
  "Switch to workspace 2")
bind(mainMod .. " + code:12", hl.dsp.focus({ workspace = 3 }),
  "Switch to workspace 3")
bind(mainMod .. " + code:13", hl.dsp.focus({ workspace = 4 }),
  "Switch to workspace 4")
bind(mainMod .. " + code:14", hl.dsp.focus({ workspace = 5 }),
  "Switch to workspace 5")
bind(mainMod .. " + code:15", hl.dsp.focus({ workspace = 6 }),
  "Switch to workspace 6")
bind(mainMod .. " + code:16", hl.dsp.focus({ workspace = 7 }),
  "Switch to workspace 7")
bind(mainMod .. " + code:17", hl.dsp.focus({ workspace = 8 }),
  "Switch to workspace 8")
bind(mainMod .. " + code:18", hl.dsp.focus({ workspace = 9 }),
  "Switch to workspace 9")
bind(mainMod .. " + code:19", hl.dsp.focus({ workspace = 10 }),
  "Switch to workspace 10")

bind(mainMod .. " + SHIFT + code:10", hl.dsp.window.move({ workspace = 1 }),
  "Move the focused window to workspace 1")
bind(mainMod .. " + SHIFT + code:11", hl.dsp.window.move({ workspace = 2 }),
  "Move the focused window to workspace 2")
bind(mainMod .. " + SHIFT + code:12", hl.dsp.window.move({ workspace = 3 }),
  "Move the focused window to workspace 3")
bind(mainMod .. " + SHIFT + code:13", hl.dsp.window.move({ workspace = 4 }),
  "Move the focused window to workspace 4")
bind(mainMod .. " + SHIFT + code:14", hl.dsp.window.move({ workspace = 5 }),
  "Move the focused window to workspace 5")
bind(mainMod .. " + SHIFT + code:15", hl.dsp.window.move({ workspace = 6 }),
  "Move the focused window to workspace 6")
bind(mainMod .. " + SHIFT + code:16", hl.dsp.window.move({ workspace = 7 }),
  "Move the focused window to workspace 7")
bind(mainMod .. " + SHIFT + code:17", hl.dsp.window.move({ workspace = 8 }),
  "Move the focused window to workspace 8")
bind(mainMod .. " + SHIFT + code:18", hl.dsp.window.move({ workspace = 9 }),
  "Move the focused window to workspace 9")
bind(mainMod .. " + SHIFT + code:19", hl.dsp.window.move({ workspace = 10 }),
  "Move the focused window to workspace 10")

bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "Switch to the next workspace")
bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }),
  "Switch to the previous workspace")

-- Move/resize windows with mainMod + LMB/RMB and dragging
bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), "Drag to move a window",
  { mouse = true })
bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), "Drag to resize a window",
  { mouse = true })

bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("swayosd-client --output-volume raise"),
  "Increase the output volume", { locked = true, repeating = true })
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("swayosd-client --output-volume lower"),
  "Decrease the output volume", { locked = true, repeating = true })
bind("XF86AudioMute", hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"),
  "Mute or unmute the audio output", { locked = true, repeating = true })
bind("XF86AudioMicMute", hl.dsp.exec_cmd("swayosd-client --input-volume mute-toogle"),
  "Mute or unmute the microphone", { locked = true, repeating = true })
bind("XF86TouchpadToggle", hl.dsp.exec_cmd("~/Scripts/touchpadctl.sh toggle"),
  "Enable or disable the touchpad", { locked = true, repeating = true })

bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("swayosd-client --brightness raise"),
  "Increase the screen brightness", { locked = true, repeating = true })
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness lower"),
  "Decrease the screen brightness", { locked = true, repeating = true })

bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), "Play the next track",
  { locked = true })
bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), "Toggle media playback",
  { locked = true })
bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), "Toggle media playback",
  { locked = true })
bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), "Play the previous track",
  { locked = true })
bind(mainMod .. " + SHIFT + CTRL + M", hl.dsp.exec_cmd("swayosd-client --playerctl next"),
  "Play the next track", { locked = true })
bind(mainMod .. " + SHIFT + CTRL + K", hl.dsp.exec_cmd("swayosd-client --playerctl play-pause"),
  "Toggle media playback", { locked = true })
bind(mainMod .. " + SHIFT + CTRL + J", hl.dsp.exec_cmd("swayosd-client --playerctl prev"),
  "Play the previous track", { locked = true })
bind(mainMod .. " + SHIFT + CTRL + L", hl.dsp.exec_cmd("swayosd-client --playerctl shuffle"),
  "Toggle shuffle mode", { locked = true })
