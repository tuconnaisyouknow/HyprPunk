pragma Singleton

import QtQuick
import Quickshell

// The night light, saved by nightlightctl.sh: off, always on, or from one hour to
// another, and how warm. NightLight.qml warms the screens by it.
Singleton {
    // "off", "on" or "schedule".
    readonly property string mode: file.values.mode || "off"
    // In kelvin, lower is warmer. Like the hours, null until the file is read.
    readonly property var temperature: file.values.temperature ? parseInt(file.values.temperature) : null
    readonly property var from: file.values.from ? parseInt(file.values.from) : null
    readonly property var to: file.values.to ? parseInt(file.values.to) : null

    function set(key, value) {
        file.run(["set", key, String(value)]);
    }

    SettingsFile {
        id: file

        fileName: "nightlight.conf"
        script: "nightlightctl.sh"
    }

}
