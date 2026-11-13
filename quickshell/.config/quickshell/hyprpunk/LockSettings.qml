pragma Singleton

import QtQuick
import Quickshell

// How the lock screen looks, saved by lockctl.sh: whether it shows the player and its
// lyrics (LockSurface.qml), and whether it blurs in and out or comes and goes at once
// (Lock.qml).
Singleton {
    readonly property bool player: file.values.player !== "false"
    readonly property bool animation: file.values.animation !== "false"

    function set(key, value) {
        file.run(["set", key, String(value)]);
    }

    SettingsFile {
        id: file

        fileName: "lock.conf"
        script: "lockctl.sh"
    }

}
