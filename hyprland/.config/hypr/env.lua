-- #############################
-- ### ENVIRONMENT VARIABLES ###
-- #############################

-- Locale
local locale = __require("locale_state")
hl.env("LANG", locale.language)
hl.env("LC_MESSAGES", locale.language)
hl.env("LC_CTYPE", locale.regional)
hl.env("LC_NUMERIC", locale.regional)
hl.env("LC_TIME", locale.regional)
hl.env("LC_COLLATE", locale.regional)
hl.env("LC_MONETARY", locale.regional)
hl.env("LC_PAPER", locale.regional)
hl.env("LC_NAME", locale.regional)
hl.env("LC_ADDRESS", locale.regional)
hl.env("LC_TELEPHONE", locale.regional)
hl.env("LC_MEASUREMENT", locale.regional)
hl.env("LC_IDENTIFICATION", locale.regional)

-- Cursor
hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "BreezeX-RosePine-Linux")
hl.env("HYPRCURSOR_THEME", "rose-pine-hyprcursor")
hl.env("HYPRCURSOR_SIZE", "24")

-- Desktop session and theme
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_CURRENT_SESSION", "Hyprland")
hl.env("GDK_SCALE", "1")
hl.env("GDK_BACKEND", "wayland")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct:qt6ct")
hl.env("DISPLAY", ":1")

-- Utils
hl.env("EDITOR", "nvim")
