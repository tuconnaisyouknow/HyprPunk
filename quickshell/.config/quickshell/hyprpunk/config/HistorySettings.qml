pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What the shell remembers, saved by historyctl.sh: whether the clipboard history is
// kept and how many copies, and how much each history holds. Every copy goes through
// the script, which follows the settings.
Singleton {
    id: settings

    readonly property bool clipboard: file.values.clipboard !== "false"
    // null until the file is read, so it's never mistaken for a size of its own.
    readonly property var size: file.values.size ? parseInt(file.values.size) : null
    // { "clipboard", "launcher", "emoji" }: how many entries each holds. Empty until
    // counted, and counted only when asked: nothing tells when a history grows.
    property var counts: ({
    })

    function set(key, value) {
        file.run(["set", key, String(value)]);
    }

    function count() {
        counter.running = true;
    }

    // "clipboard", "launcher" or "emoji". Counted again once it's gone, so what shows
    // it empty is the history itself.
    function clear(history) {
        wipe.createObject(settings, {
            "command": [Session.scripts + "/historyctl.sh", "clear", history],
            "running": true
        });
    }

    SettingsFile {
        id: file

        fileName: "history.conf"
        script: "historyctl.sh"
    }

    Process {
        id: counter

        command: [Session.scripts + "/historyctl.sh", "count"]

        stdout: StdioCollector {
            onStreamFinished: {
                const counts = {
                };
                for (const line of text.split("\n")) {
                    const split = line.indexOf("=");
                    if (split > 0)
                        counts[line.slice(0, split)] = parseInt(line.slice(split + 1));

                }
                settings.counts = counts;
            }
        }

    }

    // One per clear, so two asked together both happen.
    Component {
        id: wipe

        Process {
            onExited: {
                settings.count();
                destroy();
            }
        }

    }

}
