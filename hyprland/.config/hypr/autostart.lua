-- What starts with Hyprland (the shell, the wallpaper, idle handling…) and what runs
-- when a screen is plugged in or unplugged. Loaded by hyprland.lua, before your
-- personal/autostart.lua.

---------------
-- AUTOSTART --
---------------

-- Each one named, so personal/autostart.lua can drop one with hyprpunk.autostart.remove("bluetooth")
local startup = {
  -- Hand the Wayland session over to systemd first, so the user services see it
  { name = "systemd", command = "dbus-update-activation-environment --systemd --all" },

  -- The desktop itself: screens, touchpad, wallpaper, the shell and idle handling
  { name = "displays", command = "~/Scripts/displayctl.sh bootstrap" },
  { name = "touchpad", command = "~/Scripts/touchpadctl.sh sync" },
  -- awww-daemon forgets the last wallpaper, so wallpaperctl.sh puts it back
  { name = "wallpaper-daemon", command = "awww-daemon" },
  { name = "wallpaper", command = "~/Scripts/wallpaperctl.sh apply" },
  { name = "shell", command = "qs -c hyprpunk" },
  { name = "idle", command = "hypridle" },

  -- Bluetooth stays off until you actually need it
  { name = "bluetooth", command = "bluetoothctl power off" },

  -- Clipboard history, text and images alike (images feed the shell's thumbnails)
  { name = "clipboard-text", command = "wl-paste --type text --watch cliphist store" },
  { name = "clipboard-images", command = "wl-paste --type image --watch cliphist store" },

  -- X11 apps go through xwayland-satellite rather than Hyprland's XWayland
  { name = "xwayland", command = "systemctl --user restart xwayland-satellite.service" },

  -- Keyring for the apps that store passwords and SSH keys
  { name = "keyring", command = "/usr/bin/gnome-keyring-daemon --start --components=secrets,pkcs11,ssh" },

  -- Polkit agent, so password prompts show up as a window
  { name = "polkit", command = "systemctl --user start hyprpolkitagent" },
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
  for _, entry in ipairs(startup) do
    hl.exec_cmd(entry.command)
  end
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
