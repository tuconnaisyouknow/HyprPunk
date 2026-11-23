pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The settings the scripts save: the regional formats (locale-profilectl.sh), the glass
// style (glassctl.sh), the see-through windows (transparencyctl.sh), the keyboard layout
// (keyboard-layoutctl.sh) and the wallpaper (wallpaperctl.sh). And how the shell
// launches things.
// The shell keeps the environment it started with, so after a change of formats anything
// it launched itself would still write the old ones: apps are started through Hyprland
// instead, which follows the change.
Singleton {
    id: session

    // The regional formats' locale, as glibc names it ("de_DE.UTF-8"), and its name
    // ("German (Germany)").
    property string regionalLocale: "en_US.UTF-8"
    property string regionalName: ""
    // "classic" or "liquid", the lock screen clock's glass. Switching it restyles every
    // glass surface on the spot, no restart needed.
    property string glassStyle: "classic"
    // Which windows are see-through: "all", "terminal" or "none". Hyprland's to apply,
    // the settings' to show.
    property string transparency: "terminal"
    // The keyboard layout as XKB names it ("fr"), and its variant ("bepo"), often none.
    property string keyboardLayout: "us"
    property string keyboardVariant: ""
    // As you'd read it: "French (BEPO)".
    property string keyboardLayoutName: ""
    // Where the Vim keys sit: "vim" for Vim's own letters, "home" for the home row.
    property string vimKeysPlace: "vim"
    // What the four keys write, left, down, up, right: the ones in use, and the home
    // row's whether it's in use or not, for the settings to show.
    property var vimKeys: ["h", "j", "k", "l"]
    property var homeKeys: ["h", "j", "k", "l"]
    // The same four as Qt names a key press, left, right, down, up like Navigation's
    // arrows: the character in capitals, when it has any.
    readonly property var vimKeyCodes: [0, 3, 1, 2].map((index) => {
        const capital = vimKeys[index].toUpperCase();
        return (Array.from(capital).length === 1 ? capital : vimKeys[index]).codePointAt(0);
    })
    // The wallpaper's path, empty until known.
    property string wallpaper: ""
    // The regional formats as Qt knows them (day and month names, the first day of the
    // week), though the shell keeps the locale it started with. Qt reads glibc's names but
    // not their variant: sr_RS@latin gets Serbian's own script, Cyrillic.
    readonly property var regionalFormats: Qt.locale(regionalLocale)
    // The clocks follow the regional formats: 12 h in en_US, 24 h in en_GB.
    readonly property bool twelveHour: /a/i.test(regionalFormats.timeFormat(Locale.ShortFormat))
    // The scripts the shell runs, linked from the dotfiles' scripts module.
    readonly property string scripts: Quickshell.env("HOME") + "/.local/lib/hyprpunk"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/hyprpunk"
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/hyprpunk"

    // The key=value lines of a state file.
    function stateValues(text) {
        const values = {
        };
        for (const line of text.split("\n")) {
            const cut = line.indexOf("=");
            if (cut > 0)
                values[line.slice(0, cut)] = line.slice(cut + 1);

        }
        return values;
    }

    // The hour on its own, for the lock screen's big clock, where AM/PM is a text of its
    // own. Done by hand: Qt only counts to 12 in a format that shows AM/PM too.
    function hourText(date) {
        const hour = date.getHours();
        return twelveHour ? String(hour % 12 || 12) : String(hour).padStart(2, "0");
    }

    // "AM" or "PM" when the formats count to 12, nothing otherwise.
    function meridiemText(date) {
        if (!twelveHour)
            return "";

        return date.getHours() < 12 ? regionalFormats.amText : regionalFormats.pmText;
    }

    // A time as the regional formats write it, "3:07 PM", "15:07" or "15.07": the
    // islands' clock, the lock screen's small one, and in a sentence ("Until 3:30 PM").
    function shortTime(date) {
        return date.toLocaleTimeString(regionalFormats, Locale.ShortFormat);
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
        path: session.stateDir + "/locale-regional"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: session.regionalLocale = text().trim() || "en_US.UTF-8"
    }

    FileView {
        path: session.stateDir + "/locale-name"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: session.regionalName = text().trim()
    }

    FileView {
        path: session.stateDir + "/glass-style"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: session.glassStyle = text().trim() === "liquid" ? "liquid" : "classic"
    }

    FileView {
        path: session.stateDir + "/transparency"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const choice = text().trim();
            session.transparency = choice === "all" || choice === "none" ? choice : "terminal";
        }
    }

    FileView {
        path: session.stateDir + "/keyboard-layout"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const chosen = session.stateValues(text());
            session.keyboardLayout = chosen.layout || "us";
            session.keyboardVariant = chosen.variant || "";
            session.vimKeysPlace = chosen.keys === "home" ? "home" : "vim";
        }
    }

    // What keyboard-layoutctl.sh worked out from the choice above.
    FileView {
        path: session.stateDir + "/keyboard/keys"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const keys = session.stateValues(text());
            if (!keys.left || !keys.down || !keys.up || !keys.right)
                return ;

            session.keyboardLayoutName = keys.layout_name || "";
            session.vimKeys = [keys.left, keys.down, keys.up, keys.right];
            session.homeKeys = (keys.home || "").split(" ").length === 4 ? keys.home.split(" ") : session.vimKeys;
        }
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
