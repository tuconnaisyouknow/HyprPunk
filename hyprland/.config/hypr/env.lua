-- The environment every app started from the session inherits: language, cursor,
-- Wayland hints for GTK and Qt, and your editor. Loaded by hyprland.lua.

---------------------------
-- ENVIRONMENT VARIABLES --
---------------------------

-- Language for the interface, regional formats (dates, numbers, money) for the rest,
-- both picked from the shell and saved in ~/.local/state/hyprpunk
local locale = __require("locale_state")
hl.env("LANG", locale.language)
hl.env("LC_MESSAGES", locale.language)
for _, variable in ipairs({
  "LC_CTYPE", "LC_NUMERIC", "LC_TIME", "LC_COLLATE", "LC_MONETARY", "LC_PAPER",
  "LC_NAME", "LC_ADDRESS", "LC_TELEPHONE", "LC_MEASUREMENT", "LC_IDENTIFICATION",
}) do
  hl.env(variable, locale.regional)
end

-- Rosé Pine cursor, for X11 and Wayland apps alike
hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "BreezeX-RosePine-Linux")
hl.env("HYPRCURSOR_THEME", "rose-pine-hyprcursor")
hl.env("HYPRCURSOR_SIZE", "24")

-- Tell GTK and Qt apps they're on Wayland, under Hyprland, with the Qt theme from qt5ct/qt6ct
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_CURRENT_SESSION", "Hyprland")
hl.env("XDG_MENU_PREFIX", "mate-") -- Borrow MATE's app menu so Dolphin's "Open with" isn't empty
hl.env("GDK_SCALE", "1")
hl.env("GDK_BACKEND", "wayland")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct:qt6ct")

-- Everyday tools
hl.env("EDITOR", "nvim")
