pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The file chooser's sidebar: home, the XDG folders, your GTK bookmarks and the root.
// The folders are read at startup, so the sidebar is there on the chooser's first frame,
// and again each time someone looks (ServiceRef); the bookmarks are followed.
Singleton {
    id: places

    readonly property string home: Quickshell.env("HOME")
    property int refCount: 0
    property var userDirs: []
    property var bookmarks: []
    // [{ "icon", "name", "path" }], a folder only once.
    readonly property var list: [{
        "icon": "󰋜",
        "name": "Home",
        "path": home
    }].concat(userDirs, bookmarks.filter((bookmark) => {
        return bookmark.path !== home && !userDirs.some((place) => {
            return place.path === bookmark.path;
        });
    }), [{
        "icon": "󰋊",
        "name": "Computer",
        "path": "/"
    }])

    onRefCountChanged: {
        if (refCount === 1)
            reader.running = true;

    }

    // The XDG folders that aren't just home (xdg-user-dir falls back to it).
    Process {
        id: reader

        command: ["sh", "-c", "for name in DESKTOP DOCUMENTS DOWNLOAD PICTURES MUSIC VIDEOS; do printf '%s\\t%s\\n' \"$name\" \"$(xdg-user-dir \"$name\")\"; done"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const icons = {
                    "DESKTOP": "󰇄",
                    "DOCUMENTS": "󰈙",
                    "DOWNLOAD": "󰉍",
                    "PICTURES": "󰉏",
                    "MUSIC": "󱍙",
                    "VIDEOS": "󰕧"
                };
                places.userDirs = text.split("\n").filter((line) => {
                    return line !== "";
                }).map((line) => {
                    const fields = line.split("\t");
                    return {
                        "icon": icons[fields[0]] || "󰉋",
                        "name": fields[1].substring(fields[1].lastIndexOf("/") + 1),
                        "path": fields[1]
                    };
                }).filter((place) => {
                    return place.path !== places.home && place.path !== "";
                });
            }
        }

    }

    // Your GTK bookmarks, one "file:///path Name" a line.
    FileView {
        path: places.home + "/.config/gtk-3.0/bookmarks"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: places.bookmarks = text().split("\n").filter((line) => {
            return line.startsWith("file://");
        }).map((line) => {
            const space = line.indexOf(" ");
            // Nautilus writes them with a trailing slash.
            const path = decodeURIComponent((space > 0 ? line.substring(0, space) : line).substring(7)).replace(/(.)\/+$/, "$1");
            return {
                "icon": "󰃀",
                "name": space > 0 ? line.substring(space + 1) : path.substring(path.lastIndexOf("/") + 1),
                "path": path
            };
        })
    }

}
