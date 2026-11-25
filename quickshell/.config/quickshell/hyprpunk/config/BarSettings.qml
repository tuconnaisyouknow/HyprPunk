pragma Singleton

import QtQuick
import Quickshell

// How the bar looks, saved by barctl.sh: the bar with the pills it keeps, or the island
// alone (Bar.qml). The island always stays.
Singleton {
    // The island alone, which opens under the pointer, rather than the bar.
    readonly property bool island: file.values.layout === "island"

    // "workspaces", "monitor", "updates" or "control".
    function shows(pill) {
        return file.values[pill] !== "false";
    }

    function set(key, value) {
        file.run(["set", key, String(value)]);
    }

    SettingsFile {
        id: file

        fileName: "bar.conf"
        script: "barctl.sh"
    }

}
