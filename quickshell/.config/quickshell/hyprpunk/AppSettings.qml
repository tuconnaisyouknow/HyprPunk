pragma Singleton

import QtQuick
import Quickshell

// The apps HyprPunk opens for you, saved by appsctl.sh, which Hyprland follows
// (apps_state.lua): the command of each role, and the installed apps that can take it,
// found by their desktop entries' categories.
Singleton {
    id: appSettings

    // The roles, with the categories their apps declare.
    readonly property var roles: [{
        "name": "terminal",
        "categories": ["TerminalEmulator"],
        "icon": "󰆍",
        "title": "Terminal",
        "description": "Super+T, and wherever the shell or an app opens a terminal."
    }, {
        "name": "browser",
        "categories": ["WebBrowser"],
        "icon": "󰖟",
        "title": "Browser",
        "description": "Super+B, and the links you open from other apps."
    }, {
        "name": "files",
        "categories": ["FileManager"],
        "icon": "󰉋",
        "title": "Files",
        "description": "Super+E, and the folders you open from other apps."
    }, {
        "name": "music",
        "categories": ["Audio", "Player"],
        "icon": "󰝚",
        "title": "Music",
        "description": "Super+P. The bar's record and the lock screen's player still follow Spotify only."
    }]
    readonly property var values: file.values

    // The command a desktop entry starts, without the field codes (%U) that ask for files.
    function command(entry) {
        return entry.command.filter((word) => {
            return !/^%[a-zA-Z]$/.test(word);
        }).join(" ");
    }

    // The installed apps in all those categories, by name.
    function candidates(categories) {
        return DesktopEntries.applications.values.filter((entry) => {
            return !entry.noDisplay && categories.every((category) => {
                return entry.categories.includes(category);
            });
        }).sort((a, b) => {
            return a.name.localeCompare(b.name);
        });
    }

    function set(role, entry) {
        file.run(["set", role, command(entry), entry.id + ".desktop"]);
    }

    SettingsFile {
        id: file

        fileName: "apps.conf"
        script: "appsctl.sh"
    }

}
