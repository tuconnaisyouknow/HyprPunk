pragma Singleton

import QtQuick
import Quickshell

// How the volume moves, saved by soundctl.sh: the volume keys' step, and the limit
// nothing in the shell raises the volume past (the keys, the control center's slider).
// The script brings a louder volume down to a new limit.
Singleton {
    // In percent; like the limit, null until the file is read.
    readonly property var step: file.values.step ? parseInt(file.values.step) : null
    readonly property var limit: file.values.limit ? parseInt(file.values.limit) : null

    function set(key, value) {
        file.run(["set", key, String(value)]);
    }

    SettingsFile {
        id: file

        fileName: "sound.conf"
        script: "soundctl.sh"
    }

}
