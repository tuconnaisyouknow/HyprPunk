pragma Singleton

import QtQuick
import Quickshell

// What the shell remembers, saved by historyctl.sh: whether the clipboard history is
// kept and how many copies. Every copy goes through the script, which follows it.
Singleton {
    readonly property bool clipboard: file.values.clipboard !== "false"
    // null until the file is read, so it's never mistaken for a size of its own.
    readonly property var size: file.values.size ? parseInt(file.values.size) : null

    function set(key, value) {
        file.run(["set", key, String(value)]);
    }

    // "clipboard", "launcher" or "emoji".
    function clear(history) {
        file.run(["clear", history]);
    }

    SettingsFile {
        id: file

        fileName: "history.conf"
        script: "historyctl.sh"
    }

}
