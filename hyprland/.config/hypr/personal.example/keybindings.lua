-- Your own shortcuts, read after keybindings.lua. Every one needs a description,
-- which is what the shell's keybindings panel (Super+Ctrl+K) shows.
-- install.sh copies this example into ~/.config/hypr/personal/ once; edit that copy.
-- Uncomment what you want, it all does nothing as it stands.

-- Swap an app and the shortcut that opens it follows (terminal, files, browser, notes,
-- music and chat)
-- hyprpunk.programs.music = "spicetify auto"

-- A new shortcut
-- hyprpunk.bind("SUPER + G", hl.dsp.exec_cmd("gimp"), "Open GIMP")

-- A shortcut that's taken already: rebind it rather than bind, or both would run
-- hyprpunk.rebind("SUPER + O", hl.dsp.exec_cmd("kitty -e nvim ~/Notes"), "Open the notes")

-- Free a shortcut you don't want, written the way keybindings.lua writes it
-- hyprpunk.unbind("SUPER + D")
