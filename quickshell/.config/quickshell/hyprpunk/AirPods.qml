import QtQuick
import Quickshell
import Quickshell.Io

// The AirPods companion (~/Scripts/airpodsd.py): paired AirPods with their
// batteries and ear detection, the AirPods in pairing mode next to the computer,
// and the moments their card should show (case opened, connected, pairing mode).
Scope {
    id: airPods

    // Paired AirPods: {address, name, model, kind ("buds" or "headphones"), connected,
    // nearby, lidOpen, left/right {level, charging, inEar}, case/headset {level, charging}},
    // a level is null when unknown.
    property var devices: []
    // AirPods in pairing mode: {address, name, model, kind, state ("ready", "pairing", "failed")}.
    property var pairing: null

    signal popupRequested(string address, string reason)
    signal lidClosed(string address)

    function device(address) {
        return devices.find((item) => {
            return item.address === address;
        }) || null;
    }

    function send(command, address) {
        if (daemon.running)
            daemon.write(command + " " + address + "\n");

    }

    function pair(address) {
        send("pair", address);
    }

    // Leaves the AirPods in pairing mode alone for a while.
    function ignore(address) {
        send("ignore", address);
    }

    // `qs -c hyprpunk ipc call airpods popup`: the card of the connected AirPods, else
    // of the nearest paired ones.
    IpcHandler {
        function popup(): void {
            const shown = airPods.devices.find((item) => {
                return item.connected;
            }) || airPods.devices.find((item) => {
                return item.nearby;
            }) || airPods.devices[0];
            if (shown)
                airPods.popupRequested(shown.address, "manual");

        }

        target: "airpods"
    }

    Process {
        id: daemon

        command: ["python3", "-u", Quickshell.env("HOME") + "/Scripts/airpodsd.py"]
        running: true
        stdinEnabled: true
        onExited: restartDelay.restart()

        stdout: SplitParser {
            onRead: (line) => {
                let message;
                try {
                    message = JSON.parse(line);
                } catch (error) {
                    return ;
                }
                if (message.event === "state") {
                    airPods.devices = message.devices;
                    airPods.pairing = message.pairing;
                } else if (message.event === "popup") {
                    airPods.popupRequested(message.address, message.reason);
                } else if (message.event === "lidClosed") {
                    airPods.lidClosed(message.address);
                }
            }
        }

        stderr: SplitParser {
            onRead: (line) => {
                return console.log(line);
            }
        }

    }

    // Started again when it stops, e.g. after BlueZ restarted under it.
    Timer {
        id: restartDelay

        interval: 5000
        onTriggered: daemon.running = true
    }

}
