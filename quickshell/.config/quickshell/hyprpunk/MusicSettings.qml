pragma Singleton

import QtQuick
import Quickshell

// How the music shows, saved by musicctl.sh: the bar's cover spinning, still, or a plain
// record (MusicPill.qml), and the wave at the bottom of the desktop and the lock screen
// (VisualizerShell.qml, Lock.qml).
Singleton {
    readonly property string cover: file.values.cover || "spinning"
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
