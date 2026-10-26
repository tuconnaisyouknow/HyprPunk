import QtQuick
import Quickshell
import Quickshell.Io

// The AirPods companion (~/Scripts/airpodsd.py): paired AirPods with their
// batteries, ear detection and settings, the AirPods in pairing mode next to the
// computer, and the moments their card should show (case opened, connected, pairing mode).
Scope {
    id: airPods

    // Paired AirPods: {address, name, model, kind ("buds" or "headphones"), connected,
    // nearby, lidOpen, left/right {level, charging, inEar}, case/headset {level, charging},
    // controls {listeningMode (1 off, 2 noise cancellation, 3 transparency, 4 adaptive),
    // conversationAwareness, adaptiveStrength (0-100), allowOff} as far as they reported
    // them}, a level is null when unknown.
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

    // [{level, charging, label}] of the pods (or the headphones): one ring while both
    // pods agree, a letter on each when they do not.
    function podBatteries(device) {
        if (device === null)
            return [];

        if (device.kind === "headphones")
            return [device.headset];

        const left = device.left;
        const right = device.right;
        if (left.level === null && right.level === null)
            return [left];

        if (right.level === null || (left.level === right.level && left.charging === right.charging))
            return [Object.assign({
                "label": right.level === null ? "L" : ""
            }, left)];

        if (left.level === null)
            return [Object.assign({
                "label": "R"
            }, right)];

        return [Object.assign({
            "label": "L"
        }, left), Object.assign({
            "label": "R"
        }, right)];
    }

    // Models with noise cancellation and transparency: the Pro ones, the AirPods 4
    // with ANC and the Max.
    function hasNoiseControl(device) {
        return device !== null && [0x200E, 0x2014, 0x2024, 0x2027, 0x201B, 0x200A, 0x201F].includes(device.modelId);
    }

    function send(command, address, argument) {
        if (daemon.running)
            daemon.write(command + " " + address + (argument !== undefined ? " " + argument : "") + "\n");

    }

    // A setting of the connected AirPods (airpodsd's CONTROLS): a number, or a bool
    // for the switches.
    function control(address, name, value) {
        send("control", address, name + " " + Number(value));
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
