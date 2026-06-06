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

local function bind(keys, dispatcher, description, opts)
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

local launcher = "launcher"
local utilities = "utilites"
local windowManagement = "window management"
local workspaces = "workspaces"
local hardwareControls = "hardware controls"

bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal), "[" .. launcher .. "|apps] open terminal")
bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager), "[" .. launcher .. "|apps] open file manager")
bind(mainMod .. " + O", hl.dsp.exec_cmd(notepad), "[" .. launcher .. "|apps] open notepad")
bind(mainMod .. " + C", hl.dsp.exec_cmd(codeEditor), "[" .. launcher .. "|apps] open code editor")
bind(mainMod .. " + B", hl.dsp.exec_cmd(browser), "[" .. launcher .. "|apps] open browser")
bind(mainMod .. " + P", hl.dsp.exec_cmd(music), "[" .. launcher .. "|apps] open spotify")
bind(mainMod .. " + D", hl.dsp.exec_cmd("discord"), "[" .. launcher .. "|apps] open discord")

bind("ALT + SPACE", hl.dsp.exec_cmd(menu), "[" .. launcher .. "|rofi menus] open app menu")
bind("CTRL + ALT + SPACE", hl.dsp.exec_cmd("~/Scripts/Rofi/menu.sh"), "[" .. launcher .. "|rofi menus] open global menu")
bind("CTRL + ugrave", hl.dsp.exec_cmd("~/Scripts/Rofi/cliphist.sh standalone"),
  "[" .. launcher .. "|rofi menus] open clipboard history")
bind(mainMod .. " + CTRL + W", hl.dsp.exec_cmd("~/Scripts/Rofi/wallpaper.sh standalone"),
  "[" .. launcher .. "|rofi menus] open wallpaper selector")
bind(mainMod .. " + semicolon",
  hl.dsp.exec_cmd(
    'rofi -modi emoji -show emoji -theme ~/.config/rofi/catppuccin-list.rasi -display-emoji "󰱨 Emoji " -kb-accept-entry "" -kb-custom-1 Return'),
  "[" .. launcher .. "|rofi menus] open emoji selector")

bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region -o ~/Pictures/Screenshots"),
  "[" .. utilities .. "|screen capture] region screenshot")
bind(mainMod .. " + CTRL + S", hl.dsp.exec_cmd("hyprshot -m region --raw | satty --filename -"),
  "[" .. utilities .. "|screen capture] annotate screenshot")
bind("Print", hl.dsp.exec_cmd("hyprshot -m active -m output -o ~/Pictures/Screenshots"),
  "[" .. utilities .. "|screen capture] active monitor screenshot")
bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"), "[" .. utilities .. "|screen capture] color picker")
bind(mainMod .. " + N", hl.dsp.exec_cmd("swaync-client -t"), "[" .. utilities .. "|screen capture] toggle control center")

bind(mainMod .. " + Q", hl.dsp.window.close(), "[" .. windowManagement .. "] close focused window")
bind(mainMod .. " + F", hl.dsp.window.float({ action = "toggle" }), "[" .. windowManagement .. "] toogle float")
bind(mainMod .. " + S", hl.dsp.layout("togglesplit"), "[" .. windowManagement .. "] toggle split") -- dwindle
bind("F11", hl.dsp.window.fullscreen(), "[" .. windowManagement .. "] toogle fullscreen",
  { locked = true, repeating = true })
bind(mainMod .. " + CTRL + l", hl.dsp.exec_cmd("hyprlock"), "[" .. windowManagement .. "] lock screen")
bind(mainMod .. " + ALT + W", hl.dsp.exec_cmd("killall waybar ; waybar"), "[" .. windowManagement .. "] reload waybar")
bind(mainMod .. " + ALT + I", hl.dsp.exec_cmd("killall hypridle ; hypridle"),
  "[" .. windowManagement .. "] reload hypridle")

bind(mainMod .. " + j", hl.dsp.focus({ direction = "l" }), "[" .. windowManagement .. "|change focus] move focus left")
bind(mainMod .. " + m", hl.dsp.focus({ direction = "r" }), "[" .. windowManagement .. "|change focus] move focus right")
bind(mainMod .. " + l", hl.dsp.focus({ direction = "u" }), "[" .. windowManagement .. "|change focus] move focus up")
bind(mainMod .. " + k", hl.dsp.focus({ direction = "d" }), "[" .. windowManagement .. "|change focus] move focus down")

bind(mainMod .. " + SHIFT + j", move_active_window_or_dispatch("l", { x = -30, y = 0 }),
  "[" .. windowManagement .. "|Move active window across workspace] move activewindow to the left", { repeating = true })
bind(mainMod .. " + SHIFT + m", move_active_window_or_dispatch("r", { x = 30, y = 0 }),
  "[" .. windowManagement .. "|Move active window across workspace] move activewindow to the right", { repeating = true })
bind(mainMod .. " + SHIFT + l", move_active_window_or_dispatch("u", { x = 0, y = -30 }),
  "[" .. windowManagement .. "|Move active window across workspace] move activewindow up", { repeating = true })
bind(mainMod .. " + SHIFT + k", move_active_window_or_dispatch("d", { x = 0, y = 30 }),
  "[" .. windowManagement .. "|Move active window across workspace] move activewindow down", { repeating = true })

bind(mainMod .. " + code:10", hl.dsp.focus({ workspace = 1 }),
  "[" .. workspaces .. "|navigation] navigate to workspace 1")
bind(mainMod .. " + code:11", hl.dsp.focus({ workspace = 2 }),
  "[" .. workspaces .. "|navigation] navigate to workspace 2")
bind(mainMod .. " + code:12", hl.dsp.focus({ workspace = 3 }),
  "[" .. workspaces .. "|navigation] navigate to workspace 3")
bind(mainMod .. " + code:13", hl.dsp.focus({ workspace = 4 }),
  "[" .. workspaces .. "|navigation] navigate to workspace 4")
bind(mainMod .. " + code:14", hl.dsp.focus({ workspace = 5 }),
  "[" .. workspaces .. "|navigation] navigate to workspace 5")
bind(mainMod .. " + code:15", hl.dsp.focus({ workspace = 6 }),
  "[" .. workspaces .. "|navigation] navigate to workspace 6")
bind(mainMod .. " + code:16", hl.dsp.focus({ workspace = 7 }),
  "[" .. workspaces .. "|navigation] navigate to workspace 7")
bind(mainMod .. " + code:17", hl.dsp.focus({ workspace = 8 }),
  "[" .. workspaces .. "|navigation] navigate to workspace 8")
bind(mainMod .. " + code:18", hl.dsp.focus({ workspace = 9 }),
  "[" .. workspaces .. "|navigation] navigate to workspace 9")
bind(mainMod .. " + code:19", hl.dsp.focus({ workspace = 10 }),
  "[" .. workspaces .. "|navigation] navigate to workspace 10")

bind(mainMod .. " + SHIFT + code:10", hl.dsp.window.move({ workspace = 1 }),
  "[" .. workspaces .. "|move window to a workspace] move to workspace 1")
bind(mainMod .. " + SHIFT + code:11", hl.dsp.window.move({ workspace = 2 }),
  "[" .. workspaces .. "|move window to a workspace] move to workspace 2")
bind(mainMod .. " + SHIFT + code:12", hl.dsp.window.move({ workspace = 3 }),
  "[" .. workspaces .. "|move window to a workspace] move to workspace 3")
bind(mainMod .. " + SHIFT + code:13", hl.dsp.window.move({ workspace = 4 }),
  "[" .. workspaces .. "|move window to a workspace] move to workspace 4")
bind(mainMod .. " + SHIFT + code:14", hl.dsp.window.move({ workspace = 5 }),
  "[" .. workspaces .. "|move window to a workspace] move to workspace 5")
bind(mainMod .. " + SHIFT + code:15", hl.dsp.window.move({ workspace = 6 }),
  "[" .. workspaces .. "|move window to a workspace] move to workspace 6")
bind(mainMod .. " + SHIFT + code:16", hl.dsp.window.move({ workspace = 7 }),
  "[" .. workspaces .. "|move window to a workspace] move to workspace 7")
bind(mainMod .. " + SHIFT + code:17", hl.dsp.window.move({ workspace = 8 }),
  "[" .. workspaces .. "|move window to a workspace] move to workspace 8")
bind(mainMod .. " + SHIFT + code:18", hl.dsp.window.move({ workspace = 9 }),
  "[" .. workspaces .. "|move window to a workspace] move to workspace 9")
bind(mainMod .. " + SHIFT + code:19", hl.dsp.window.move({ workspace = 10 }),
  "[" .. workspaces .. "|move window to a workspace] move to workspace 10")

-- Example special workspace (scratchpad)
-- hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
-- hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "[" .. workspaces .. "|navigation] next workspace")
bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }),
  "[" .. workspaces .. "|navigation] previous workspace")

-- Move/resize windows with mainMod + LMB/RMB and dragging
bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), "[" .. workspaces .. "|navigation] hold to move window",
  { mouse = true })
bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), "[" .. workspaces .. "|navigation] hold to resize window",
  { mouse = true })

bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("swayosd-client --output-volume raise"),
  "[" .. hardwareControls .. "|audio] increase volume", { locked = true, repeating = true })
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("swayosd-client --output-volume lower"),
  "[" .. hardwareControls .. "|audio] decrease volume", { locked = true, repeating = true })
bind("XF86AudioMute", hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"),
  "[" .. hardwareControls .. "|audio] toogle mute volume", { locked = true, repeating = true })
bind("XF86AudioMicMute", hl.dsp.exec_cmd("swayosd-client --input-volume mute-toogle"),
  "[" .. hardwareControls .. "|audio] toogle mute microphone", { locked = true, repeating = true })
bind("XF86TouchpadToggle", hl.dsp.exec_cmd("~/Scripts/touchpad.sh"),
  "[" .. hardwareControls .. "|audio] toogle touchpad", { locked = true, repeating = true })

bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("swayosd-client --brightness raise"),
  "[" .. hardwareControls .. "|brightness] increase brightness", { locked = true, repeating = true })
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness lower"),
  "[" .. hardwareControls .. "|brightness] decrease brightness", { locked = true, repeating = true })

bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), "[" .. hardwareControls .. "|media] next media",
  { locked = true })
bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), "[" .. hardwareControls .. "|media] pause media",
  { locked = true })
bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), "[" .. hardwareControls .. "|media] play media",
  { locked = true })
bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), "[" .. hardwareControls .. "|media] previous media",
  { locked = true })
bind(mainMod .. " + SHIFT + CTRL + M", hl.dsp.exec_cmd("swayosd-client --playerctl next"),
  "[" .. hardwareControls .. "|media] next media", { locked = true })
bind(mainMod .. " + SHIFT + CTRL + K", hl.dsp.exec_cmd("swayosd-client --playerctl play-pause"),
  "[" .. hardwareControls .. "|media] pause media", { locked = true })
bind(mainMod .. " + SHIFT + CTRL + J", hl.dsp.exec_cmd("swayosd-client --playerctl prev"),
  "[" .. hardwareControls .. "|media] previous track", { locked = true })
bind(mainMod .. " + SHIFT + CTRL + L", hl.dsp.exec_cmd("swayosd-client --playerctl shuffle"),
  "[" .. hardwareControls .. "|media] shuffle", { locked = true })
