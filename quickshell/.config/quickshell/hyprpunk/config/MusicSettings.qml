pragma Singleton

import QtQuick
import Quickshell

// The music's settings, saved by musicctl.sh: the players the shell follows (Players.qml),
// the island's equalizer moving or still (Equalizer.qml), and the wave at the bottom of
// the desktop and the lock screen (VisualizerShell.qml, Lock.qml).
Singleton {
    // The players followed, as their bus names start ("spotify", "firefox"). None for any.
    readonly property var sources: (file.values.sources || "").split(",").filter((source) => {
        return source !== "";
    })
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
