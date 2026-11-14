pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

// Turns Bluetooth on and off. BlueZ won't power an adapter rfkill blocks: the block is
// lifted first, and the adapter powered once it's reported unblocked.
Singleton {
    id: power

    readonly property var adapter: Bluetooth.defaultAdapter
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

            power.pending = true;
            timeout.restart();
            power.powerIfReady();
        }
    }

    Connections {
        function onStateChanged() {
            power.powerIfReady();
        }

        target: power.adapter
    }

    // Gives up if the adapter never comes out of the block.
    Timer {
        id: timeout

        interval: 3000
        onTriggered: power.pending = false
    }

}
