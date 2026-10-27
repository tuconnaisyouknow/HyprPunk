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
    required property var airPods
    property bool opened: false
    // Opened from a keybind: takes the keyboard so Escape closes it right away.
    property bool openedByKeybind: false
    // Hover state of the right-most bar pill, the panel grows out of it.
    property bool pillHovered: false
    property bool panelHovered: false
    property real retainedHeight: 0
    property real progress: opened ? 1 : 0
    readonly property int panelWidth: 452
    // The panel's tallest: a page taller than that scrolls.
    readonly property int panelMaxHeight: 680
    // Geometry of that pill (screen coordinates), published by the bar.
    readonly property var pill: shellState.controlPill
    property string page: "main"
    // Page transition, iOS navigation-like: the sub-page slides in from the right over
    // the main page, which backs off to the left; the other way round going back.
    property string shownPage: "main"
    property string previousPage: "main"
    property real pageProgress: 1
    property var passwordNetwork: null
    // Enterprise network whose credentials are asked on the "enterprise" page.
    property var enterpriseNetwork: null
    // Network connected from the panel: only its failures ask for credentials, not
    // NetworkManager's own reconnections in the background.
    property var requestedWifi: null
    // Saved network and paired device of the detail pages.
    property var detailNetwork: null
    property var detailDevice: null
    // Where the enterprise form goes back to: the list, or the network's details.
    property string enterpriseReturnPage: "wifi"
    // The Bluetooth page, or the sound page for an audio device opened from it.
    property string bluetoothDetailReturnPage: "bluetooth"
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
    readonly property string stateDir: Session.stateDir
    property string keyboardLayout: "us"
    readonly property string localeLanguage: Session.languageProfile
    readonly property string localeRegional: Session.regionalProfile
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
    // The time caffeine's countdown is shown at, ticking while the panel is open.
    property real now: Date.now()
    readonly property var caffeineDurations: [{
        "minutes": 0,
        "label": "Until turned off"
    }, {
        "minutes": 30,
        "label": "30 minutes"
    }, {
        "minutes": 60,
        "label": "1 hour"
    }, {
        "minutes": 120,
        "label": "2 hours"
    }, {
        "minutes": 240,
        "label": "4 hours"
    }]
    // The batteries' charge limit in % (100 when off), 0 without one. Set with
    // battery-limit as a user of the wheel group, once installed (battery/, by
    // install.sh), which also applies it again at boot and around sleep.
    property int chargeLimit: 0
    property bool chargeLimitWritable: false
    // Why the last limit was not set (one the battery refuses), empty otherwise.
    property string chargeLimitError: ""
    // The limit turned back on: the last one under 100.
    property int chargeLimitOn: 80
    readonly property var chargeLimits: [60, 70, 80, 90]
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

    function pageVisible(name) {
        return page === name || (pageProgress < 1 && previousPage === name);
    }

    function pageDepth(name) {
        if (name === "main")
            return 0;

        if (name === "wifiDetail" || name === "bluetoothDetail")
            return 2;

        return name === "enterprise" ? 3 : 1;
    }

    // The page a page goes back to (Escape and the back buttons).
    function parentPage(name) {
        if (name === "enterprise")
            return enterpriseReturnPage;

        if (name === "wifiDetail")
            return "wifi";

        if (name === "bluetoothDetail")
            return bluetoothDetailReturnPage;

        return "main";
    }

    function showWifiDetails(network) {
        detailNetwork = network;
        wifiDetailPage.reset();
        page = "wifiDetail";
    }

    function showBluetoothDetails(device) {
        bluetoothDetailReturnPage = page === "sound" ? "sound" : "bluetooth";
        detailDevice = device;
        page = "bluetoothDetail";
    }

    function pageX(name) {
        // Back towards the main page: the other way round.
        const direction = pageDepth(page) < pageDepth(previousPage) ? -1 : 1;
        const width = panelWidth - 28;
        // pageProgress runs linearly: the slide eases out (cubic), the fades below don't.
        const slide = 1 - Math.pow(1 - pageProgress, 3);
        if (name === page)
            return (1 - slide) * direction * width * 0.3;

        return -slide * direction * width * 0.15;
    }

    function pageOpacity(name) {
        // The page left behind is almost gone before the new one shows, so the two
        // never blur together.
        if (name === page)
            return Math.max(0, Math.min(1, (pageProgress - 0.2) / 0.6));

        return Math.max(0, 1 - pageProgress / 0.35);
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
            requestedWifi = network;
            network.connect();
        } else {
            askWifiSecrets(network);
        }
    }

    // 802.1X networks (NetworkManager's enterprise form), the others a password.
    function isEnterprise(network) {
        return [WifiSecurityType.WpaEap, WifiSecurityType.Wpa2Eap, WifiSecurityType.Wpa3SuiteB192, WifiSecurityType.DynamicWep, WifiSecurityType.Leap].includes(network.security);
    }

    function askWifiSecrets(network) {
        if (isEnterprise(network)) {
            passwordNetwork = null;
            enterpriseNetwork = network;
            enterpriseReturnPage = "wifi";
            enterprisePage.reset();
            page = "enterprise";
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

    function toggleCaffeine() {
        if (shellState.caffeine)
            shellState.caffeine = false;
        else
            shellState.setCaffeine(0);
        now = Date.now();
    }

    function chooseCaffeine(minutes) {
        shellState.setCaffeine(minutes);
        now = Date.now();
    }

    // "Off", "On" until turned off, or the time left: "45 min left", "1 h 30 left".
    function caffeineSubtitle() {
        if (!shellState.caffeine)
            return "Off";

        if (shellState.caffeineUntil <= 0)
            return "On";

        const minutes = Math.max(1, Math.ceil((shellState.caffeineUntil - now) / 60000));
        if (minutes < 60)
            return minutes + " min left";

        return Math.floor(minutes / 60) + " h " + String(minutes % 60).padStart(2, "0") + " left";
    }

    function setChargeLimit(limit) {
        if (!chargeLimitWritable)
            return ;

        chargeLimit = limit;
        if (limit < 100)
            chargeLimitOn = limit;

        chargeLimitError = "";
        chargeLimitSetProcess.command = ["battery-limit", "set", String(limit)];
        chargeLimitSetProcess.running = true;
    }

    // A battery filled up to the limit, full without one.
    function chargeLimitIcon(limit) {
        return limit >= 100 ? "󰁹" : String.fromCodePoint(0xf007a + Math.max(0, Math.min(8, Math.round(limit / 10) - 1)));
    }

    function toggleChargeLimit() {
        setChargeLimit(chargeLimit < 100 ? 100 : chargeLimitOn);
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
            chargeLimitError = "";
            chargeLimitProcess.running = true;
            panel.forceActiveFocus();
        } else {
            openedByKeybind = false;
            page = "main";
            // Folds back without the page transition.
            pageAnimation.complete();
            passwordNetwork = null;
            enterpriseNetwork = null;
            requestedWifi = null;
            detailNetwork = null;
            detailDevice = null;
            // Set after the page reset, which would otherwise retain the old height.
            retainedHeight = 0;
        }
    }
    onPageChanged: {
        // panel.height still holds the previous page's height at this point.
        retainedHeight = Math.max(retainedHeight, panel.height);
        previousPage = shownPage;
        shownPage = page;
        pageAnimation.restart();
    }
    onPasswordNetworkChanged: {
        if (passwordNetwork === null && !pillHovered && !panelHovered)
            closeDelay.restart();

    }
    implicitWidth: panelWidth + pill.right
    implicitHeight: panelMaxHeight + pill.top
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
                    controlCenter.page = controlCenter.parentPage(controlCenter.page);
                else
                    controlCenter.close();
            }

            // Same card as the pill it grows from: base at 0.9 (blurred by a layer rule) with
            // the glass rim, so the pill itself seems to grow.
            GlassSurface {
                radius: panel.radius
                tinted: false
                backgroundColor: Qt.rgba(30 / 255, 30 / 255, 46 / 255, 0.9)
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

                implicitHeight: controlCenter.page === "wifi" ? wifiPage.implicitHeight : controlCenter.page === "enterprise" ? enterprisePage.implicitHeight : controlCenter.page === "wifiDetail" ? wifiDetailPage.implicitHeight : controlCenter.page === "bluetoothDetail" ? bluetoothDetailPage.implicitHeight : controlCenter.page === "bluetooth" ? bluetoothPage.implicitHeight : controlCenter.page === "locale" ? localePage.implicitHeight : controlCenter.page === "sound" ? soundPage.implicitHeight : controlCenter.page === "caffeine" ? caffeinePage.implicitHeight : controlCenter.page === "chargeLimit" ? chargeLimitPage.implicitHeight : mainPage.implicitHeight
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 14
                anchors.topMargin: 14
                width: controlCenter.panelWidth - 28

                ColumnLayout {
                    id: mainPage

                    width: parent.width
                    x: controlCenter.pageX("main")
                    visible: controlCenter.pageVisible("main")
                    enabled: controlCenter.page === "main"
                    opacity: controlCenter.pageOpacity("main")
                    spacing: 12

                    // Two columns of tiles, of the same width.
                    RowLayout {
                        id: tileColumns

                        readonly property real columnWidth: (width - spacing) / 2

                        Layout.fillWidth: true
                        spacing: 12

                        ColumnLayout {
                            Layout.preferredWidth: tileColumns.columnWidth
                            Layout.alignment: Qt.AlignTop
                            spacing: 12

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

                        ColumnLayout {
                            Layout.preferredWidth: tileColumns.columnWidth
                            Layout.fillHeight: true
                            spacing: 12

                            ControlTile {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                icon: "󰂛"
                                title: "Focus"
                                subtitle: controlCenter.shellState.doNotDisturb ? "On" : "Off"
                                active: controlCenter.shellState.doNotDisturb
                                onToggled: controlCenter.shellState.doNotDisturb = !controlCenter.shellState.doNotDisturb
                            }

                            ControlTile {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                visible: controlCenter.powerProfilesAvailable
                                icon: controlCenter.powerProfileIcon()
                                title: "Power"
                                subtitle: controlCenter.powerProfile === "power-saver" ? "Saver" : controlCenter.powerProfile === "performance" ? "Performance" : "Balanced"
                                active: controlCenter.powerProfile !== "balanced"
                                onToggled: controlCenter.cyclePowerProfile()
                            }

                            // A click switches between the AZERTY and QWERTY profiles.
                            ControlTile {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                icon: "󰌌"
                                title: "Keyboard"
                                subtitle: controlCenter.keyboardLayout === "fr" ? "FR AZERTY" : "US QWERTY"
                                onToggled: Quickshell.execDetached([Quickshell.env("HOME") + "/Scripts/keyboard-layoutctl.sh", "set", controlCenter.keyboardLayout === "fr" ? "us" : "fr"])
                            }

                        }

                    }

                    // Under the columns, as wide as them; caffeine across both without a
                    // battery's charge limit, for the grid to stay even.
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: tileColumns.spacing

                        ControlTile {
                            Layout.fillWidth: true
                            Layout.preferredWidth: tileColumns.columnWidth
                            icon: controlCenter.shellState.caffeine ? "󰅶" : "󰾪"
                            title: "Caffeine"
                            subtitle: controlCenter.caffeineSubtitle()
                            active: controlCenter.shellState.caffeine
                            expandable: true
                            onToggled: controlCenter.toggleCaffeine()
                            onExpandRequested: controlCenter.page = "caffeine"
                        }

                        ControlTile {
                            Layout.fillWidth: true
                            Layout.preferredWidth: tileColumns.columnWidth
                            visible: controlCenter.chargeLimit > 0
                            icon: controlCenter.chargeLimitIcon(controlCenter.chargeLimit)
                            title: "Charge limit"
                            subtitle: controlCenter.chargeLimit < 100 ? controlCenter.chargeLimit + " %" : "Off"
                            active: controlCenter.chargeLimit < 100
                            expandable: true
                            onToggled: {
                                if (controlCenter.chargeLimitWritable)
                                    controlCenter.toggleChargeLimit();
                                else
                                    controlCenter.page = "chargeLimit";
                            }
                            onExpandRequested: controlCenter.page = "chargeLimit"
                        }

                    }

                    ControlBlock {
                        Layout.fillWidth: true
                        implicitHeight: brightnessColumn.implicitHeight + 24

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

                    ControlBlock {
                        id: soundBlock

                        Layout.fillWidth: true
                        implicitHeight: soundColumn.implicitHeight + 24

                        // Under the content: the slider keeps its own clicks.
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                soundBlock.bounce();
                                controlCenter.page = "sound";
                            }
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
                                    color: "#b4befe"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                }

                                Text {
                                    text: "󰅂"
                                    color: soundBlock.hovered ? "#cba6f7" : "#b4befe"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 160
                                        }

                                    }

                                }

                            }

                            HorizontalSlider {
                                Layout.fillWidth: true
                                // Muting keeps the volume: the fill stays at its level, in lavender.
                                value: controlCenter.volume / 100
                                accent: controlCenter.muted ? "#b4befe" : "#cba6f7"
                                iconButton: true
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
                    x: controlCenter.pageX("wifi")
                    visible: controlCenter.pageVisible("wifi")
                    enabled: controlCenter.page === "wifi"
                    opacity: controlCenter.pageOpacity("wifi")
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

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: wifiList.height
                        visible: controlCenter.wifiNetworks.length > 0

                        ListView {
                            id: wifiList

                            // Wider than the page by a few pixels, so the hovered row's zoom and
                            // bounce (up to 4.5px a side) aren't cut; the rows stay aligned.
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: -6
                            anchors.rightMargin: -6
                            height: Math.min(contentHeight, 340)
                            clip: true
                            spacing: 4
                            model: controlCenter.wifiNetworks

                            // The row inside: the list sets its delegates' x.
                            delegate: Item {
                                required property var modelData

                                width: ListView.view.width
                                height: row.height

                                ListRow {
                                    id: row

                                    x: 6
                                    width: parent.width - 12
                                    icon: controlCenter.wifiIcon(modelData.signalStrength)
                                    title: modelData.name
                                    subtitle: modelData.stateChanging ? (modelData.connected ? "Disconnecting…" : "Connecting…") : modelData.connected ? "Connected" : modelData.known ? "Saved" : ""
                                    trailing: modelData.security === WifiSecurityType.Open ? "" : "󰌾"
                                    highlighted: modelData.connected
                                    detailsAvailable: modelData.known
                                    onClicked: controlCenter.selectWifi(modelData)
                                    onDetailsRequested: controlCenter.showWifiDetails(modelData)

                                    Connections {
                                        function onConnectionFailed(reason) {
                                            if (reason === ConnectionFailReason.NoSecrets && controlCenter.opened && controlCenter.requestedWifi === modelData)
                                                controlCenter.askWifiSecrets(modelData);

                                        }

                                        target: modelData
                                    }

                                }

                            }

                        }

                    }

                    ControlBlock {
                        Layout.fillWidth: true
                        implicitHeight: passwordColumn.implicitHeight + 24
                        visible: controlCenter.passwordNetwork !== null

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
                                    // The sudo field's hidden letters and cursor (SddmPicker).
                                    echoMode: TextInput.Password
                                    passwordCharacter: "■"
                                    color: "#cba6f7"
                                    selectionColor: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.35)
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    font.letterSpacing: 3
                                    clip: true
                                    cursorDelegate: Item {
                                    }
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
                                        font.family: parent.font.family
                                        font.pixelSize: parent.font.pixelSize
                                    }

                                    BlockCursor {
                                        input: passwordInput
                                    }

                                }

                            }

                        }

                    }

                }

                ColumnLayout {
                    id: bluetoothPage

                    width: parent.width
                    x: controlCenter.pageX("bluetooth")
                    visible: controlCenter.pageVisible("bluetooth")
                    enabled: controlCenter.page === "bluetooth"
                    opacity: controlCenter.pageOpacity("bluetooth")
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

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: bluetoothList.height
                        visible: controlCenter.bluetoothDevices.length > 0

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
                            model: controlCenter.bluetoothDevices

                            // The row inside: the list sets its delegates' x.
                            delegate: Item {
                                required property var modelData

                                width: ListView.view.width
                                height: row.height

                                ListRow {
                                    id: row

                                    x: 6
                                    width: parent.width - 12
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
                                    detailsAvailable: modelData.paired
                                    onClicked: controlCenter.selectBluetooth(modelData)
                                    onDetailsRequested: controlCenter.showBluetoothDetails(modelData)
                                }

                            }

                        }

                    }

                }


                EnterpriseWifiPage {
                    id: enterprisePage

                    width: parent.width
                    x: controlCenter.pageX("enterprise")
                    visible: controlCenter.pageVisible("enterprise")
                    enabled: controlCenter.page === "enterprise"
                    opacity: controlCenter.pageOpacity("enterprise")
                    network: controlCenter.enterpriseNetwork
                    onBackRequested: controlCenter.page = controlCenter.enterpriseReturnPage
                    onFinished: controlCenter.page = controlCenter.enterpriseReturnPage
                }

                WifiDetailPage {
                    id: wifiDetailPage

                    width: parent.width
                    x: controlCenter.pageX("wifiDetail")
                    visible: controlCenter.pageVisible("wifiDetail")
                    enabled: controlCenter.page === "wifiDetail"
                    opacity: controlCenter.pageOpacity("wifiDetail")
                    network: controlCenter.detailNetwork
                    enterprise: controlCenter.detailNetwork !== null && controlCenter.isEnterprise(controlCenter.detailNetwork)
                    onBackRequested: controlCenter.page = "wifi"
                    onConnectRequested: controlCenter.selectWifi(controlCenter.detailNetwork)
                    onModifyRequested: {
                        controlCenter.enterpriseNetwork = controlCenter.detailNetwork;
                        controlCenter.enterpriseReturnPage = "wifiDetail";
                        enterprisePage.edit();
                        controlCenter.page = "enterprise";
                    }
                    onForgotten: controlCenter.page = "wifi"
                }

                BluetoothDetailPage {
                    id: bluetoothDetailPage

                    width: parent.width
                    x: controlCenter.pageX("bluetoothDetail")
                    visible: controlCenter.pageVisible("bluetoothDetail")
                    enabled: controlCenter.page === "bluetoothDetail"
                    opacity: controlCenter.pageOpacity("bluetoothDetail")
                    device: controlCenter.detailDevice
                    onBackRequested: controlCenter.page = controlCenter.bluetoothDetailReturnPage
                    onForgotten: controlCenter.page = controlCenter.bluetoothDetailReturnPage
                }

                SoundPage {
                    id: soundPage

                    width: parent.width
                    x: controlCenter.pageX("sound")
                    visible: controlCenter.pageVisible("sound")
                    enabled: controlCenter.page === "sound"
                    opacity: controlCenter.pageOpacity("sound")
                    active: controlCenter.opened && controlCenter.page === "sound"
                    maxHeight: controlCenter.panelMaxHeight - 28
                    airPods: controlCenter.airPods
                    onBackRequested: controlCenter.page = "main"
                    onBluetoothDetailsRequested: (device) => {
                        return controlCenter.showBluetoothDetails(device);
                    }
                }

                ColumnLayout {
                    id: caffeinePage

                    width: parent.width
                    x: controlCenter.pageX("caffeine")
                    visible: controlCenter.pageVisible("caffeine")
                    enabled: controlCenter.page === "caffeine"
                    opacity: controlCenter.pageOpacity("caffeine")
                    spacing: 6

                    PageHeader {
                        Layout.fillWidth: true
                        title: "Caffeine"
                        checked: controlCenter.shellState.caffeine
                        onToggled: controlCenter.toggleCaffeine()
                        onBackRequested: controlCenter.page = "main"
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 6
                        text: "Keeps the screen on: no dimming, locking or sleep."
                        color: "#7f849c"
                        wrapMode: Text.Wrap
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }

                    Repeater {
                        model: controlCenter.caffeineDurations

                        ListRow {
                            required property var modelData
                            readonly property bool chosen: controlCenter.shellState.caffeine && controlCenter.shellState.caffeineMinutes === modelData.minutes

                            Layout.fillWidth: true
                            icon: modelData.minutes === 0 ? "󰅶" : "󰔛"
                            title: modelData.label
                            // The chosen duration ends at: "Until 22:10".
                            subtitle: chosen && controlCenter.shellState.caffeineUntil > 0 ? "Until " + Qt.formatTime(new Date(controlCenter.shellState.caffeineUntil), "HH:mm") : ""
                            trailing: chosen ? "\uf00c" : ""
                            highlighted: chosen
                            onClicked: controlCenter.chooseCaffeine(modelData.minutes)
                        }

                    }

                }

                ColumnLayout {
                    id: chargeLimitPage

                    width: parent.width
                    x: controlCenter.pageX("chargeLimit")
                    visible: controlCenter.pageVisible("chargeLimit")
                    enabled: controlCenter.page === "chargeLimit"
                    opacity: controlCenter.pageOpacity("chargeLimit")
                    spacing: 6

                    PageHeader {
                        Layout.fillWidth: true
                        title: "Charge limit"
                        checked: controlCenter.chargeLimit < 100
                        toggleVisible: controlCenter.chargeLimitWritable
                        onToggled: controlCenter.toggleChargeLimit()
                        onBackRequested: controlCenter.page = "main"
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 6
                        text: !controlCenter.chargeLimitWritable ? "Read only: install battery-limit (battery/ in the dotfiles) to change it." : controlCenter.chargeLimitError !== "" ? controlCenter.chargeLimitError : "Stops charging at the limit, easier on the battery over the years. Kept after a restart."
                        color: !controlCenter.chargeLimitWritable || controlCenter.chargeLimitError !== "" ? "#fab387" : "#7f849c"
                        wrapMode: Text.Wrap
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }

                    Repeater {
                        model: controlCenter.chargeLimits

                        ListRow {
                            required property int modelData
                            readonly property bool chosen: controlCenter.chargeLimit === modelData

                            Layout.fillWidth: true
                            icon: controlCenter.chargeLimitIcon(modelData)
                            title: modelData + " %"
                            subtitle: modelData === 80 ? "Recommended" : ""
                            trailing: chosen ? "\uf00c" : ""
                            highlighted: chosen
                            enabled: controlCenter.chargeLimitWritable
                            onClicked: controlCenter.setChargeLimit(modelData)
                        }

                    }

                }

                ColumnLayout {
                    id: localePage

                    width: parent.width
                    x: controlCenter.pageX("locale")
                    visible: controlCenter.pageVisible("locale")
                    enabled: controlCenter.page === "locale"
                    opacity: controlCenter.pageOpacity("locale")
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
                        text: "New apps use it right away. Log out and back in to apply it to the apps already open."
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

        // The bar's pills' delay (Bar.hoverOpenDelay).
        interval: 350
        onTriggered: controlCenter.opened = true
    }

    Timer {
        id: closeDelay

        interval: 380
        onTriggered: {
            // Keep the panel open while a Wi-Fi password or enterprise credentials are typed
            // (a certificate may be picked in a file chooser outside it).
            if (!controlCenter.pillHovered && !controlCenter.panelHovered && controlCenter.passwordNetwork === null && controlCenter.page !== "enterprise" && !(controlCenter.page === "wifiDetail" && wifiDetailPage.editing))
                controlCenter.opened = false;

        }
    }

    Behavior on progress {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }

    }

    NumberAnimation {
        id: pageAnimation

        target: controlCenter
        property: "pageProgress"
        from: 0
        to: 1
        duration: 320
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

    Timer {
        running: controlCenter.opened && controlCenter.shellState.caffeine && controlCenter.shellState.caffeineUntil > 0
        interval: 15000
        repeat: true
        triggeredOnStart: true
        onTriggered: controlCenter.now = Date.now()
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

    // "<limit> <writable 1|0> <kept limit>", nothing without a battery's limit; read
    // only without battery-limit.
    Process {
        id: chargeLimitProcess

        command: ["sh", "-c", "command -v battery-limit >/dev/null && exec battery-limit get; for file in /sys/class/power_supply/*/charge_control_end_threshold; do [ -e \"$file\" ] && echo \"$(cat \"$file\") 0\"; break; done"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split(/\s+/);
                const limit = parseInt(fields[0]);
                controlCenter.chargeLimit = isNaN(limit) ? 0 : limit;
                controlCenter.chargeLimitWritable = fields[1] === "1";
                const kept = parseInt(fields[2]);
                if (limit > 0 && limit < 100)
                    controlCenter.chargeLimitOn = limit;
                else if (kept > 0 && kept < 100)
                    controlCenter.chargeLimitOn = kept;
            }
        }

    }

    Process {
        id: chargeLimitSetProcess

        stderr: StdioCollector {
            id: chargeLimitSetErrors
        }

        // Re-read the real state, the firmware may round or refuse it.
        onExited: (code) => {
            if (code !== 0)
                controlCenter.chargeLimitError = chargeLimitSetErrors.text.trim().split("\n").pop() || "The charge limit could not be set.";

            chargeLimitProcess.running = true;
        }
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
