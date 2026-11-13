pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// How screenshots and recordings are kept and where, saved by capturectl.sh:
// Screenshot.qml follows it for every capture.
Singleton {
    // "both", "copy" or "save": whether a screenshot goes to the clipboard, your
    // Screenshots folder, or both. Both until the file is read.
    readonly property string screenshots: file.values.screenshots || "both"
    readonly property bool copies: screenshots !== "save"
    readonly property bool saves: screenshots !== "copy"
    // "system", "microphone" or "none": what a recording hears.
    readonly property string audio: file.values.audio || "system"
    // Frames a second, 0 to record only when the screen changes.
    readonly property int framerate: parseInt(file.values.framerate) || 0
    // Where they're saved: the folder you chose, or Screenshots in your pictures folder
    // and Recordings in your videos folder.
    readonly property bool screenshotsFolderChosen: (file.values["screenshots.folder"] || "") !== ""
    readonly property bool recordingsFolderChosen: (file.values["recordings.folder"] || "") !== ""
    readonly property string screenshotsFolder: screenshotsFolderChosen ? file.values["screenshots.folder"] : userDir("PICTURES", "Pictures") + "/Screenshots"
    readonly property string recordingsFolder: recordingsFolderChosen ? file.values["recordings.folder"] : userDir("VIDEOS", "Videos") + "/Recordings"
    // user-dirs.dirs as last read, for the folders to follow it.
    property string userDirsText: ""

    function set(key, value) {
        file.run(["set", key, String(value)]);
    }

    // The folders file only appears at the first login, maybe after the shell started:
    // read again before each capture.
    function readUserDirs() {
        userDirs.reload();
    }

    // Your pictures or videos folder, wherever user-dirs.dirs puts it, or the usual one
    // before xdg-user-dirs has run.
    function userDir(name, fallback) {
        const match = userDirsText.match(new RegExp("^XDG_" + name + "_DIR=\"(.*)\"$", "m"));
        return match ? match[1].replace(/^\$HOME/, Quickshell.env("HOME")) : Quickshell.env("HOME") + "/" + fallback;
    }

    SettingsFile {
        id: file

        fileName: "capture.conf"
        script: "capturectl.sh"
    }

    // ~/.config/user-dirs.dirs, written by xdg-user-dirs-update at each login.
    FileView {
        id: userDirs

        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/user-dirs.dirs"
        // Read on the spot, so a capture right after the reload sees the folders.
        blockLoading: true
        printErrors: false
        onLoaded: userDirsText = text()
    }

}
