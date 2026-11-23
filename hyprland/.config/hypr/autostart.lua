-- What starts with Hyprland (the shell, the wallpaper, idle handling, the X11 server…)
-- and what runs when a screen is plugged in or unplugged. Loaded by hyprland.lua,
-- before your personal/autostart.lua.

--------------
-- X11 APPS --
--------------

-- X11 apps go through xwayland-satellite alone: Hyprland's own XWayland lines the screens
-- up left to right for them, so their menus open on the wrong spot when yours aren't
-- laid out that way. With both running they fought over the same display. HyprPunk
-- builds satellite with a patch (satellite/) that leaves the windows' size to Hyprland.
hl.config({
  xwayland = {
    enabled = false,
  },
})

-- SDDM's login screen keeps :0 for itself, so satellite gets a set display rather
-- than whichever is free first. Apps learn it at start (see below): with its own
-- XWayland off, Hyprland clears DISPLAY while starting, after the config set it.
local x11Display = ":1"

---------------
-- AUTOSTART --
---------------

-- Each one named, so personal/autostart.lua can drop one with hyprpunk.autostart.remove("bluetooth")
local startup = {
  -- Hand the Wayland session over to systemd first, so the user services see it
  { name = "systemd",          command = "dbus-update-activation-environment --systemd --all" },

  -- The desktop itself: screens, touchpad, wallpaper, the shell and idle handling
  { name = "displays",         command = hyprpunk.scripts .. "/displayctl.sh sync" },
  { name = "touchpad",         command = hyprpunk.scripts .. "/touchpadctl.sh sync" },
  -- awww-daemon forgets the last wallpaper, so wallpaperctl.sh puts it back
  { name = "wallpaper-daemon", command = "awww-daemon" },
  { name = "wallpaper",        command = hyprpunk.scripts .. "/wallpaperctl.sh apply" },
  { name = "shell",            command = "qs -c hyprpunk" },
  { name = "idle",             command = "hypridle" },
  -- Your Documents, Pictures… folders, in English so screenshots land next to the
  -- wallpapers. xdg-user-dirs' own service waits for a systemd target Hyprland never reaches.
  { name = "user-dirs",        command = "LC_ALL=C xdg-user-dirs-update" },

  -- Bluetooth stays off until you need it
  { name = "bluetooth",        command = "bluetoothctl power off" },

  -- Clipboard history, text and images alike, kept or not as the settings say. Text is
  -- asked for as plain UTF-8: any other text type (a browser's UTF-16 link, its HTML)
  -- would come back as data nothing can paste.
  { name = "clipboard-text",   command = "wl-paste --type 'text/plain;charset=utf-8' --watch " .. hyprpunk.scripts .. "/historyctl.sh store text" },
  { name = "clipboard-images", command = "wl-paste --type image --watch " .. hyprpunk.scripts .. "/historyctl.sh store image" },

  -- X11 apps, since Hyprland's own XWayland is off (see above)
  { name = "xwayland",         command = "xwayland-satellite " .. x11Display },

  -- Keyring for the apps that store passwords and SSH keys
  { name = "keyring",          command = "/usr/bin/gnome-keyring-daemon --start --components=secrets,pkcs11,ssh" },

  -- A notification when HyprPunk has an update, once per session
  { name = "update-check",     command = hyprpunk.scripts .. "/update-notify.sh" },
}

-- The list only runs once the whole config is read, so your additions and removals count
hyprpunk.autostart = {
  -- The name is only needed to remove it later, it's the command by default
  add = function(command, name)
    table.insert(startup, { name = name or command, command = command })
  end,
  remove = function(name)
    for index, entry in ipairs(startup) do
      if entry.name == name then
        table.remove(startup, index)
        return
      end
    end
    error("no autostart entry named " .. name)
  end,
}

hl.on("hyprland.start", function()
  hl.env("DISPLAY", x11Display)
  for _, entry in ipairs(startup) do
    hl.exec_cmd(entry.command)
  end
end)

-- A screen gets plugged in: set it up (screens already configured keep their settings)
hl.on("monitor.added", function()
  hl.exec_cmd(hyprpunk.scripts .. "/displayctl.sh sync")
  -- Give awww a second to notice the new screen, otherwise it stays blank
  hl.exec_cmd("sleep 1; " .. hyprpunk.scripts .. "/wallpaperctl.sh apply")
end)

-- A screen goes away: rearrange the ones left, the saved layout comes back on reconnect
hl.on("monitor.removed", function()
  hl.exec_cmd(hyprpunk.scripts .. "/displayctl.sh reflow")
end)
