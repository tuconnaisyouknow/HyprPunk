pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The session's locale profiles (locale-profilectl.sh) and how the shell starts programs.
// The shell keeps the environment it was started with, so after a locale change the
// programs it starts would keep the old locale: apps go through Hyprland, whose
// environment follows the profiles, and the shell's own children get localeEnvironment.
Singleton {
    id: session

    // "us" or "fr".
    property string languageProfile: "us"
    property string regionalProfile: "fr"
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

        // A Lua long string needs no escaping, at a level the command can't close.
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
        onLoaded: session.regionalProfile = text().trim() || "fr"
    }

}
