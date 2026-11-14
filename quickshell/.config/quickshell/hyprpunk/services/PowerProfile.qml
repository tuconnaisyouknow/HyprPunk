pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The power profile, through power-profiles-daemon: the one in use and the ones there
// are. Read at startup, then again each time someone looks (ServiceRef), since another
// app may have changed it meanwhile.
Singleton {
    id: power

    property int refCount: 0
    property string current: "balanced"
    // Saver, balanced, then performance where the computer has it.
    property var profiles: []
    // Laptops and desktops alike: power-profiles-daemon always has at least saver and
    // balanced, so fewer means it isn't running.
    readonly property bool available: profiles.length > 1

    // The next profile, back to the first after the last.
    function cycle() {
        if (setter.running || profiles.length < 2)
            return ;

        const next = profiles[(profiles.indexOf(current) + 1) % profiles.length];
        current = next;
        setter.command = ["powerprofilesctl", "set", next];
        setter.running = true;
    }

    onRefCountChanged: {
        if (refCount === 1)
            reader.running = true;

    }

    Process {
        id: reader

        // Profile lines look like "* balanced:" (active) or "  performance:".
        command: ["powerprofilesctl", "list"]
        running: true
        onExited: (exitCode) => {
            if (exitCode !== 0)
                power.profiles = [];

        }

        stdout: StdioCollector {
            onStreamFinished: {
                const order = ["power-saver", "balanced", "performance"];
                const profiles = [];
                const pattern = /^([* ]) ([a-z-]+):$/gm;
                let match;
                while ((match = pattern.exec(text)) !== null) {
                    profiles.push(match[2]);
                    if (match[1] === "*")
                        power.current = match[2];

                }
                power.profiles = profiles.sort((a, b) => {
                    return order.indexOf(a) - order.indexOf(b);
                });
            }
        }

    }

    Process {
        id: setter

        // Re-read the real state, the daemon may refuse or hold the profile.
        onExited: reader.running = true
    }

}
