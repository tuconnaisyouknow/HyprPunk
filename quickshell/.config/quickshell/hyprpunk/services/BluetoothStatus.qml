pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

// Bluetooth: turning it on and off, the devices around and connecting to them. BlueZ
// won't power an adapter rfkill blocks: the block is lifted first, and the adapter
// powered once it's reported unblocked.
Singleton {
    id: bluetooth

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: adapter !== null && adapter.enabled
    // Connected first, then paired, then by name. Unpaired devices that only give their
    // address are left out: you couldn't tell which one is yours.
    readonly property var devices: {
        if (!enabled)
            return [];

        return adapter.devices.values.filter((device) => {
            return device.paired || (device.deviceName !== "" && !/^([0-9A-F]{2}[-:]){5}[0-9A-F]{2}$/i.test(device.deviceName));
        }).sort((a, b) => {
            return (b.connected - a.connected) || (b.paired - a.paired) || a.deviceName.localeCompare(b.deviceName);
        });
    }
    readonly property var connected: devices.filter((device) => {
        return device.connected;
    })
    // Unblocked, waiting for the adapter to come out of the block.
    property bool pending: false

    function toggle() {
        if (adapter === null)
            return ;

        if (!adapter.enabled && adapter.state === BluetoothAdapterState.Blocked)
            unblock.running = true;
        else
            adapter.enabled = !adapter.enabled;
    }

    // Disconnects, connects a paired device, or pairs a new one, trusted so it connects
    // again on its own.
    function select(device) {
        if (device.connected) {
            device.disconnect();
        } else if (device.paired) {
            device.connect();
        } else {
            device.trusted = true;
            device.pair();
        }
    }

    function powerIfReady() {
        // Still blocked, or BlueZ is restoring power on its own after the unblock.
        if (!pending || adapter === null || adapter.state === BluetoothAdapterState.Blocked || adapter.state === BluetoothAdapterState.Enabling)
            return ;

        pending = false;
        if (adapter.state === BluetoothAdapterState.Disabled)
            adapter.enabled = true;

    }

    Process {
        id: unblock

        command: ["rfkill", "unblock", "bluetooth"]
        onExited: (exitCode) => {
            if (exitCode !== 0)
                return ;

            bluetooth.pending = true;
            timeout.restart();
            bluetooth.powerIfReady();
        }
    }

    Connections {
        function onStateChanged() {
            bluetooth.powerIfReady();
        }

        target: bluetooth.adapter
    }

    // Gives up if the adapter never comes out of the block.
    Timer {
        id: timeout

        interval: 3000
        onTriggered: bluetooth.pending = false
    }

}
