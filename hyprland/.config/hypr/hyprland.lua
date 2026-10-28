-------------
-- SOURCES --
-------------

local colors = require("mocha")              -- Catppuccin Mocha palette
local keyboard = __require("keyboard_state") -- Keyboard layout, reloaded when you switch it
package.loaded["glass_state"] = nil          -- Glass style, read again on every reload
local linked, glass = pcall(__require, "glass_state")
-- Classic until glass_state.lua is linked, so a git pull without stow can't break the config
if not linked then
  glass = { liquid = false, ignore_alpha = 0.5 }
end
pcall(require, "personal")                   -- Your own tweaks in ~/.config/hypr/personal.lua, skipped if it doesn't exist
require("monitors")                          -- Screens
require("keybindings")                       -- Shortcuts
require("env")                               -- Environment variables
require("touchpad")                          -- Touchpad on/off toggle
require("workspaces")                        -- Which workspace lives on which screen, per machine

---------------
-- AUTOSTART --
---------------

hl.on("hyprland.start", function()
  -- Hand the Wayland session over to systemd first, so the user services see it
  hl.exec_cmd("dbus-update-activation-environment --systemd --all")

  -- The desktop itself: screens, touchpad, wallpaper, the shell and idle handling
  hl.exec_cmd("~/Scripts/displayctl.sh bootstrap")
  hl.exec_cmd("~/Scripts/touchpadctl.sh sync")
  -- awww-daemon forgets the last wallpaper, so wallpaperctl.sh puts it back
  hl.exec_cmd("awww-daemon")
  hl.exec_cmd("~/Scripts/wallpaperctl.sh apply")
  hl.exec_cmd("qs -c hyprpunk")
  hl.exec_cmd("hypridle")

  -- Bluetooth stays off until you actually need it
  hl.exec_cmd("bluetoothctl power off")

  -- Clipboard history, text and images alike (images feed the shell's thumbnails)
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")

  -- X11 apps go through xwayland-satellite rather than Hyprland's XWayland
  hl.exec_cmd("systemctl --user restart xwayland-satellite.service")

  -- Keyring for the apps that store passwords and SSH keys
  hl.exec_cmd("/usr/bin/gnome-keyring-daemon --start --components=secrets,pkcs11,ssh")

  -- Polkit agent, so password prompts show up as a window
  hl.exec_cmd("systemctl --user start hyprpolkitagent")
end)

-- A screen gets plugged in: set it up (screens already configured keep their settings)
hl.on("monitor.added", function()
  hl.exec_cmd("~/Scripts/displayctl.sh sync")
  -- Give awww a second to notice the new screen, otherwise it stays blank
  hl.exec_cmd("sleep 1; ~/Scripts/wallpaperctl.sh apply")
end)

-- A screen goes away: rearrange the ones left, the saved layout comes back on reconnect
hl.on("monitor.removed", function()
  hl.exec_cmd("~/Scripts/displayctl.sh reflow")
end)

------------------
-- WINDOW RULES --
------------------

-- Every app has its home
hl.window_rule({ match = { class = "kitty" }, workspace = "1" })
hl.window_rule({ match = { class = "brave-browser" }, workspace = "2" })
hl.window_rule({ match = { class = "Spotify" }, workspace = "3" })
hl.window_rule({ match = { class = "md.obsidian.Obsidian" }, workspace = "4" })
hl.window_rule({ match = { class = "discord" }, workspace = "5" })
hl.window_rule({ match = { class = "Element" }, workspace = "5" })
hl.window_rule({ match = { class = "org.kde.dolphin" }, workspace = "6" })

-- Bitwarden's little popup is its own Chromium app: float it so it doesn't cut Brave in half
hl.window_rule({ match = { class = "brave-nngceckbapebfimnlniiiahkandclblb-Default" }, float = true })

-- Floating windows open in the middle of the screen
hl.window_rule({ match = { float = true }, center = true })

--------------
-- GESTURES --
--------------

-- Three fingers sideways to change workspace
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Four fingers to drag a window around
hl.gesture({ fingers = 4, direction = "swipe", action = "move" })

-----------------
-- LAYER RULES --
-----------------

-- The shell's see-through panels: blur only what is drawn, not the empty space around it
hl.layer_rule({ match = { namespace = "hyprpunk-notifications" }, blur = true, ignore_alpha = glass.ignore_alpha })
hl.layer_rule({ match = { namespace = "hyprpunk-notification-center" }, blur = true, ignore_alpha = glass.ignore_alpha })
hl.layer_rule({ match = { namespace = "hyprpunk-osd" }, blur = true, ignore_alpha = glass.ignore_alpha })
hl.layer_rule({ match = { namespace = "hyprpunk-control-center" }, blur = true, ignore_alpha = glass.ignore_alpha })
hl.layer_rule({ match = { namespace = "hyprpunk-tray" }, blur = true, blur_popups = true, ignore_alpha = glass.ignore_alpha })
-- The island's panels (session menu, wallpaper picker) bring their own animation
hl.layer_rule({ match = { namespace = "hyprpunk-island" }, blur = true, ignore_alpha = glass.ignore_alpha, no_anim = true })
-- Screenshot selection appears right away over the frozen screen, no fade
hl.layer_rule({ match = { namespace = "hyprpunk-screenshot" }, no_anim = true })
-- In the classic style the bar's pills are opaque, so the blur only shows behind the island and the player
hl.layer_rule({ match = { namespace = "hyprpunk-bar" }, blur = true, blur_popups = true, ignore_alpha = glass.ignore_alpha })

-------------------
-- LOOK AND FEEL --
-------------------

hl.config({
  general = {
    gaps_in = 5,
    gaps_out = 10,

    border_size = 2,

    col = {
      active_border = colors.mauve,
      inactive_border = colors.lavender,
    },

    resize_on_border = false,

    allow_tearing = false,

    layout = "dwindle",
  },
})

hl.config({
  decoration = {
    rounding = 5,
    rounding_power = 2,

    -- Slightly see-through, so the wallpaper shows behind the blur
    active_opacity = 0.9,
    inactive_opacity = 0.9,

    shadow = {
      enabled = true,
      range = 4,
      render_power = 3,
      color = "rgba(1a1a1aee)",
    },

    blur = {
      enabled = true,
      size = 1,
      passes = 4,
      contrast = 1.1,
      brightness = 1.1,
      vibrancy = 0.2,
      vibrancy_darkness = 0.2,
      noise = 0.03,
      ignore_opacity = true,
    },
  },
})

hl.config({
  animations = {
    enabled = true,
  },
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1.0 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

-- Snappy on the way in, quicker on the way out
hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
-- Popups close at once. The shell already folds its cards back into their pill, and
-- Hyprland's fade, drawn without the blur, flashed the liquid glass darker after it
hl.animation({ leaf = "fadePopupsOut", enabled = false })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

hl.config({
  dwindle = {
    preserve_split = true, -- A split keeps its direction when windows come and go
  },
})

hl.config({
  master = {
    new_status = "master",
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

-----------
-- INPUT --
-----------

hl.config({
  input = {
    kb_layout = keyboard.xkb,
    kb_variant = "",
    kb_model = "",
    kb_options = "",
    kb_rules = "",

    follow_mouse = 1, -- Focus follows the mouse

    sensitivity = 0, -- From -1.0 to 1.0, 0 leaves the mouse as it is

    touchpad = {
      natural_scroll = false,
      disable_while_typing = true,
    },
  },
})

----------------------------
-- WINDOWS AND WORKSPACES --
----------------------------

-- Apps don't get to maximize themselves, the layout decides
hl.window_rule({
  name = "suppress-maximize-events",
  match = { class = ".*" },
  suppress_event = "maximize",
})

-- Invisible XWayland windows (drag and drop helpers) shouldn't steal focus
hl.window_rule({
  name = "fix-drag-xwayland",
  match = {
    class = "^$",
    title = "^$",
    xwayland = true,
    float = true,
    fullscreen = true,
    pin = true,
  },
  no_focus = true,
})
