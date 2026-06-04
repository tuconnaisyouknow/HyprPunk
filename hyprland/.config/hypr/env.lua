-- #############################
-- ### ENVIRONMENT VARIABLES ###
-- #############################

-- Locale
hl.env("LC_CTYPE", "fr_FR.UTF-8")
hl.env("LC_NUMERIC", "fr_FR.UTF-8")
hl.env("LC_TIME", "fr_FR.UTF-8")
hl.env("LC_COLLATE", "fr_FR.UTF-8")
hl.env("LC_MONETARY", "fr_FR.UTF-8")
hl.env("LC_MESSAGES", "en_US.UTF-8")
hl.env("LC_PAPER", "fr_FR.UTF-8")
hl.env("LC_NAME", "fr_FR.UTF-8")
hl.env("LC_ADDRESS", "fr_FR.UTF-8")
hl.env("LC_TELEPHONE", "fr_FR.UTF-8")
hl.env("LC_MEASUREMENT", "fr_FR.UTF-8")
hl.env("LC_IDENTIFICATION", "fr_FR.UTF-8")

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
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
hl.env("QT_STYLE_OVERRIDE", "kvantum")
hl.env("DISPLAY", ":1")

-- Utils
hl.env("EDITOR", "nvim")
