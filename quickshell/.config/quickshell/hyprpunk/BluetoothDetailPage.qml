import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth

// A paired Bluetooth device: its state, then connect or disconnect and forget it
// (removes the pairing).
ColumnLayout {
    id: page

    property var device: null

    signal backRequested()
    signal forgotten()

    spacing: 12

    PageHeader {
        Layout.fillWidth: true
        title: page.device !== null ? page.device.deviceName : ""
        toggleVisible: false
        onBackRequested: page.backRequested()
    }

    InfoBlock {
        Layout.fillWidth: true
        rows: page.device === null ? [] : [{
            "label": "Status",
            "value": page.device.state === BluetoothDeviceState.Connecting ? "Connecting…" : page.device.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…" : page.device.connected ? "Connected" : "Paired"
        }, {
            "label": "Battery",
            "value": page.device.batteryAvailable ? Math.round(page.device.battery * 100) + "%" : ""
        }, {
            "label": "Address",
            "value": page.device.address
        }]
    }

    ActionRow {
        Layout.fillWidth: true
        icon: page.device !== null && page.device.connected ? "󰂲" : "󰂱"
        label: page.device !== null && page.device.connected ? "Disconnect" : "Connect"
        onTriggered: {
            if (page.device.connected)
                page.device.disconnect();
            else
                page.device.connect();
        }
    }

    ActionRow {
        Layout.fillWidth: true
        icon: "󰆴"
        label: "Forget This Device"
        confirmLabel: "Click again to forget it"
        destructive: true
        onTriggered: {
            page.device.forget();
            page.forgotten();
        }
    }

}
