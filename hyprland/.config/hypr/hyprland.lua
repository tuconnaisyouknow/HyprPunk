-- ###############
-- ### SOURCES ###
-- ###############

local colors = require("mocha") -- Color theme
require("monitors")             -- Monitors config
require("keybindings")          -- Keybindings
require("env")                  -- Environement variables
require("touchpad")             -- Touchpad toogle conf
pcall(require, "personal")      -- OPTIONAL (if you don't need a ~/.config/hypr/personal.lua file you can remove this line)

-- #################
-- ### AUTOSTART ###
-- #################

hl.on("hyprland.start", function()
  -- Exporting the Wayland session environment before starting user services
  hl.exec_cmd("dbus-update-activation-environment --systemd --all")

  -- Starting essential hyprland programs
  hl.exec_cmd("hyprpaper")
  hl.exec_cmd("waybar")
  hl.exec_cmd("hypridle")

  -- Starting network and bluetooth applets
  hl.exec_cmd("nm-applet")
  hl.exec_cmd("blueman-applet")

  -- Starting swaync and swayosd servers for notifications and OSD
  hl.exec_cmd("systemctl --user restart swaync.service")
  hl.exec_cmd("swayosd-server")

  -- Stopping bluetooth by default on startup
  hl.exec_cmd("bluetoothctl power off")

  -- Starting battery moniroring script to notify when the battery is under 20% of charge
  hl.exec_cmd("~/Scripts/battery-monitor.sh")

  -- Starting clipboard monitoring to store clipboard history
  hl.exec_cmd("wl-paste --watch cliphist store")

  -- Starting xwayland-satellite instead of XWayland
  hl.exec_cmd("systemctl --user restart xwayland-satellite.service")

  -- Starting gnome keyring for some applications
  hl.exec_cmd("/usr/bin/gnome-keyring-daemon --start --components=secrets,pkcs11,ssh")
end)

-- ##################
-- ### WORKSPACES ###
-- ##################

-- Monitors
hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-1" }) -- Assign workspace 1 to the first monitor
hl.workspace_rule({ workspace = "2", monitor = "eDP-1" })    -- Assign workspace 2 to the laptop monitor
hl.workspace_rule({ workspace = "5", monitor = "eDP-1" })    -- Assign workspace 5 to the laptop monitor

-- ####################
-- ### WINDOW RULES ###
-- ####################

-- Applications
hl.window_rule({ match = { class = "brave-browser" }, workspace = "2" })                -- Assign Brave to workspace 2
hl.window_rule({ match = { class = "Spotify" }, workspace = "3" })                      -- Assign Spotify to workspace 3
hl.window_rule({ match = { class = "obsidian" }, workspace = "4" })                     -- Assign Obsidian to workspace 4
hl.window_rule({ match = { class = "discord" }, workspace = "5" })                      -- Assign Discord to workspace 5
hl.window_rule({ match = { class = "thunar" }, workspace = "6" })                       -- Assign Thunar to workspace 6
hl.window_rule({ match = { class = "teams-for-linux" }, workspace = "6" })              -- Assign Teams to workspace 6
hl.window_rule({ match = { class = "gns3" }, workspace = "7" })                         -- Assign GNS3 to workspace 7
hl.window_rule({ match = { class = "virt-manager" }, workspace = "9" })                 -- Assign Virtual Machine Manager to workspace 9
hl.window_rule({ match = { class = "org.qbittorrent.qBittorrent" }, workspace = "10" }) -- Assign qBittorrent to workspace 10

-- Making satty windows float
hl.window_rule({ match = { class = "com.gabm.satty" }, float = true })

-- Centering floating windows
hl.window_rule({ match = { float = true }, center = true }) -- Center all floating windows

-- ###################
-- ### LAYER RULES ###
-- ###################

hl.layer_rule({ match = { namespace = "swaync-control-center" }, blur = true, ignore_alpha = 0.35 })
hl.layer_rule({ match = { namespace = "swaync-notification-window" }, blur = true, ignore_alpha = 0.35 })

-- #####################
-- ### LOOK AND FEEL ###
-- #####################

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
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

hl.config({
  dwindle = {
    preserve_split = true, -- You probably want this
  },
})

hl.config({
  master = {
    new_status = "master",
  },
})

hl.config({
  misc = {
    force_default_wallpaper = -1, -- Set to 0 or 1 to disable the anime mascot wallpapers
    disable_hyprland_logo = true, -- If true disables the random hyprland logo / anime girl background. :(
  },
})

-- #############
-- ### INPUT ###
-- #############

hl.config({
  input = {
    kb_layout = "fr",
    kb_variant = "",
    kb_model = "",
    kb_options = "",
    kb_rules = "",

    follow_mouse = 1,

    sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

    touchpad = {
      natural_scroll = false,
      disable_while_typing = true,
    },
  },
})

hl.device({
  name = "epic-mouse-v1",
  sensitivity = -0.5,
})

-- ##############################
-- ### WINDOWS AND WORKSPACES ###
-- ##############################

-- Ignore maximize requests from apps. You'll probably like this.
hl.window_rule({
  name = "suppress-maximize-events",
  match = { class = ".*" },
  suppress_event = "maximize",
})

-- Fix some dragging issues with XWayland
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
