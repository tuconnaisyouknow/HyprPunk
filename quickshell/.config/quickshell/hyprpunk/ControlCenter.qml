import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: controlCenter

    required property var shellState
    property bool opened: false
    // Opened from a keybind: takes the keyboard so Escape closes it right away.
    property bool openedByKeybind: false
    // Hover state of the right-most bar pill, the panel grows out of it.
    property bool pillHovered: false
    property bool panelHovered: false
    property real retainedHeight: 0
    property real progress: opened ? 1 : 0
    readonly property int panelWidth: 378
    // Geometry of that pill (screen coordinates), published by the bar.
    readonly property var pill: shellState.controlPill
    property string page: "main"
    property var passwordNetwork: null
    property string powerProfile: "balanced"
    property var powerProfiles: []
    property bool bluetoothPowerPending: false
    // SMBIOS chassis types: Portable, Laptop, Notebook, Hand Held, Sub Notebook,
    // Tablet, Convertible, Detachable.
    readonly property bool laptopChassis: [8, 9, 10, 11, 14, 30, 31, 32].includes(parseInt(chassisTypeFile.text()))
    readonly property bool hasLaptopBattery: UPower.displayDevice.ready && UPower.displayDevice.isLaptopBattery && UPower.displayDevice.isPresent
    readonly property bool isLaptop: laptopChassis || hasLaptopBattery
    readonly property bool powerProfilesAvailable: isLaptop && powerProfiles.length > 1
    property int brightness: 0
    // Keyboard layout and locale profiles ("fr" or "us"), kept by the hyprpunk scripts.
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/hyprpunk"
    property string keyboardLayout: "us"
    property string localeLanguage: "us"
    property string localeRegional: "fr"
    readonly property var localeProfiles: [{
        "id": "fr",
        "name": "French",
        "locale": "fr_FR.UTF-8"
    }, {
        "id": "us",
        "name": "English",
        "locale": "en_US.UTF-8"
    }]
    property int pendingBrightness: 0
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property var audio: audioSink !== null ? audioSink.audio : null
    readonly property int volume: audio !== null ? Math.round(audio.volume * 100) : 0
    readonly property bool muted: audio !== null && audio.muted
    readonly property var wifiDevice: {
        for (const device of Networking.devices.values) {
            if (device.type === DeviceType.Wifi)
                return device;

        }
        return null;
    }
    readonly property bool wiredConnected: {
        for (const device of Networking.devices.values) {
            if (device.type === DeviceType.Wired && device.connected)
                return true;

        }
        return false;
    }
    readonly property var wifiNetworks: {
        if (wifiDevice === null || !Networking.wifiEnabled)
            return [];

        return wifiDevice.networks.values.slice().sort((a, b) => {
            return (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength);
        });
    }
    readonly property var activeWifi: wifiNetworks.length > 0 && wifiNetworks[0].connected ? wifiNetworks[0] : null
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothEnabled: adapter !== null && adapter.enabled
    readonly property var bluetoothDevices: {
        if (adapter === null || !adapter.enabled)
            return [];

        return adapter.devices.values.filter((device) => {
            return device.paired || (device.deviceName !== "" && !/^([0-9A-F]{2}[-:]){5}[0-9A-F]{2}$/i.test(device.deviceName));
        }).sort((a, b) => {
            return (b.connected - a.connected) || (b.paired - a.paired) || a.deviceName.localeCompare(b.deviceName);
        });
    }
    readonly property var connectedBluetooth: bluetoothDevices.filter((device) => {
        return device.connected;
    })

    function lerp(from, to) {
        return from + (to - from) * progress;
    }

    function close() {
        opened = false;
    }

    function wifiIcon(strength) {
        const icons = ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"];
        return icons[Math.max(0, Math.min(icons.length - 1, Math.floor(strength * icons.length)))];
    }

    function wifiSubtitle() {
        if (!Networking.wifiEnabled)
            return "Off";

        if (activeWifi !== null)
            return activeWifi.name;

        return wiredConnected ? "Ethernet" : "Not connected";
    }

    function toggleBluetooth() {
        if (adapter === null)
            return ;

        // BlueZ refuses to power an rfkill-blocked adapter: lift the block first,
        // the adapter is powered once it is reported as unblocked.
        if (!adapter.enabled && adapter.state === BluetoothAdapterState.Blocked)
            rfkillUnblockProcess.running = true;
        else
            adapter.enabled = !adapter.enabled;
    }

    function bluetoothSubtitle() {
        if (adapter === null)
            return "Unavailable";

        if (!adapter.enabled)
            return "Off";

        if (connectedBluetooth.length === 1)
            return connectedBluetooth[0].deviceName;

        if (connectedBluetooth.length > 1)
            return connectedBluetooth.length + " devices";

        return "On";
    }

    function bluetoothDeviceIcon(icon) {
        if (icon.startsWith("audio-headset") || icon.startsWith("audio-headphones"))
            return "󰋋";

        if (icon.startsWith("audio"))
            return "󰓃";

        if (icon.startsWith("input-mouse"))
            return "󰍽";

        if (icon.startsWith("input-keyboard"))
            return "󰌌";

        if (icon.startsWith("input-gaming"))
            return "󰊴";

        if (icon.startsWith("phone"))
            return "󰏲";

        return "󰂯";
    }

    function selectWifi(network) {
        if (network.connected) {
            network.disconnect();
        } else if (network.known || network.security === WifiSecurityType.Open) {
            passwordNetwork = null;
            network.connect();
        } else {
            passwordNetwork = network;
            passwordInput.text = "";
            passwordInput.forceActiveFocus();
        }
    }

    function selectBluetooth(device) {
        if (device.connected) {
            device.disconnect();
        } else if (device.paired) {
            device.connect();
        } else {
            device.trusted = true;
            device.pair();
        }
    }

    function powerProfileIcon() {
        if (powerProfile === "performance")
            return "󰓅";

        if (powerProfile === "power-saver")
            return "󰌪";

        return "󰾅";
    }

    function cyclePowerProfile() {
        if (powerProfileSetProcess.running || powerProfiles.length < 2)
            return ;

        const next = powerProfiles[(powerProfiles.indexOf(powerProfile) + 1) % powerProfiles.length];
        powerProfile = next;
        powerProfileSetProcess.command = ["powerprofilesctl", "set", next];
        powerProfileSetProcess.running = true;
    }

    function volumeIcon() {
        if (muted)
            return "";

        if (volume === 0)
            return "";

        if (volume < 34)
            return "";

        if (volume < 67)
            return "";

        return "";
    }

    // category is "language" or "regional".
    function setLocale(category, profile) {
        Quickshell.execDetached([Quickshell.env("HOME") + "/Scripts/locale-profilectl.sh", "set-" + category, profile]);
    }

    function brightnessIcon() {
        const icons = ["", "", "", "", "", "", "", "", ""];
        return icons[Math.min(icons.length - 1, Math.floor(brightness * icons.length / 101))];
    }

    onOpenedChanged: {
        shellState.controlCenterOpen = opened;
        if (opened) {
            powerProfileProcess.running = true;
            brightnessProcess.running = true;
            panel.forceActiveFocus();
        } else {
            openedByKeybind = false;
            page = "main";
            passwordNetwork = null;
            // Set after the page reset, which would otherwise retain the old height.
            retainedHeight = 0;
        }
    }
    onPageChanged: {
        // panel.height still holds the previous page's height at this point.
        retainedHeight = Math.max(retainedHeight, panel.height);
    }
    onPasswordNetworkChanged: {
        if (passwordNetwork === null && !pillHovered && !panelHovered)
            closeDelay.restart();

    }
    implicitWidth: panelWidth + pill.right
    implicitHeight: 680 + pill.top
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hyprpunk-control-center"
    WlrLayershell.keyboardFocus: !opened ? WlrKeyboardFocus.None : openedByKeybind ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

    anchors {
        top: true
        right: true
    }

    Connections {
        function onControlPillHoveredChanged() {
            if (controlCenter.shellState.controlPillScreen !== controlCenter.screen)
                return ;

            controlCenter.pillHovered = controlCenter.shellState.controlPillHovered;
            if (controlCenter.pillHovered) {
                closeDelay.stop();
                openDelay.restart();
            } else {
                openDelay.stop();
                closeDelay.restart();
            }
        }

        function onPanelRequestsChanged() {
            const request = controlCenter.shellState.panelRequest;
            const target = request.screen || (Hyprland.focusedMonitor !== null ? Hyprland.focusedMonitor.name : "");
            if (request.panel !== "controlcenter" || target !== controlCenter.screen.name)
                return ;

            const action = request.action;
            const open = action === "open" || (action === "toggle" && !controlCenter.opened);
            openDelay.stop();
            closeDelay.stop();
            if (open) {
                controlCenter.openedByKeybind = true;
                controlCenter.opened = true;
            } else {
                controlCenter.close();
            }
        }

        target: controlCenter.shellState
    }

    // Hover area around the panel. After switching to a shorter page it keeps the
    // previous height, so the pointer is not suddenly outside and the panel
    // does not close under it.
    Item {
        id: hoverZone

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: controlCenter.pill.top
        anchors.rightMargin: controlCenter.pill.right
        // Nothing while closed, so the pill below gets the pointer.
        width: controlCenter.progress > 0 ? panel.width : 0
        height: Math.max(panel.height, controlCenter.retainedHeight)

        HoverHandler {
            onHoveredChanged: {
                controlCenter.panelHovered = hovered;
                if (hovered) {
                    closeDelay.stop();
                    // Caught again while folding back onto the pill.
                    controlCenter.opened = true;
                } else {
                    controlCenter.retainedHeight = 0;
                    closeDelay.restart();
                }
            }
        }

        // Grows out of the pill like the calendar and the player: from the pill's
        // color and size to the blurred panel.
        ClippingRectangle {
            id: panel

            property real fullHeight: pages.implicitHeight + 28

            anchors.top: parent.top
            anchors.right: parent.right
            visible: controlCenter.progress > 0
            width: controlCenter.lerp(controlCenter.pill.width, controlCenter.panelWidth)
            height: controlCenter.lerp(controlCenter.pill.height, fullHeight)
            // The pill's corners: rounder ones would let the pill's show under the panel.
            radius: controlCenter.pill.height / 2
            // Lets the notification popups move below the panel instead of hiding behind it.
            onHeightChanged: {
                controlCenter.shellState.controlCenterBottomScreen = controlCenter.screen;
                controlCenter.shellState.controlCenterBottom = controlCenter.progress > 0 ? controlCenter.pill.top + height : 0;
            }
            color: "transparent"
            focus: true
            Keys.onEscapePressed: {
                if (controlCenter.page !== "main")
                    controlCenter.page = "main";
                else
                    controlCenter.close();
            }

            // Same card as the island panels: surface0 (the pill) to base at 0.9 (blurred by a
            // layer rule) with the glass rim, opaque from the start so the pill itself seems to grow.
            GlassSurface {
                radius: panel.radius
                tinted: false
                backgroundColor: Qt.rgba(controlCenter.lerp(49, 30) / 255, controlCenter.lerp(50, 30) / 255, controlCenter.lerp(68, 46) / 255, controlCenter.lerp(1, 0.9))
            }

            HoverHandler {
                onHoveredChanged: {
                    // Back inside the real panel: the retained zone is no longer needed.
                    if (hovered)
                        controlCenter.retainedHeight = 0;

                }
            }

            // Laid out at full size, only uncovered while the panel grows.
            Item {
                id: pages

                opacity: controlCenter.opened ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }

                }

                implicitHeight: controlCenter.page === "wifi" ? wifiPage.implicitHeight : controlCenter.page === "bluetooth" ? bluetoothPage.implicitHeight : controlCenter.page === "locale" ? localePage.implicitHeight : mainPage.implicitHeight
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 14
                anchors.topMargin: 14
                width: controlCenter.panelWidth - 28

                ColumnLayout {
                    id: mainPage

                    width: parent.width
                    visible: controlCenter.page === "main"
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: connectivity.implicitHeight + 20
                            radius: 18
                            color: "transparent"

                            GlassSurface {
                                radius: parent.radius
                            }

                            ColumnLayout {
                                id: connectivity

                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 6

                                ControlTile {
                                    Layout.fillWidth: true
                                    icon: Networking.wifiEnabled ? (controlCenter.activeWifi !== null ? controlCenter.wifiIcon(controlCenter.activeWifi.signalStrength) : "󰤯") : "󰤭"
                                    title: "Wi-Fi"
                                    subtitle: controlCenter.wifiSubtitle()
                                    active: Networking.wifiEnabled
                                    expandable: controlCenter.wifiDevice !== null
                                    onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                                    onExpandRequested: controlCenter.page = "wifi"
                                }

                                ControlTile {
                                    Layout.fillWidth: true
                                    icon: controlCenter.bluetoothEnabled ? (controlCenter.connectedBluetooth.length > 0 ? "󰂱" : "󰂯") : "󰂲"
                                    title: "Bluetooth"
                                    subtitle: controlCenter.bluetoothSubtitle()
                                    active: controlCenter.bluetoothEnabled
                                    expandable: controlCenter.adapter !== null
                                    onToggled: controlCenter.toggleBluetooth()
                                    onExpandRequested: controlCenter.page = "bluetooth"
                                }

                                ControlTile {
                                    Layout.fillWidth: true
                                    icon: "󰗊"
                                    title: "Locale"
                                    subtitle: controlCenter.localeLanguage.toUpperCase() + " · " + controlCenter.localeRegional.toUpperCase() + " formats"
                                    expandable: true
                                    onToggled: controlCenter.page = "locale"
                                    onExpandRequested: controlCenter.page = "locale"
                                }

                            }

                        }

                        ColumnLayout {
                            Layout.fillWidth: false
                            Layout.preferredWidth: 132
                            Layout.fillHeight: true
                            spacing: 12

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 18
                                color: "transparent"

                                GlassSurface {
                                    radius: parent.radius
                                }

                                ControlTile {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 8
                                    icon: "󰂛"
                                    title: "Focus"
                                    subtitle: controlCenter.shellState.doNotDisturb ? "On" : "Off"
                                    active: controlCenter.shellState.doNotDisturb
                                    onToggled: controlCenter.shellState.doNotDisturb = !controlCenter.shellState.doNotDisturb
                                }

                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                visible: controlCenter.powerProfilesAvailable
                                radius: 18
                                color: "transparent"

                                GlassSurface {
                                    radius: parent.radius
                                }

                                ControlTile {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 8
                                    icon: controlCenter.powerProfileIcon()
                                    title: "Power"
                                    subtitle: controlCenter.powerProfile === "power-saver" ? "Saver" : controlCenter.powerProfile === "performance" ? "Performance" : "Balanced"
                                    active: controlCenter.powerProfile !== "balanced"
                                    onToggled: controlCenter.cyclePowerProfile()
                                }

                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 18
                                color: "transparent"

                                GlassSurface {
                                    radius: parent.radius
                                }

                                // A click switches between the AZERTY and QWERTY profiles.
                                ControlTile {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 8
                                    icon: "󰌌"
                                    title: "Keyboard"
                                    subtitle: controlCenter.keyboardLayout === "fr" ? "FR AZERTY" : "US QWERTY"
                                    onToggled: Quickshell.execDetached([Quickshell.env("HOME") + "/Scripts/keyboard-layoutctl.sh", "set", controlCenter.keyboardLayout === "fr" ? "us" : "fr"])
                                }

                            }

                        }

                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: brightnessColumn.implicitHeight + 24
                        radius: 18
                        color: "transparent"

                        GlassSurface {
                            radius: parent.radius
                        }

                        ColumnLayout {
                            id: brightnessColumn

                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            Text {
                                text: "Display"
                                color: "#cba6f7"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }

                            HorizontalSlider {
                                Layout.fillWidth: true
                                value: controlCenter.brightness / 100
                                icon: controlCenter.brightnessIcon()
                                onValueRequested: (value) => {
                                    const requestedBrightness = Math.max(1, Math.round(value * 100));
                                    controlCenter.brightness = requestedBrightness;
                                    controlCenter.pendingBrightness = requestedBrightness;
                                    brightnessWriteDelay.restart();
                                }
                            }

                        }

                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: soundColumn.implicitHeight + 24
                        radius: 18
                        color: "transparent"

                        GlassSurface {
                            radius: parent.radius
                        }

                        ColumnLayout {
                            id: soundColumn

                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: "Sound"
                                    color: "#cba6f7"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                }

                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignRight
                                    elide: Text.ElideRight
                                    text: controlCenter.audioSink !== null ? (controlCenter.audioSink.description || controlCenter.audioSink.name) : "No output"
                                    color: soundSettingsHover.hovered ? "#cba6f7" : "#b4befe"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12

                                    HoverHandler {
                                        id: soundSettingsHover

                                        cursorShape: Qt.PointingHandCursor
                                    }

                                    TapHandler {
                                        onTapped: {
                                            controlCenter.close();
                                            Quickshell.execDetached(["mate-volume-control"]);
                                        }
                                    }

                                }

                            }

                            HorizontalSlider {
                                Layout.fillWidth: true
                                value: controlCenter.muted ? 0 : controlCenter.volume / 100
                                icon: controlCenter.volumeIcon()
                                onValueRequested: (value) => {
                                    if (controlCenter.audio !== null) {
                                        controlCenter.audio.muted = false;
                                        controlCenter.audio.volume = value;
                                    }
                                }
                                onIconClicked: {
                                    if (controlCenter.audio !== null)
                                        controlCenter.audio.muted = !controlCenter.audio.muted;

                                }
                            }

                        }

                    }
                }

                ColumnLayout {
                    id: wifiPage

                    width: parent.width
                    visible: controlCenter.page === "wifi"
                    spacing: 12

                    PageHeader {
                        Layout.fillWidth: true
                        title: "Wi-Fi"
                        checked: Networking.wifiEnabled
                        onBackRequested: controlCenter.page = "main"
                        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                    }

                    IconText {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                        visible: controlCenter.wifiNetworks.length === 0
                        icon: Networking.wifiEnabled ? "󰤯" : "󰤭"
                        text: Networking.wifiEnabled ? "Searching for networks…" : "Wi-Fi is off"
                        color: "#7f849c"
                        font.pixelSize: 14
                        font.weight: Font.Normal


                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(contentHeight, 340)
                        visible: controlCenter.wifiNetworks.length > 0
                        clip: true
                        spacing: 4
                        model: controlCenter.wifiNetworks

                        delegate: ListRow {
                            required property var modelData

                            width: ListView.view.width
                            icon: controlCenter.wifiIcon(modelData.signalStrength)
                            title: modelData.name
                            subtitle: modelData.stateChanging ? (modelData.connected ? "Disconnecting…" : "Connecting…") : modelData.connected ? "Connected" : modelData.known ? "Saved" : ""
                            trailing: modelData.security === WifiSecurityType.Open ? "" : "󰌾"
                            highlighted: modelData.connected
                            onClicked: controlCenter.selectWifi(modelData)

                            Connections {
                                function onConnectionFailed(reason) {
                                    if (reason === ConnectionFailReason.NoSecrets)
                                        controlCenter.selectWifi(modelData);

                                }

                                target: modelData
                            }

                        }

                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: passwordColumn.implicitHeight + 24
                        visible: controlCenter.passwordNetwork !== null
                        radius: 18
                        color: "transparent"

                        GlassSurface {
                            radius: parent.radius
                        }

                        ColumnLayout {
                            id: passwordColumn

                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            IconText {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                icon: "󰌾"
                                text: (controlCenter.passwordNetwork !== null ? controlCenter.passwordNetwork.name : "")
                                color: "#cba6f7"
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 34
                                radius: 12
                                // Recessed field inside the glass card.
                                color: Qt.rgba(17 / 255, 17 / 255, 27 / 255, 0.45)

                                TextInput {
                                    id: passwordInput

                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    verticalAlignment: TextInput.AlignVCenter
                                    echoMode: TextInput.Password
                                    color: "#cba6f7"
                                    selectionColor: "#cba6f7"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    Keys.onEscapePressed: controlCenter.passwordNetwork = null
                                    onAccepted: {
                                        if (controlCenter.passwordNetwork !== null && text !== "") {
                                            controlCenter.passwordNetwork.connectWithPsk(text);
                                            controlCenter.passwordNetwork = null;
                                            panel.forceActiveFocus();
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: parent.text === ""
                                        text: "Password, then Enter"
                                        color: "#6c7086"
                                        font: parent.font
                                    }

                                }

                            }

                        }

                    }

                }

                ColumnLayout {
                    id: bluetoothPage

                    width: parent.width
                    visible: controlCenter.page === "bluetooth"
                    spacing: 12

                    PageHeader {
                        Layout.fillWidth: true
                        title: "Bluetooth"
                        checked: controlCenter.bluetoothEnabled
                        onBackRequested: controlCenter.page = "main"
                        onToggled: controlCenter.toggleBluetooth()
                    }

                    IconText {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                        visible: controlCenter.bluetoothDevices.length === 0
                        icon: controlCenter.bluetoothEnabled ? "󰂰" : "󰂲"
                        text: controlCenter.bluetoothEnabled ? "Searching for devices…" : "Bluetooth is off"
                        color: "#7f849c"
                        font.pixelSize: 14
                        font.weight: Font.Normal


                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(contentHeight, 340)
                        visible: controlCenter.bluetoothDevices.length > 0
                        clip: true
                        spacing: 4
                        model: controlCenter.bluetoothDevices

                        delegate: ListRow {
                            required property var modelData

                            width: ListView.view.width
                            icon: controlCenter.bluetoothDeviceIcon(modelData.icon)
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
                            onClicked: controlCenter.selectBluetooth(modelData)
                        }

                    }

                }


                ColumnLayout {
                    id: localePage

                    width: parent.width
                    visible: controlCenter.page === "locale"
                    spacing: 6

                    PageHeader {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 6
                        title: "Locale"
                        toggleVisible: false
                        onBackRequested: controlCenter.page = "main"
                    }

                    Text {
                        Layout.topMargin: 0
                        text: "Interface language"
                        color: "#b4befe"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }

                    Repeater {
                        model: controlCenter.localeProfiles

                        ListRow {
                            required property var modelData

                            Layout.fillWidth: true
                            icon: modelData.id.toUpperCase()
                            title: modelData.name
                            subtitle: modelData.locale
                            trailing: controlCenter.localeLanguage === modelData.id ? "\uf00c" : ""
                            highlighted: controlCenter.localeLanguage === modelData.id
                            onClicked: controlCenter.setLocale("language", modelData.id)
                        }

                    }

                    Text {
                        Layout.topMargin: 8
                        text: "Regional formats"
                        color: "#b4befe"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }

                    Repeater {
                        model: controlCenter.localeProfiles

                        ListRow {
                            required property var modelData

                            Layout.fillWidth: true
                            icon: modelData.id.toUpperCase()
                            title: modelData.name
                            subtitle: modelData.locale
                            trailing: controlCenter.localeRegional === modelData.id ? "\uf00c" : ""
                            highlighted: controlCenter.localeRegional === modelData.id
                            onClicked: controlCenter.setLocale("regional", modelData.id)
                        }

                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        wrapMode: Text.WordWrap
                        text: "Restart open applications to apply it."
                        color: "#7f849c"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }

                }

            }

            Behavior on fullHeight {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }

            }

        }

    }

    Timer {
        id: openDelay

        interval: 120
        onTriggered: controlCenter.opened = true
    }

    Timer {
        id: closeDelay

        interval: 380
        onTriggered: {
            // Keep the panel open while a Wi-Fi password is being typed.
            if (!controlCenter.pillHovered && !controlCenter.panelHovered && controlCenter.passwordNetwork === null)
                controlCenter.opened = false;

        }
    }

    Behavior on progress {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }

    }

    Binding {
        target: controlCenter.wifiDevice
        property: "scannerEnabled"
        value: true
        when: controlCenter.wifiDevice !== null && controlCenter.opened && controlCenter.page === "wifi"
    }

    Binding {
        target: controlCenter.adapter
        property: "discovering"
        value: true
        when: controlCenter.bluetoothEnabled && controlCenter.opened && controlCenter.page === "bluetooth"
    }

    PwObjectTracker {
        objects: controlCenter.audioSink !== null ? [controlCenter.audioSink] : []
    }

    Process {
        id: powerProfileProcess

        // Profile lines look like "* balanced:" (active) or "  performance:".
        command: ["powerprofilesctl", "list"]
        running: true
        onExited: (exitCode) => {
            if (exitCode !== 0)
                controlCenter.powerProfiles = [];

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
                        controlCenter.powerProfile = match[2];

                }
                controlCenter.powerProfiles = profiles.sort((a, b) => {
                    return order.indexOf(a) - order.indexOf(b);
                });
            }
        }

    }

    Process {
        id: rfkillUnblockProcess

        command: ["rfkill", "unblock", "bluetooth"]
        onExited: (exitCode) => {
            if (exitCode !== 0)
                return ;

            controlCenter.bluetoothPowerPending = true;
            bluetoothPowerTimeout.restart();
            bluetoothPowerConnection.powerIfReady();
        }
    }

    Connections {
        id: bluetoothPowerConnection

        function powerIfReady() {
            const adapter = controlCenter.adapter;
            // Still blocked, or BlueZ is restoring power on its own after the unblock.
            if (!controlCenter.bluetoothPowerPending || adapter === null || adapter.state === BluetoothAdapterState.Blocked || adapter.state === BluetoothAdapterState.Enabling)
                return ;

            controlCenter.bluetoothPowerPending = false;
            if (adapter.state === BluetoothAdapterState.Disabled)
                adapter.enabled = true;

        }

        function onStateChanged() {
            powerIfReady();
        }

        target: controlCenter.adapter
    }

    Timer {
        id: bluetoothPowerTimeout

        interval: 3000
        onTriggered: controlCenter.bluetoothPowerPending = false
    }

    Process {
        id: powerProfileSetProcess

        // Re-read the real state, the daemon may refuse or hold the profile.
        onExited: powerProfileProcess.running = true
    }

    FileView {
        path: controlCenter.stateDir + "/keyboard-layout"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: controlCenter.keyboardLayout = text().trim() || "us"
    }

    FileView {
        path: controlCenter.stateDir + "/locale-language"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: controlCenter.localeLanguage = text().trim() || "us"
    }

    FileView {
        path: controlCenter.stateDir + "/locale-regional"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: controlCenter.localeRegional = text().trim() || "fr"
    }

    FileView {
        id: chassisTypeFile

        path: "/sys/class/dmi/id/chassis_type"
        preload: true
        blockLoading: true
        printErrors: false
    }

    Timer {
        id: brightnessWriteDelay

        interval: 35
        onTriggered: Quickshell.execDetached(["brightnessctl", "set", controlCenter.pendingBrightness + "%"])
    }

    Process {
        id: brightnessProcess

        command: ["brightnessctl", "-m"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split(",");
                if (fields.length >= 4)
                    controlCenter.brightness = parseInt(fields[3]);

            }
        }

    }

    Process {
        command: ["udevadm", "monitor", "--kernel", "--subsystem-match=backlight"]
        running: true

        stdout: SplitParser {
            onRead: {
                if (!brightnessWriteDelay.running)
                    brightnessProcess.running = true;

            }
        }

    }

    mask: Region {
        item: hoverZone
    }

}
