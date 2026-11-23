pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The wallpapers and themes wallpaperctl.sh offers, and switching to one. Read at startup
// and each time someone looks (ServiceRef), for files added meanwhile. The wallpaper you
// pick counts as yours at once: switching takes wallpaperctl.sh a few seconds, and the
// pickers follow your choice rather than what it has saved so far.
Singleton {
    id: wallpapers

    readonly property string wallpaperctl: Session.scripts + "/wallpaperctl.sh"
    property int refCount: 0
    // Every theme's wallpapers, in wallpaperctl.sh's order:
    // [{ "theme", "path", "thumbnail", "colors": [accent, secondary, surface] }].
    property var all: []
    // [{ "name", "wallpaper": its last one, "thumbnail" }], as wallpaperctl.sh saved them.
    property var savedThemes: []
    // The wallpaper you picked, while wallpaperctl.sh puts it in place.
    property string chosen: ""
    // The next switch, when you pick again before the last one is done: only the latest counts.
    property var next: null
    readonly property string current: chosen !== "" ? chosen : Session.wallpaper
    readonly property var currentEntry: all.find((wallpaper) => {
        return wallpaper.path === current;
    }) ?? null
    readonly property string theme: currentEntry ? currentEntry.theme : ""
    // The current theme's wallpapers.
    readonly property var list: all.filter((wallpaper) => {
        return wallpaper.theme === theme;
    })
    // Each theme and the wallpaper it would switch to: the current one for its own theme.
    readonly property var themes: savedThemes.map((saved) => {
        return saved.name === theme ? {
            "name": saved.name,
            "wallpaper": current,
            "thumbnail": currentEntry.thumbnail
        } : saved;
    })

    function read() {
        lister.running = true;
        themeLister.running = true;
    }

    function set(path) {
        run(path, ["set", path], "Unable to change wallpaper");
    }

    function setTheme(name) {
        const saved = savedThemes.find((theme) => {
            return theme.name === name;
        });
        if (saved)
            run(saved.wallpaper, ["theme", name], "Unable to change theme");

    }

    function run(wallpaper, args, failure) {
        chosen = wallpaper;
        next = {
            "command": [wallpaperctl, ...args],
            "failure": failure
        };
        if (!setter.running)
            startNext();

    }

    function startNext() {
        setter.command = next.command;
        setter.failure = next.failure;
        next = null;
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

    // Each theme's last wallpaper changes with every one saved
    Connections {
        function onWallpaperChanged() {
            themeLister.running = true;
        }

        target: Session
    }

    Process {
        id: lister

        command: [wallpapers.wallpaperctl, "list"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: wallpapers.all = wallpapers.lines(text).map(([theme, path, thumbnail, ...colors]) => {
                return {
                    "theme": theme,
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
            onStreamFinished: wallpapers.savedThemes = wallpapers.lines(text).map(([name, wallpaper, thumbnail]) => {
                return {
                    "name": name,
                    "wallpaper": wallpaper,
                    "thumbnail": thumbnail
                };
            })
        }

    }

    // The saved wallpaper is written before wallpaperctl.sh ends, so letting go of your
    // choice hands over to it without a flicker, or brings the old one back if it failed.
    Process {
        id: setter

        property string failure: ""

        onExited: (exitCode) => {
            if (exitCode !== 0)
                Quickshell.execDetached(["notify-send", "-u", "critical", failure, errors.text.trim()]);

            if (wallpapers.next)
                wallpapers.startNext();
            else
                wallpapers.chosen = "";
        }

        stderr: StdioCollector {
            id: errors
        }

    }

}
