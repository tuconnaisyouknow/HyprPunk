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
// their page), then the display, the sound and the background apps. The keys move
// around it as a grid.
ControlPage {
    id: page

    // The background apps' page, with this app's menu unfolded (or none).
    signal trayRequested(var item)

    function wifiSubtitle() {
        if (!Networking.wifiEnabled)
            return "Off";

        if (NetworkStatus.activeWifi !== null)
            return NetworkStatus.activeWifi.name;

        return NetworkStatus.wiredConnected ? "Ethernet" : "Not connected";
    }

    function bluetoothSubtitle() {
        if (BluetoothStatus.adapter === null)
            return "Unavailable";

        if (!BluetoothStatus.enabled)
            return "Off";

        if (BluetoothStatus.connected.length === 1)
            return BluetoothStatus.connected[0].deviceName;

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

    pageName: "main"
    spacing: Metrics.spacing.large

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
                icon: Networking.wifiEnabled ? (NetworkStatus.activeWifi !== null ? Icons.wifi(NetworkStatus.activeWifi.signalStrength, Vpn.connection !== null) : "󰤯") : "󰤭"
                title: "Wi-Fi"
                subtitle: page.wifiSubtitle()
                active: Networking.wifiEnabled
                // Its page also holds the VPNs, Wi-Fi or not.
                expandable: true
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                onExpandRequested: page.stack.push("wifi")
            }

            ControlTile {
                Layout.fillWidth: true
                icon: BluetoothStatus.enabled ? (BluetoothStatus.connected.length > 0 ? "󰂱" : "󰂯") : "󰂲"
                title: "Bluetooth"
                subtitle: page.bluetoothSubtitle()
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

            ControlTile {
                Layout.fillWidth: true
                Layout.fillHeight: true
                icon: "󰂛"
                title: "Focus"
                subtitle: ShellState.doNotDisturb ? "On" : "Off"
                active: ShellState.doNotDisturb
                onToggled: ShellState.doNotDisturb = !ShellState.doNotDisturb
            }

            ControlTile {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: PowerProfile.available
                icon: Icons.powerProfile(PowerProfile.current)
                title: "Power"
                subtitle: PowerProfile.current === "power-saver" ? "Saver" : PowerProfile.current === "performance" ? "Performance" : "Balanced"
                active: PowerProfile.current !== "balanced"
                onToggled: PowerProfile.cycle()
            }

        }

    }

    // Below the two columns. Without a charge limit, caffeine spans both
    // so the grid stays even.
    RowLayout {
        Layout.fillWidth: true
        spacing: tileColumns.spacing

        ControlTile {
            Layout.fillWidth: true
            Layout.preferredWidth: tileColumns.columnWidth
            icon: ShellState.caffeine ? "󰅶" : "󰾪"
            title: "Caffeine"
            subtitle: page.caffeineSubtitle()
            active: ShellState.caffeine
            expandable: true
            onToggled: ShellState.toggleCaffeine()
            onExpandRequested: page.stack.push("caffeine")
        }

        ControlTile {
            Layout.fillWidth: true
            Layout.preferredWidth: tileColumns.columnWidth
            visible: ChargeLimit.current > 0
            icon: Icons.chargeLimit(ChargeLimit.current)
            title: "Charge limit"
            subtitle: ChargeLimit.current < 100 ? ChargeLimit.current + " %" : "Off"
            active: ChargeLimit.current < 100
            expandable: true
            onToggled: {
                if (ChargeLimit.writable)
                    ChargeLimit.toggle();
                else
                    page.stack.push("chargeLimit");
            }
            onExpandRequested: page.stack.push("chargeLimit")
        }

    }

    // The brightness when the screen has a backlight, and the glass style.
    ControlBlock {
        Layout.fillWidth: true
        implicitHeight: brightnessColumn.implicitHeight + 2 * Metrics.spacing.large

        ColumnLayout {
            id: brightnessColumn

            anchors.fill: parent
            anchors.margins: Metrics.spacing.large
            spacing: Metrics.spacing.normal

            Text {
                text: "Display"
                color: Colors.primary
                font.family: Metrics.font
                font.pixelSize: Metrics.text.emphasis
                font.weight: Font.Bold
            }

            HorizontalSlider {
                Layout.fillWidth: true
                visible: Devices.hasBacklight
                value: Devices.brightness / 100
                icon: Icons.brightness(Devices.brightness)
                onValueRequested: (value) => {
                    return Devices.setBrightness(Math.max(1, Math.round(value * 100)));
                }
            }

            SegmentedControl {
                Layout.fillWidth: true
                compact: true
                value: Session.glassStyle
                options: [{
                    "value": "classic",
                    "icon": "󰆧",
                    "label": "Classic"
                }, {
                    "value": "liquid",
                    "icon": "󰖌",
                    "label": "Liquid"
                }]
                onSelected: (value) => {
                    return Quickshell.execDetached([Session.scripts + "/glassctl.sh", "set", value]);
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
                    model: Tray.items

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

    // Read again each time the panel opens: another app may have changed them.
    ServiceRef {
        service: PowerProfile
        active: page.stack.opened
    }

    ServiceRef {
        service: ChargeLimit
        active: page.stack.opened
    }

}
