-- Your own shortcuts, read after keybindings.lua. Every one needs a description,
-- which is what the shell's keybindings panel (Super+Ctrl+K) shows.
-- install.sh copies this example into ~/.config/hypr/personal/ once; edit that copy.
-- Uncomment what you want, it all does nothing as it stands.

-- Swap an app and what opens it follows (terminal, editor, files, browser, music)
-- hyprpunk.programs.music = "spotifast"

-- A new shortcut
-- hyprpunk.bind("SUPER + G", hl.dsp.exec_cmd("gimp"), "Open GIMP")

-- A shortcut that's taken already: rebind it rather than bind, or both would run
-- hyprpunk.rebind("SUPER + B", hl.dsp.exec_cmd("brave --incognito"), "Open a private window")

-- Free a shortcut you don't want, written the way keybindings.lua writes it
-- hyprpunk.unbind("SUPER + D")
