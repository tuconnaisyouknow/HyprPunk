pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Where the battery stops charging, changed through battery-limit (see battery/, which
// install.sh sets up); read only without it. Read at startup, then again each time
// someone looks (ServiceRef), since the firmware may change it on its own.
Singleton {
    id: limit

    property int refCount: 0
    // In % (100 for none), 0 when the battery has no such thing.
    property int current: 0
    property bool writable: false
    // Why the last limit didn't stick (the battery refused it), empty otherwise.
    property string error: ""
    // 100 turns it off.
    readonly property var choices: [60, 70, 80, 90, 100]

    function set(value) {
        if (!writable)
            return ;

        current = value;
        error = "";
        setter.command = ["battery-limit", "set", String(value)];
        setter.running = true;
    }

    onRefCountChanged: {
        if (refCount === 1) {
            error = "";
            reader.running = true;
        }
    }

    // "<limit> <writable 1|0>" first, or nothing when the battery has no limit.
    Process {
        id: reader

        command: ["sh", "-c", "command -v battery-limit >/dev/null && exec battery-limit get; for file in /sys/class/power_supply/*/charge_control_end_threshold; do [ -e \"$file\" ] && echo \"$(cat \"$file\") 0\"; break; done"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split(/\s+/);
                const value = parseInt(fields[0]);
                limit.current = isNaN(value) ? 0 : value;
                limit.writable = fields[1] === "1";
            }
        }

    }

    Process {
        id: setter

        stderr: StdioCollector {
            id: errors
        }

        // Re-read the real state, the firmware may round or refuse it.
        onExited: (code) => {
            if (code !== 0)
                limit.error = errors.text.trim().split("\n").pop() || "The charge limit could not be set.";

            reader.running = true;
        }
    }

}
