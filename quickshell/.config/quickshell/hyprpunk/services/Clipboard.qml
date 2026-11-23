pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Your clipboard history, newest first, and putting an entry back. historyctl.sh keeps
// it, one file per copy. Read each time someone looks (ServiceRef): nothing tells when
// it grows.
Singleton {
    id: clipboard

    property int refCount: 0
    // [{ "id": its file, "text": a text's start, an image's label or the files' names,
    //    "image": the picture to show, or "" }]
    property var entries: []
    readonly property bool loading: reader.running

    function copy(entry) {
        Quickshell.execDetached([Session.scripts + "/historyctl.sh", "copy", entry.id]);
    }

    onRefCountChanged: {
        if (refCount === 1)
            reader.running = true;

    }

    Process {
        id: reader

        command: [Session.scripts + "/historyctl.sh", "list"]

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
