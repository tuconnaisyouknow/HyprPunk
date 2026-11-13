pragma Singleton

import QtQuick
import Quickshell

// What the island tells you as it happens, saved by osdctl.sh: which changes show
// (Bar.qml asks shows() before each), and how long they stay. The battery's warnings
// always show.
Singleton {
    // How much longer or shorter than usual each one stays.
    readonly property real pace: ({
        "short": 0.6,
        "long": 1.6
    })[file.values.duration] || 1
    readonly property string duration: file.values.duration || "normal"

    // "volume", "microphone", "brightness", "keys", "power", "airpods" or "screenshots".
    function shows(change) {
        return file.values[change] !== "false";
    }

    function set(key, value) {
        file.run(["set", key, String(value)]);
    }

    SettingsFile {
        id: file

        fileName: "osd.conf"
        script: "osdctl.sh"
    }

}
