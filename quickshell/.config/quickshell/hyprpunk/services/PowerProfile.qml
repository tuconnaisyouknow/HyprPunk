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

    function set(profile) {
        setter.command = ["powerprofilesctl", "set", profile];
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
                profiles.sort((a, b) => {
                    return order.indexOf(a) - order.indexOf(b);
                });
                // Only when they change, so the control showing them isn't built again.
                if (profiles.join() !== power.profiles.join())
                    power.profiles = profiles;

            }
        }

    }

    Process {
        id: setter

        // Re-read the real state, the daemon may refuse or hold the profile.
        onExited: reader.running = true
    }

}
