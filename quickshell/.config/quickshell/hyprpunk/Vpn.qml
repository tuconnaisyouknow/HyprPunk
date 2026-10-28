pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The VPNs NetworkManager has up or is bringing up, which Quickshell.Networking doesn't
// tell. The bar's network icon turns into a padlock while one is on.
Singleton {
    id: vpn

    // [{name, state}], state being "activated" or "activating".
    property var connections: []
    // The one that's up, else one coming up, else null.
    readonly property var connection: connections.find((connection) => {
        return connection.state === "activated";
    }) || connections.find((connection) => {
        return connection.state === "activating";
    }) || null
    readonly property bool active: connection !== null && connection.state === "activated"
    readonly property bool connecting: connection !== null && !active

    Process {
        id: listProcess

        // NAME last: it is the only field that can hold an (escaped) colon.
        command: ["nmcli", "-t", "-f", "TYPE,STATE,NAME", "connection", "show", "--active"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const connections = [];
                for (const line of text.trim().split("\n")) {
                    const fields = line.split(":");
                    if (fields.length >= 3 && (fields[0] === "vpn" || fields[0] === "wireguard"))
                        connections.push({
                        "state": fields[1],
                        "name": fields.slice(2).join(":").replace(/\\:/g, ":")
                    });

                }
                if (JSON.stringify(connections) !== JSON.stringify(vpn.connections))
                    vpn.connections = connections;

            }
        }

    }

    // Any NetworkManager change lists them again, a burst of changes only once.
    Process {
        command: ["nmcli", "monitor"]
        running: true

        stdout: SplitParser {
            onRead: refresh.restart()
        }

    }

    Timer {
        id: refresh

        interval: 250
        onTriggered: listProcess.running = true
    }

}
