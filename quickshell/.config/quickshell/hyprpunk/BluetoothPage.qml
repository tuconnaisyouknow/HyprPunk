import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

// The control center's Bluetooth page: the devices around, a click to pair or
// connect, and the paired ones open their details.
ColumnLayout {
    id: page

    required property var center

    signal backRequested()

    spacing: 12

    PageHeader {
        Layout.fillWidth: true
        title: "Bluetooth"
        checked: page.center.bluetoothEnabled
        onBackRequested: page.backRequested()
        onToggled: page.center.toggleBluetooth()
    }

    IconText {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 8
        Layout.bottomMargin: 8
        visible: page.center.bluetoothDevices.length === 0
        icon: page.center.bluetoothEnabled ? "󰂰" : "󰂲"
        text: page.center.bluetoothEnabled ? "Searching for devices…" : "Bluetooth is off"
        color: Theme.overlay1
        font.pixelSize: 14
        font.weight: Font.Normal


    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: bluetoothList.height
        visible: page.center.bluetoothDevices.length > 0

        ListView {
            id: bluetoothList

            // Wider than the page by a few pixels, so the hovered row's zoom and
            // bounce (up to 4.5px a side) aren't cut; the rows stay aligned.
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: -6
            anchors.rightMargin: -6
            height: Math.min(contentHeight, 340)
            clip: true
            spacing: 4
            // Keeps the rows that stay instead of rebuilding them all at each change,
            // which held up the animations.
            model: ScriptModel {
                values: page.center.bluetoothDevices
            }

            // The row inside: the list sets its delegates' x.
            delegate: Item {
                required property var modelData

                width: ListView.view.width
                height: row.height

                ListRow {
                    id: row

                    x: 6
                    width: parent.width - 12
                    icon: page.center.bluetoothDeviceIcon(modelData.icon)
                    title: modelData.deviceName
                    subtitle: {
                        if (modelData.pairing)
                            return "Pairing…";

                        if (modelData.state === BluetoothDeviceState.Connecting)
                            return "Connecting…";

                        if (modelData.state === BluetoothDeviceState.Disconnecting)
                            return "Disconnecting…";

                        if (modelData.connected)
                            return modelData.batteryAvailable ? "Connected · " + Math.round(modelData.battery * 100) + "%" : "Connected";

                        return modelData.paired ? "Paired" : "";
                    }
                    highlighted: modelData.connected
                    detailsAvailable: modelData.paired
                    onClicked: page.center.selectBluetooth(modelData)
                    onDetailsRequested: page.center.showBluetoothDetails(modelData)
                }

            }

        }

    }

}
