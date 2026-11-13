pragma Singleton

import QtQuick
import Quickshell

// The launcher's pinned and hidden apps, by desktop entry, saved by launcherctl.sh. The
// pinned ones come first while nothing is typed, in the order you pinned them; the
// hidden ones never show (AppLauncher.qml).
Singleton {
    readonly property var pinned: file.entries.filter((entry) => {
        return entry[0] === "pinned";
    }).map((entry) => {
        return entry[1];
    })
    readonly property var hidden: file.entries.filter((entry) => {
        return entry[0] === "hidden";
    }).map((entry) => {
        return entry[1];
    })

    function setPinned(app, pin) {
        file.run([pin ? "pin" : "unpin", app]);
    }

    function setHidden(app, hide) {
        file.run([hide ? "hide" : "show", app]);
    }

    SettingsFile {
        id: file

        fileName: "launcher.conf"
        script: "launcherctl.sh"
    }

}
