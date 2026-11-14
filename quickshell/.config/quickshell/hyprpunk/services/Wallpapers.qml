pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The wallpapers and themes wallpaperctl.sh offers, and switching to one. Read at startup,
// again after each new wallpaper (it may be another theme's, with its own list), and each
// time someone looks (ServiceRef), for files added meanwhile.
Singleton {
    id: wallpapers

    readonly property string wallpaperctl: Session.scripts + "/wallpaperctl.sh"
    property int refCount: 0
    // The current theme's wallpapers, in wallpaperctl.sh's order:
    // [{ "path", "thumbnail", "colors": [accent, secondary, surface] }].
    property var list: []
    // [{ "name", "wallpaper": its last one, "thumbnail" }].
    property var themes: []

    function read() {
        lister.running = true;
        themeLister.running = true;
    }

    function set(path) {
        run(["set", path], "Unable to change wallpaper");
    }

    function setTheme(name) {
        run(["theme", name], "Unable to change theme");
    }

    function run(args, failure) {
        setter.failure = failure;
        setter.command = [wallpaperctl, ...args];
        setter.running = true;
    }

    function lines(text) {
        return text.split("\n").filter((line) => {
            return line !== "";
        }).map((line) => {
            return line.split("\t");
        });
    }

    onRefCountChanged: {
        if (refCount === 1)
            read();

    }

    Connections {
        function onWallpaperChanged() {
            wallpapers.read();
        }

        target: Session
    }

    Process {
        id: lister

        command: [wallpapers.wallpaperctl, "list"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: wallpapers.list = wallpapers.lines(text).map(([path, thumbnail, ...colors]) => {
                return {
                    "path": path,
                    "thumbnail": thumbnail,
                    "colors": colors
                };
            })
        }

    }

    Process {
        id: themeLister

        command: [wallpapers.wallpaperctl, "themes"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: wallpapers.themes = wallpapers.lines(text).map(([name, wallpaper, thumbnail]) => {
                return {
                    "name": name,
                    "wallpaper": wallpaper,
                    "thumbnail": thumbnail
                };
            })
        }

    }

    Process {
        id: setter

        property string failure: ""

        onExited: (exitCode) => {
            if (exitCode !== 0)
                Quickshell.execDetached(["notify-send", "-u", "critical", failure, errors.text.trim()]);

        }

        stderr: StdioCollector {
            id: errors
        }

    }

}
