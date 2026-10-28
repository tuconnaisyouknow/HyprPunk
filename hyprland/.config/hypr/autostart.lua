-- What starts with Hyprland (the shell, the wallpaper, idle handling…) and what runs
-- when a screen is plugged in or unplugged. Loaded by hyprland.lua.

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
