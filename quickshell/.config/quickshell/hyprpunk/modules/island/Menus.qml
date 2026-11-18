pragma Singleton

import QtQuick
import Quickshell
import qs.services

// The dynamic island's menus, the ones the launcher lists after ">": what they're called,
// what they're for, and which of them match what you type.
Singleton {
    // panel: the island panel opened on the screen ("settings" opens the settings window).
    readonly property var entries: [{
        "icon": "󰅌",
        "name": "Clipboard",
        "comment": "What you copied, to copy again",
        "panel": "clipboard"
    }, {
        "icon": "󰱨",
        "name": "Emoji",
        "comment": "Find an emoji and copy it",
        "panel": "emoji"
    }, {
        "icon": "󰹑",
        "name": "Capture",
        "comment": "Take a screenshot or record the screen",
        "panel": "screenshot"
    }, {
        "icon": "󰌌",
        "name": "Keybindings",
        "comment": "Every shortcut, to look up or run",
        "panel": "keybindings"
    }, {
        "icon": "",
        "name": "Wallpaper",
        "comment": "Change the wallpaper, and the colors with it",
        "panel": "wallpaper"
    }, {
        "icon": "󰏘",
        "name": "Theme",
        "comment": "Switch to another theme and its wallpaper",
        "panel": "theme"
    }, {
        "icon": "",
        "name": "Configuration",
        "comment": "Open one of your config files in your editor",
        "panel": "config"
    }, {
        "icon": "󰘮",
        "name": "Settings",
        "comment": "Displays, sound, power, appearance and the rest",
        "panel": "settings"
    }, {
        "icon": "",
        "name": "Session",
        "comment": "Lock, log out, reboot, shut down",
        "panel": "session"
    }]

    // The menus matching text, best first, in their own order while nothing is typed.
    function search(text) {
        const needle = text.toLowerCase();
        const matches = [];
        for (const entry of entries) {
            const score = needle === "" ? 1 : Math.max(Apps.matchScore(entry.name, needle, true), 0.6 * Apps.matchScore(entry.panel, needle, false), needle.length > 2 ? 0.4 * Apps.matchScore(entry.comment, needle, false) : 0);
            if (score > 0)
                matches.push({
                "entry": entry,
                "score": score
            });

        }
        // Stable: equal scores keep their order.
        matches.sort((a, b) => {
            return b.score - a.score;
        });
        // id: what the launcher's list knows a row by, like an app's.
        return matches.map((match) => {
            return Object.assign({
                "id": match.entry.panel
            }, match.entry);
        });
    }

}
