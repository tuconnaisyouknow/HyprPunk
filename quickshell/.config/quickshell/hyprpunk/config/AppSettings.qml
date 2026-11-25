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
        "icon": "terminal",
        "title": "Terminal",
        "description": "Super+T, and wherever the shell or an app opens a terminal."
    }, {
        "name": "browser",
        "categories": ["WebBrowser"],
        "icon": "language",
        "title": "Browser",
        "description": "Super+B, and the links you open from other apps."
    }, {
        "name": "files",
        "categories": ["FileManager"],
        "icon": "folder",
        "title": "Files",
        "description": "Super+E, and the folders you open from other apps."
    }, {
        "name": "music",
        "categories": ["Audio", "Player"],
        "icon": "music_note",
        "title": "Music",
        "description": "Super+P. The players the island and the lock screen follow are on the Music page."
    }]
    readonly property var values: file.values

    // The command a desktop entry starts, without the field codes (%U) that ask for files.
    function command(entry) {
        return entry.command.filter((word) => {
            return !/^%[a-zA-Z]$/.test(word);
        }).join(" ");
    }

    // The app's own name, not what it does: the words of its entry's name that name its
    // program ("Thunar File Manager" is Thunar). GNOME names its apps by their role
    // ("Files"), so then the program itself (Nautilus).
    function name(entry) {
        const program = entry.id.split(".").pop();
        const identity = (entry.id + " " + (entry.command[0] ?? "").split("/").pop()).toLowerCase();
        const words = entry.name.split(" ").filter((word) => {
            return identity.includes(word.toLowerCase());
        });
        return words.length > 0 ? words.join(" ") : program.charAt(0).toUpperCase() + program.slice(1);
    }

    // The installed apps in all those categories, by name. Not the ones that run in a
    // terminal: a role's command is started on its own, where they'd have no window.
    function candidates(categories) {
        return DesktopEntries.applications.values.filter((entry) => {
            return !entry.noDisplay && !entry.runInTerminal && categories.every((category) => {
                return entry.categories.includes(category);
            });
        }).sort((a, b) => {
            return name(a).localeCompare(name(b));
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
