pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The settings the scripts save: the language (locale-profilectl.sh), the glass style
// (glassctl.sh), the keyboard layout (keyboard-layoutctl.sh) and the wallpaper
// (wallpaperctl.sh). And how the shell launches things.
// The shell keeps the environment it started with, so after a language change anything
// it launched itself would still speak the old one. Apps are started through Hyprland
// instead, which follows the change, and the shell's own helpers get localeEnvironment.
Singleton {
    id: session

    // "us" or "fr".
    property string languageProfile: "us"
    property string regionalProfile: "us"
    // "classic" or "liquid", the lock screen clock's glass. Switching it restyles every
    // glass surface on the spot, no restart needed.
    property string glassStyle: "classic"
    // "us" or "fr", whose Vim keys the panels follow (h/l, or j/m on AZERTY).
    property string keyboardLayout: "us"
    // The wallpaper's path, empty until known.
    property string wallpaper: ""
    readonly property string languageLocale: localeOf(languageProfile)
    readonly property string regionalLocale: localeOf(regionalProfile)
    // The variables locale-profilectl.sh exports, for a Process's environment.
    readonly property var localeEnvironment: ({
        "LANG": languageLocale,
        "LC_MESSAGES": languageLocale,
        "LC_CTYPE": regionalLocale,
        "LC_NUMERIC": regionalLocale,
        "LC_TIME": regionalLocale,
        "LC_COLLATE": regionalLocale,
        "LC_MONETARY": regionalLocale,
        "LC_PAPER": regionalLocale,
        "LC_NAME": regionalLocale,
        "LC_ADDRESS": regionalLocale,
        "LC_TELEPHONE": regionalLocale,
        "LC_MEASUREMENT": regionalLocale,
        "LC_IDENTIFICATION": regionalLocale,
        "LC_ALL": null
    })
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/hyprpunk"
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/hyprpunk"

    function localeOf(profile) {
        return profile === "fr" ? "fr_FR.UTF-8" : "en_US.UTF-8";
    }

    function quoted(argument) {
        return "'" + String(argument).replace(/'/g, "'\\''") + "'";
    }

    // Starts an app through Hyprland (hl.dsp.exec_cmd, run by sh), in a directory.
    function launch(command, workingDirectory) {
        let line = command.map(quoted).join(" ");
        if (workingDirectory)
            line = "cd " + quoted(workingDirectory) + " && exec " + line;

        // A Lua long string, with enough = signs that the command can't close it early.
        let level = "=";
        while (line.includes("]" + level + "]"))
            level += "=";
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exec_cmd([" + level + "[" + line + "]" + level + "])"]);
    }

    FileView {
        path: session.stateDir + "/locale-language"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: session.languageProfile = text().trim() || "us"
    }

    FileView {
        path: session.stateDir + "/locale-regional"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: session.regionalProfile = text().trim() || "us"
    }

    FileView {
        path: session.stateDir + "/glass-style"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: session.glassStyle = text().trim() === "liquid" ? "liquid" : "classic"
    }

    FileView {
        path: session.stateDir + "/keyboard-layout"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: session.keyboardLayout = text().trim() || "us"
    }

    FileView {
        path: session.stateDir + "/wallpaper.conf"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const match = text().match(/^wallpaper=(.*)$/m);
            session.wallpaper = match ? match[1] : "";
        }
    }

}
