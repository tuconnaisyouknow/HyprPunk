pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Your clipboard history from cliphist, newest first, and putting an entry back. Read
// each time someone looks (ServiceRef): cliphist has no way to follow it.
Singleton {
    id: clipboard

    readonly property string cacheDir: Session.cacheDir + "/clipboard"
    property int refCount: 0
    // [{ "id", "text", "image": decoded file or "" }]
    property var entries: []
    readonly property bool loading: reader.running

    function copy(entry) {
        Quickshell.execDetached(["sh", "-c", "cliphist decode \"$0\" | wl-copy", entry.id]);
    }

    onRefCountChanged: {
        if (refCount === 1)
            reader.running = true;

    }

    // One "id<TAB>preview<TAB>image" line per entry, the images decoded once into the
    // cache, which forgets them after a month.
    Process {
        id: reader

        command: ["bash", "-c", "mkdir -p \"$0\"; find \"$0\" -type f -mtime +30 -delete; cliphist list | while IFS=$'\\t' read -r id preview; do image=''; if [[ $preview == '[[ binary data '* ]]; then ext=$(sed -nE 's/.* (png|jpeg|jpg|gif|bmp|webp) .*/\\1/p' <<<\"$preview\"); if [[ -n $ext ]]; then image=\"$0/$id.$ext\"; [[ -s $image ]] || cliphist decode \"$id\" >\"$image\" 2>/dev/null; fi; fi; printf '%s\\t%s\\t%s\\n' \"$id\" \"$preview\" \"$image\"; done", clipboard.cacheDir]

        stdout: StdioCollector {
            onStreamFinished: clipboard.entries = text.split("\n").filter((line) => {
                return line !== "";
            }).map((line) => {
                const fields = line.split("\t");
                return {
                    "id": fields[0],
                    "text": fields[1] || "",
                    "image": fields[2] || ""
                };
            })
        }

    }

}
