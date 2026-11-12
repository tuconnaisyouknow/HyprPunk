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
    // The clocks follow the regional formats: 12 h in us, 24 h in fr.
    readonly property bool twelveHour: /a/i.test(Qt.locale(regionalLocale.split(".")[0]).timeFormat(Locale.ShortFormat))
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
    // The scripts the shell runs, linked from the dotfiles' scripts module.
    readonly property string scripts: Quickshell.env("HOME") + "/.local/lib/hyprpunk"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/hyprpunk"
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/hyprpunk"

    function localeOf(profile) {
        return profile === "fr" ? "fr_FR.UTF-8" : "en_US.UTF-8";
    }

    // The hour on its own, for the lock screen's big clock, where AM/PM is a text of its
    // own. Done by hand: Qt only counts to 12 in a format that shows AM/PM too.
    function hourText(date) {
        const hour = date.getHours();
        return twelveHour ? String(hour % 12 || 12) : String(hour).padStart(2, "0");
    }

    // "AM" or "PM" in us, nothing in fr.
    function meridiemText(date) {
        if (!twelveHour)
            return "";

        const locale = Qt.locale(regionalLocale.split(".")[0]);
        return date.getHours() < 12 ? locale.amText : locale.pmText;
    }

    // "3:07 PM" in us, "15:07" in fr, for the islands and the calendar card.
    function clockText(date) {
        const meridiem = meridiemText(date);
        return hourText(date) + Qt.formatDateTime(date, ":mm") + (meridiem !== "" ? " " + meridiem : "");
    }

    // A time in a sentence ("Until 3:30 PM"), with AM/PM when the formats have it.
    function shortTime(date) {
        return date.toLocaleTimeString(Qt.locale(regionalLocale.split(".")[0]), Locale.ShortFormat);
    }

    function quoted(argument) {
        return "'" + String(argument).replace(/'/g, "'\\''") + "'";
    }

    // In your terminal: Hyprland reads $TERMINAL when it starts it, so changing it in
    // personal/keybindings.lua counts without restarting the shell.
    function launchInTerminal(command, workingDirectory) {
        launch(["sh", "-c", "exec ${TERMINAL:-kitty} -e \"$@\"", "sh"].concat(command), workingDirectory);
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
