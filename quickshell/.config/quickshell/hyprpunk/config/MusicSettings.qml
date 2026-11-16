pragma Singleton

import QtQuick
import Quickshell

// How the music shows, saved by musicctl.sh: the island's equalizer moving or still
// (Equalizer.qml), and the wave at the bottom of the desktop and the lock screen
// (VisualizerShell.qml, Lock.qml).
Singleton {
    readonly property bool equalizer: file.values.equalizer !== "false"
    readonly property bool wave: file.values.wave !== "false"

    function set(key, value) {
        file.run(["set", key, String(value)]);
    }

    SettingsFile {
        id: file

        fileName: "music.conf"
        script: "musicctl.sh"
    }

}
