import QtQuick
import Quickshell

// The main menu: a glass square per panel, with the selected one's name underneath.
// Picking one opens that panel, and Escape there comes back here.
IconMenu {
    id: menu

    // panel: the island panel opened on this screen.
    entries: [{
        "icon": "",
        "name": "Apps",
        "panel": "launcher"
    }, {
        "icon": "󰅌",
        "name": "Clipboard",
        "panel": "clipboard"
    }, {
        "icon": "󰱨",
        "name": "Emoji",
        "panel": "emoji"
    }, {
        "icon": "󰹑",
        "name": "Capture",
        "panel": "screenshot"
    }, {
        "icon": "󰌌",
        "name": "Keybindings",
        "panel": "keybindings"
    }, {
        "icon": "",
        "name": "Wallpaper",
        "panel": "wallpaper"
    }, {
        "icon": "󰔎",
        "name": "SDDM theme",
        "panel": "sddm"
    }, {
        "icon": "",
        "name": "Configuration",
        "panel": "config"
    }, {
        "icon": "󰍹",
        "name": "Monitor",
        "panel": "monitor"
    }, {
        "icon": "",
        "name": "Session",
        "panel": "session"
    }]

    panelName: "menu"
    // Back from an entry's panel, that entry stays selected.
    onOpening: selectedIndex = Math.max(0, entries.findIndex((entry) => {
        return entry.panel === openedFrom;
    }))
    onChosen: (entry) => {
        close();
        shellState.requestPanel(entry.panel, "open", screen.name, panelName);
    }
}
