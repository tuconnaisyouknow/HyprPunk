pragma Singleton

import QtQuick
import Quickshell

// The battery's warnings, saved by batteryctl.sh: the low and critical levels the island
// warns you at (Bar.qml), and what the computer does when it stays critical
// (CriticalBattery.qml).
Singleton {
    // In percent; like the critical one, null until the file is read.
    readonly property var low: file.values.low ? parseInt(file.values.low) : null
    readonly property var critical: file.values.critical ? parseInt(file.values.critical) : null
    // "none", "suspend" or "poweroff".
    readonly property string action: file.values.action || "none"

    function set(key, value) {
        file.run(["set", key, String(value)]);
    }

    SettingsFile {
        id: file

        fileName: "battery.conf"
        script: "batteryctl.sh"
    }

}
