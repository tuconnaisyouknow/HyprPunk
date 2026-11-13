pragma Singleton

import QtQuick
import Quickshell

// How updates reach you, saved by updatesctl.sh: the notification at login when HyprPunk
// has one (update-notify.sh reads it), and the bar's count of package updates
// (Updates.qml), how often it asks.
Singleton {
    readonly property bool hyprpunk: file.values.hyprpunk !== "false"
    readonly property bool packages: file.values.packages !== "false"
    // In minutes, null until the file is read.
    readonly property var interval: file.values.interval ? parseInt(file.values.interval) : null

    function set(key, value) {
        file.run(["set", key, String(value)]);
    }

    // In your terminal, like the notification's button.
    function updateHyprPunk() {
        file.run(["run"]);
    }

    SettingsFile {
        id: file

        fileName: "updates.conf"
        script: "updatesctl.sh"
    }

}
