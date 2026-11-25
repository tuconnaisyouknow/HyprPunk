import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs.components
import qs.config
import qs.services
import qs.state
import qs.theme

// The control center's first page: the tiles you switch with a click (their arrow opens
// their page), then the brightness, the sound and the background apps. The keys move
// around it as a grid.
ControlPage {
    id: page

    // The background apps' page, with this app's menu unfolded (or none).
    signal trayRequested(var item)

    function wifiSubtitle() {
        if (!Networking.wifiEnabled)
            return "Off";

        return NetworkStatus.wiredConnected ? "Ethernet" : "Not connected";
    }

    function bluetoothSubtitle() {
        if (BluetoothStatus.adapter === null)
            return "Unavailable";

        if (!BluetoothStatus.enabled)
            return "Off";

        if (BluetoothStatus.connected.length > 1)
            return BluetoothStatus.connected.length + " devices";

        return "On";
    }

    // "Off", "On" until turned off, or the time left: "45 min left", "1 h 30 left".
    function caffeineSubtitle() {
        if (!ShellState.caffeine)
            return "Off";

        if (ShellState.caffeineUntil <= 0)
            return "On";

        const minutes = Math.max(1, ShellState.caffeineMinutesLeft);
        if (minutes < 60)
            return minutes + " min left";

        return Math.floor(minutes / 60) + " h " + String(minutes % 60).padStart(2, "0") + " left";
    }

    // "Off", "On", or the schedule's next turn: "Until 7:00", "From 21:00".
    function nightLightSubtitle() {
        if (NightLightSettings.mode !== "schedule")
            return NightLight.active ? "On" : "Off";

        // Turned against the schedule, it holds until the schedule's own next turn: the
        // hours still tell it.
        return NightLight.active ? "Until " + NightLightSettings.hourText(NightLightSettings.to) : "From " + NightLightSettings.hourText(NightLightSettings.from);
    }

    pageName: "main"
    spacing: Metrics.spacing.large

    // Its sliders show the brightness and the volume as they change: no OSD for them
    // while you see the page.
    ServiceRef {
        service: Osd.brightnessInSight
        active: page.active && Devices.hasBacklight
    }

    ServiceRef {
        service: Osd.volumeInSight
        active: page.active
    }

    // Two columns of tiles, of the same width.
    RowLayout {
        id: tileColumns

        readonly property real columnWidth: (width - spacing) / 2

        Layout.fillWidth: true
        spacing: Metrics.spacing.large

        ColumnLayout {
            Layout.preferredWidth: tileColumns.columnWidth
            Layout.alignment: Qt.AlignTop
            spacing: Metrics.spacing.large

            ControlTile {
                Layout.fillWidth: true
                icon: Networking.wifiEnabled ? (NetworkStatus.activeWifi !== null ? Icons.wifi(NetworkStatus.activeWifi.signalStrength, Vpn.connection !== null) : "signal_wifi_0_bar") : "signal_wifi_off"
                title: "Wi-Fi"
                subtitle: page.wifiSubtitle()
                name: Networking.wifiEnabled && NetworkStatus.activeWifi !== null ? NetworkStatus.activeWifi.name : ""
                active: Networking.wifiEnabled
                // Its page also holds the VPNs, Wi-Fi or not.
                expandable: true
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                onExpandRequested: page.stack.push("wifi")
            }

            ControlTile {
                Layout.fillWidth: true
                icon: BluetoothStatus.enabled ? (BluetoothStatus.connected.length > 0 ? "bluetooth_connected" : "bluetooth") : "bluetooth_disabled"
                title: "Bluetooth"
                subtitle: page.bluetoothSubtitle()
                name: BluetoothStatus.enabled && BluetoothStatus.connected.length === 1 ? BluetoothStatus.connected[0].deviceName : ""
                active: BluetoothStatus.enabled
                expandable: BluetoothStatus.adapter !== null
                onToggled: BluetoothStatus.toggle()
                onExpandRequested: page.stack.push("bluetooth")
            }

        }

        ColumnLayout {
            Layout.preferredWidth: tileColumns.columnWidth
            Layout.fillHeight: true
            spacing: Metrics.spacing.large

            // Its icon goes against the schedule until its next turn: leaving the
            // schedule is for its page.
            ControlTile {
                Layout.fillWidth: true
                Layout.fillHeight: true
                icon: "lightbulb"
                title: "Night light"
                subtitle: page.nightLightSubtitle()
                active: NightLight.active
                expandable: true
                onToggled: NightLight.toggle()
                onExpandRequested: page.stack.push("nightlight")
            }

            ControlTile {
                Layout.fillWidth: true
                Layout.fillHeight: true
                icon: "coffee"
                title: "Caffeine"
                subtitle: page.caffeineSubtitle()
                active: ShellState.caffeine
                expandable: true
                onToggled: ShellState.toggleCaffeine()
                onExpandRequested: page.stack.push("caffeine")
            }

        }

    }

    // Only when the screen has a backlight to dim.
    ControlBlock {
        Layout.fillWidth: true
        visible: Devices.hasBacklight
        implicitHeight: brightnessColumn.implicitHeight + 2 * Metrics.spacing.large

        ColumnLayout {
            id: brightnessColumn

            anchors.fill: parent
            anchors.margins: Metrics.spacing.large
            spacing: Metrics.spacing.normal

            Heading {
                text: "Display"
            }

            HorizontalSlider {
                Layout.fillWidth: true
                value: Devices.brightness / 100
                icon: Icons.brightness(Devices.brightness)
                onValueRequested: (value) => {
                    return Devices.setBrightness(Math.max(1, Math.round(value * 100)));
                }
            }

        }

    }

    ControlBlock {
        id: soundBlock

        Layout.fillWidth: true
        implicitHeight: soundColumn.implicitHeight + 2 * Metrics.spacing.large

        // Under the content: the slider keeps its own clicks.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: soundHeader.activate()
        }

        ColumnLayout {
            id: soundColumn

            anchors.fill: parent
            anchors.margins: Metrics.spacing.large
            spacing: Metrics.spacing.normal

            BlockHeader {
                id: soundHeader

                block: soundBlock
                title: "Sound"
                detail: Audio.sink !== null ? (Audio.sink.description || Audio.sink.name) : "No output"
                onActivated: page.stack.push("sound")
            }

            HorizontalSlider {
                Layout.fillWidth: true
                // Muted, the fill keeps its level and turns to the secondary color.
                value: Audio.volume / 100
                accent: Audio.muted ? Colors.secondary : Colors.primary
                iconButton: true
                icon: Icons.volume(Audio.volume, Audio.muted)
                // Up to the volume limit set in the settings.
                onValueRequested: (value) => {
                    return Audio.setVolume(value);
                }
                onIconClicked: Audio.toggleMute()
            }

        }

    }

    // Last, since it changes size with the apps running: an icon brings
    // its app back, the rest of the block opens their page.
    ControlBlock {
        id: trayBlock

        // Named in the header while hovered, in place of a tooltip.
        property var hoveredItem: null

        Layout.fillWidth: true
        visible: Tray.items.length > 0
        implicitHeight: trayColumn.implicitHeight + 2 * Metrics.spacing.large

        // Under the content: the icons keep their own clicks.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: trayHeader.activate()
        }

        ColumnLayout {
            id: trayColumn

            anchors.fill: parent
            anchors.margins: Metrics.spacing.large
            spacing: Metrics.spacing.normal

            BlockHeader {
                id: trayHeader

                block: trayBlock
                title: "Background apps"
                detail: trayBlock.hoveredItem !== null ? Tray.name(trayBlock.hoveredItem) : Tray.items.length + (Tray.items.length === 1 ? " app" : " apps")
                onActivated: page.trayRequested(null)
            }

            // The icons' halo is wider than the icon: pulled left so the
            // first icon lines up with the title.
            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: -6
                spacing: Metrics.spacing.small

                Repeater {
                    // The icons stay as apps come and go.
                    model: ScriptModel {
                        values: Tray.items
                    }

                    TrayItem {
                        required property var modelData

                        item: modelData
                        onHoveredChanged: {
                            if (hovered)
                                trayBlock.hoveredItem = modelData;
                            else if (trayBlock.hoveredItem === modelData)
                                trayBlock.hoveredItem = null;
                        }
                        onMenuRequested: page.trayRequested(modelData)
                    }

                }

            }

        }

    }

}
