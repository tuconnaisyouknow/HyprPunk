-- Where your own apps open, read after rules.lua so a second rule for the same app wins.
-- install.sh copies this example into ~/.config/hypr/personal/ once; edit that copy.
-- Uncomment what you want, it all does nothing as it stands.

-- An app's class is what `hyprctl clients` shows for its window
-- hyprpunk.app("org.gnome.Geary", 6)
-- hyprpunk.app("discord", 7)

-- An app whose dialogs get tiled, cut off or blurred past their edges: they float, its
-- main window stays tiled. Its title is the initialTitle `hyprctl clients` shows for it
-- hyprpunk.float_dialogs("^my-app$", "^My App$")

-- Any other window rule works too
-- hl.window_rule({ match = { class = "pavucontrol" }, float = true })
