import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: bar

    required property var shellState
    property color base: "#1e1e2e"
    property color surface0: "#313244"
    property color surface1: "#45475a"
    property color lavender: "#b4befe"
    property color overlay2: "#9399b2"
    property color mauve: "#cba6f7"
    property color red: "#f38ba8"
    readonly property var workspaceIcons: ["", "", "", "", "", "", "", "", "", "", ""]
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery.ready && battery.isLaptopBattery && battery.isPresent
    property string cpuTemperature: "--°C"
    property string cpuFrequency: ""
    property string cpuModel: ""
    property string memoryText: "--"
    property int cpuUsage: 0
    // [idle, total] jiffies of the last /proc/stat sample.
    property var cpuStat: [0, 0]
    property string updatesText: ""
    property bool calendarVisible: false
    property bool calendarPopupVisible: false
    property bool musicVisible: false
    property bool musicPopupVisible: false
    // Set while a popup is mapping: it only starts growing once its first frame is on screen.
    property bool calendarOpenPending: false
    property bool musicOpenPending: false
    property bool monitorOpenPending: false
    property bool monitorVisible: false
    property bool monitorPopupVisible: false
    // 0 = card folded on the resources pill, 1 = system monitor fully open.
    property real monitorProgress: monitorVisible ? 1 : 0
    // 0 = popup folded on the cover pill, 1 = player fully open.
    property real musicProgress: musicVisible ? 1 : 0
    // Only Spotify, browsers and other MPRIS players are ignored.
    readonly property var spotifyPlayer: {
        for (const player of Mpris.players.values) {
            if (player.dbusName === "org.mpris.MediaPlayer2.spotify")
                return player;

        }
        return null;
    }
    property bool statusOsdVisible: false
    property string statusOsdIcon: ""
    property string statusOsdLabel: ""
    property bool statusOsdEnabled: false
    // Level gauge shown instead of the On/Off badge when statusOsdMaxLevel > 0.
    property int statusOsdLevel: 0
    property int statusOsdMaxLevel: 0
    property bool lockStateInitialized: false
    property bool capsLockEnabled: false
    property bool numLockEnabled: false
    property bool touchpadStateInitialized: false
    property bool touchpadEnabled: true
    readonly property var micSource: Pipewire.defaultAudioSource
    readonly property bool micMuted: micSource !== null && micSource.audio !== null && micSource.audio.muted
    property bool micStateInitialized: false
    property int keyboardBacklight: -1
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property int audioVolume: audioSink !== null && audioSink.audio !== null ? Math.round(audioSink.audio.volume * 100) : 0
    readonly property bool audioMuted: audioSink !== null && audioSink.audio !== null && audioSink.audio.muted
    property bool volumeInitialized: false
    property int screenBrightness: 0
    property bool brightnessInitialized: false
    property string keyboardBacklightPath: ""
    property bool keyboardHwInitialized: false
    property real clockCenterOffset: bar.statusOsdVisible ? 3 : -3
    readonly property string stateHome: {
        const configuredStateHome = Quickshell.env("XDG_STATE_HOME");
        return configuredStateHome && configuredStateHome !== "" ? configuredStateHome : Quickshell.env("HOME") + "/.local/state";
    }

    // The connected device first, else one NetworkManager is bringing up.
    readonly property var networkDevice: {
        let connecting = null;
        for (const device of Networking.devices.values) {
            if (device.connected)
                return device;

            if (connecting === null && device.state === ConnectionState.Connecting)
                connecting = device;

        }
        return connecting;
    }
    // Active VPN connections ({name, state}), Quickshell.Networking does not expose them.
    property var vpnConnections: []
    readonly property var vpnConnection: vpnConnections.find((connection) => {
        return connection.state === "activated";
    }) || vpnConnections.find((connection) => {
        return connection.state === "activating";
    }) || null
    readonly property bool vpnActive: vpnConnection !== null && vpnConnection.state === "activated"
    readonly property bool vpnConnecting: vpnConnection !== null && !vpnActive
    readonly property bool networkConnecting: (networkDevice !== null && !networkDevice.connected) || vpnConnecting
    readonly property bool wiredLocked: networkDevice !== null && networkDevice.connected && networkDevice.type === DeviceType.Wired && vpnConnection !== null

    function activeWifiNetwork(device) {
        for (const network of device.networks.values) {
            if (network.connected)
                return network;

        }
        return null;
    }

    function networkIcon() {
        const device = bar.networkDevice;
        if (device === null)
            return "󰤮";

        if (device.type === DeviceType.Wired)
            return device.connected ? "󰈀" : "󰌚";

        // Locked while a VPN is up (or coming up) over the Wi-Fi.
        const locked = device.connected && bar.vpnConnection !== null;
        const icons = locked ? ["󰤬", "󰤡", "󰤤", "󰤧", "󰤪"] : ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"];
        const network = bar.activeWifiNetwork(device);
        const strength = network !== null ? network.signalStrength : 0;
        return icons[Math.max(0, Math.min(icons.length - 1, Math.floor(strength * icons.length)))];
    }

    function networkTooltip() {
        const device = bar.networkDevice;
        if (device === null)
            return "Disconnected";

        let text;
        if (device.type === DeviceType.Wired) {
            text = "Ethernet · " + device.name;
        } else {
            const network = bar.activeWifiNetwork(device);
            text = network !== null ? network.name + " · " + Math.round(network.signalStrength * 100) + "%" : device.name;
        }
        if (!device.connected)
            return "Connecting · " + text;

        if (bar.vpnConnection !== null)
            text += "\n" + (bar.vpnConnecting ? "Connecting VPN · " : "VPN · ") + bar.vpnConnection.name;

        return text;
    }

    function batteryIcon() {
        // Plugged in: the same gauge with the charging bolt.
        const icons = UPower.onBattery ? ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"] : ["󰢟", "󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"];
        const percentage = Math.max(0, Math.min(1, bar.battery.percentage));
        return icons[Math.min(icons.length - 1, Math.floor(percentage * icons.length))];
    }

    function formatDuration(seconds) {
        if (!seconds || seconds <= 0)
            return "Unknown";

        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        return hours + "h " + minutes + "m";
    }

    function batteryTooltip() {
        if (!bar.hasBattery)
            return "";

        const charging = !UPower.onBattery;
        let value = charging ? "Charging" : "Discharging";
        const remaining = charging ? bar.battery.timeToFull : bar.battery.timeToEmpty;
        value += "\nTime remaining: " + bar.formatDuration(remaining);
        value += "\nPower: " + bar.battery.changeRate.toFixed(1) + "W";
        if (bar.battery.healthSupported)
            value += "\nHealth: " + Math.round(bar.battery.healthPercentage * 100) + "%";

        return value;
    }

    // With maxLevel > 0, a gauge of level / maxLevel replaces the On/Off badge.
    function showStatusOsd(icon, label, enabled, level, maxLevel) {
        calendarCloseDelay.stop();
        calendarHideDelay.stop();
        calendarVisible = false;
        calendarPopupVisible = false;
        statusOsdIcon = icon;
        statusOsdLabel = label;
        statusOsdEnabled = enabled;
        statusOsdLevel = level !== undefined ? level : 0;
        statusOsdMaxLevel = maxLevel !== undefined ? maxLevel : 0;
        statusOsdVisible = true;
        statusOsdHideDelay.restart();
    }

    function volumeIcon() {
        if (audioMuted)
            return "";

        if (audioVolume === 0)
            return "";

        if (audioVolume < 34)
            return "";

        if (audioVolume < 67)
            return "";

        return "";
    }

    function brightnessIcon() {
        const icons = ["", "", "", "", "", "", "", "", ""];
        return icons[Math.min(icons.length - 1, Math.floor(screenBrightness * icons.length / 101))];
    }

    function showVolumeOsd() {
        if (volumeInitialized)
            showStatusOsd(volumeIcon(), audioMuted ? "Muted" : "Volume", !audioMuted, audioMuted ? 0 : audioVolume, 100);

    }

    // The island's new content fades in while the pill resizes around it.
    onStatusOsdVisibleChanged: islandContentFade.restart()
    onStatusOsdLabelChanged: islandContentFade.restart()
    onAudioVolumeChanged: showVolumeOsd()
    onAudioMutedChanged: showVolumeOsd()
    // Deferred: during the bar's creation the pill's animations do not exist yet.
    onSpotifyPlayerChanged: Qt.callLater(musicPill.resetDiscs)
    onMicSourceChanged: {
        // Wait for the new source's state before reacting to mute changes.
        micStateInitialized = false;
        micInitDelay.restart();
    }
    onMicMutedChanged: {
        if (micStateInitialized)
            showStatusOsd(micMuted ? "󰍭" : "󰍬", "Microphone", !micMuted);

    }
    implicitHeight: 56
    color: "transparent"
    exclusiveZone: 50
    // Named so the player popup can be blurred by a blur_popups layer rule.
    WlrLayershell.namespace: "hyprpunk-bar"

    anchors {
        top: true
        left: true
        right: true
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24

        RowLayout {
            id: leftGroup

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -(bar.implicitHeight - 50) / 2
            spacing: 9

            Pill {
                Item {
                    id: workspaceSwitcher

                    readonly property var hyprlandMonitor: Hyprland.monitorFor(bar.screen)
                    readonly property var workspaces: Hyprland.workspaces.values.filter((workspace) => {
                        return workspace.id > 0 && workspace.id <= 10 && workspace.monitor === workspaceSwitcher.hyprlandMonitor && (workspace.active || workspace.toplevels.values.length > 0);
                    })
                    property int activeButtonIndex: -1
                    property int activeWorkspaceId: -1
                    property bool activeWorkspaceOccupied: false
                    property real fallbackSlideX: 0
                    property real fallbackOpacity: 1

                    function selectWorkspace(workspaceId, visualIndex, occupied) {
                        const previousWorkspaceId = activeWorkspaceId;
                        const previousIndex = activeButtonIndex;
                        const previousWorkspaceOccupied = activeWorkspaceOccupied;
                        activeWorkspaceId = workspaceId;
                        activeButtonIndex = visualIndex;
                        activeWorkspaceOccupied = occupied;
                        const sameVisualPosition = previousIndex === visualIndex;
                        const emptyToOccupiedAfter = !previousWorkspaceOccupied && occupied && workspaceId > previousWorkspaceId;
                        if (previousWorkspaceId >= 0 && previousWorkspaceId !== workspaceId && (sameVisualPosition || emptyToOccupiedAfter)) {
                            fallbackTransition.stop();
                            fallbackSlideX = workspaceId > previousWorkspaceId ? 22 : -22;
                            fallbackOpacity = 0.25;
                            fallbackTransition.start();
                        }
                    }

                    function clearSelectionIfUnfocused() {
                        for (const workspace of workspaces) {
                            if (workspace.focused)
                                return ;

                        }
                        activeButtonIndex = -1;
                        activeWorkspaceId = -1;
                        activeWorkspaceOccupied = false;
                    }

                    implicitWidth: workspaceRow.implicitWidth
                    implicitHeight: workspaceRow.implicitHeight
                    opacity: fallbackOpacity

                    ParallelAnimation {
                        id: fallbackTransition

                        NumberAnimation {
                            target: workspaceSwitcher
                            property: "fallbackSlideX"
                            to: 0
                            duration: 220
                            easing.type: Easing.OutCubic
                        }

                        NumberAnimation {
                            target: workspaceSwitcher
                            property: "fallbackOpacity"
                            to: 1
                            duration: 160
                            easing.type: Easing.OutCubic
                        }

                    }

                    Rectangle {
                        z: 0
                        x: workspaceSwitcher.activeButtonIndex >= 0 ? workspaceSwitcher.activeButtonIndex * (31 + workspaceRow.spacing) : 0
                        y: 0
                        width: 44
                        height: 31
                        radius: height / 2
                        color: bar.mauve
                        visible: workspaceSwitcher.activeButtonIndex >= 0

                        Behavior on x {
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    Row {
                        id: workspaceRow

                        z: 1
                        spacing: 2

                        Repeater {
                            id: workspaceRepeater

                            model: workspaceSwitcher.workspaces

                            WorkspaceButton {
                                id: workspaceButton

                                required property var modelData
                                required property int index

                                workspaceId: modelData.id
                                icon: bar.workspaceIcons[modelData.id]
                                active: modelData.focused
                                occupied: modelData.toplevels.values.length > 0
                                drawActiveBackground: false
                                onActivated: modelData.activate()
                                onActiveChanged: {
                                    if (active)
                                        workspaceSwitcher.selectWorkspace(workspaceId, index, occupied);
                                    else
                                        Qt.callLater(workspaceSwitcher.clearSelectionIfUnfocused);
                                }
                                onOccupiedChanged: {
                                    if (active)
                                        workspaceSwitcher.activeWorkspaceOccupied = occupied;

                                }
                                Component.onCompleted: {
                                    if (active)
                                        workspaceSwitcher.selectWorkspace(workspaceId, index, occupied);

                                }
                            }

                        }

                    }

                    transform: Translate {
                        x: workspaceSwitcher.fallbackSlideX
                    }

                }

            }

            // Opens the system monitor on hover, which grows out of it like the player.
            Pill {
                id: monitorPill

                visible: bar.width >= 1200
                onHoveredChanged: {
                    if (hovered) {
                        monitorCloseDelay.stop();
                        monitorHideDelay.stop();
                        if (!bar.monitorPopupVisible) {
                            bar.monitorOpenPending = true;
                            bar.monitorPopupVisible = true;
                        } else {
                            bar.monitorVisible = true;
                        }
                    } else {
                        monitorCloseDelay.restart();
                    }
                }

                IconText {
                    icon: ""
                    text: bar.memoryText
                }

                IconText {
                    icon: ""
                    text: bar.cpuUsage + "%"
                }

                Timer {
                    id: monitorCloseDelay

                    interval: 220
                    onTriggered: {
                        bar.monitorOpenPending = false;
                        bar.monitorVisible = false;
                        monitorHideDelay.restart();
                    }
                }

                Timer {
                    id: monitorHideDelay

                    // Lets the card fold back onto the pill first.
                    interval: 320
                    onTriggered: bar.monitorPopupVisible = false
                }

                PopupWindow {
                    id: monitorPopup

                    readonly property real progress: bar.monitorProgress

                    function lerp(from, to) {
                        return from + (to - from) * progress;
                    }

                    visible: bar.monitorPopupVisible

                    Connections {
                        function onFrameSwapped() {
                            if (bar.monitorOpenPending) {
                                bar.monitorOpenPending = false;
                                bar.monitorVisible = true;
                            }
                        }

                        target: monitorCard.Window.window
                    }

                    implicitWidth: monitorContent.implicitWidth
                    implicitHeight: monitorContent.implicitHeight
                    color: "transparent"
                    grabFocus: false

                    anchor {
                        item: monitorPill
                        edges: Edges.Top | Edges.Left
                        gravity: Edges.Bottom | Edges.Right
                        adjustment: PopupAdjustment.SlideX
                    }

                    // The anchor is only computed on opening: follow the pill when the
                    // workspaces before it change width.
                    Connections {
                        function onXChanged() {
                            monitorPopup.anchor.updateAnchor();
                        }

                        function onYChanged() {
                            monitorPopup.anchor.updateAnchor();
                        }

                        target: monitorPill
                    }

                    Connections {
                        function onXChanged() {
                            monitorPopup.anchor.updateAnchor();
                        }

                        function onYChanged() {
                            monitorPopup.anchor.updateAnchor();
                        }

                        target: monitorPill.parent
                    }

                    ClippingRectangle {
                        id: monitorCard

                        anchors.top: parent.top
                        anchors.left: parent.left
                        width: monitorPopup.lerp(monitorPill.width, monitorPopup.width)
                        height: monitorPopup.lerp(monitorPill.height, monitorPopup.height)
                        radius: monitorPopup.lerp(monitorPill.radius, 24)
                        color: "transparent"

                        // Same card as the player, faded in over the pill like the control
                        // center so the pill's own content disappears under it.
                        GlassSurface {
                            radius: monitorCard.radius
                            tinted: false
                            opacity: Math.min(1, monitorPopup.progress / 0.35)
                            backgroundColor: Qt.rgba(monitorPopup.lerp(49, 30) / 255, monitorPopup.lerp(50, 30) / 255, monitorPopup.lerp(68, 46) / 255, 0.9)
                        }

                        SystemMonitorCard {
                            id: monitorContent

                            anchors.top: parent.top
                            anchors.left: parent.left
                            width: monitorPopup.width
                            opacity: Math.max(0, (monitorPopup.progress - 0.7) / 0.3)
                            active: bar.monitorPopupVisible
                            temperature: bar.cpuTemperature
                            frequency: bar.cpuFrequency
                            model: bar.cpuModel
                        }

                        HoverHandler {
                            onHoveredChanged: {
                                if (hovered) {
                                    monitorCloseDelay.stop();
                                    monitorHideDelay.stop();
                                    bar.monitorVisible = true;
                                } else {
                                    monitorCloseDelay.restart();
                                }
                            }
                        }

                    }

                    mask: Region {
                        item: monitorCard
                    }

                }

            }

        }

        RowLayout {
            id: centerGroup

            anchors.centerIn: parent
            anchors.verticalCenterOffset: bar.clockCenterOffset
            spacing: 9
            // The island moves with the group (centring and the OSD offset), not inside it.
            onXChanged: clockPill.publishGeometry()
            onYChanged: clockPill.publishGeometry()

            Pill {
                id: clockPill

                function publishGeometry() {
                    const origin = mapToItem(null, 0, 0);
                    bar.shellState.islandPill = {
                        "centerOffset": origin.x + width / 2 - bar.width / 2,
                        "top": origin.y,
                        "width": width,
                        "height": height
                    };
                }

                onWidthChanged: publishGeometry()
                onHeightChanged: publishGeometry()
                Component.onCompleted: publishGeometry()
                spacing: 8
                horizontalPadding: bar.statusOsdVisible ? 36 : 20
                implicitHeight: bar.statusOsdVisible ? 50 : 38
                contentOpacity: 1

                Label {
                    id: dateTimeLabel

                    visible: !bar.statusOsdVisible
                    text: Qt.formatDateTime(clock.date, "HH:mm")

                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered) {
                                calendarCloseDelay.stop();
                                calendarHideDelay.stop();
                                if (!bar.calendarPopupVisible) {
                                    calendarPopup.monthOffset = 0;
                                    bar.calendarOpenPending = true;
                                    bar.calendarPopupVisible = true;
                                } else {
                                    bar.calendarVisible = true;
                                }
                            } else {
                                calendarCloseDelay.restart();
                            }
                        }
                    }

                    SystemClock {
                        id: clock

                        precision: SystemClock.Minutes
                    }

                }

                Text {
                    visible: bar.statusOsdVisible
                    text: bar.statusOsdIcon
                    color: bar.mauve
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 20
                }

                // Volume and screen brightness only show their icon and bar.
                Text {
                    visible: bar.statusOsdVisible && bar.statusOsdMaxLevel <= 10
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    text: bar.statusOsdLabel
                    color: bar.mauve
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    font.weight: Font.Bold
                }

                Rectangle {
                    visible: bar.statusOsdVisible && bar.statusOsdMaxLevel <= 0
                    implicitWidth: statusOsdStateText.implicitWidth + 16
                    implicitHeight: 24
                    radius: 12
                    color: bar.statusOsdEnabled ? bar.mauve : bar.surface1

                    Text {
                        id: statusOsdStateText

                        anchors.centerIn: parent
                        text: bar.statusOsdEnabled ? "On" : "Off"
                        color: bar.statusOsdEnabled ? bar.base : bar.overlay2
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }

                }

                Row {
                    readonly property int segments: bar.statusOsdMaxLevel
                    readonly property int filled: bar.statusOsdLevel

                    visible: bar.statusOsdVisible && bar.statusOsdMaxLevel > 0 && bar.statusOsdMaxLevel <= 10
                    spacing: 4

                    Repeater {
                        model: parent.segments

                        Rectangle {
                            required property int index

                            width: 18
                            height: 8
                            radius: 4
                            color: index < parent.filled ? bar.mauve : bar.surface1

                            Behavior on color {
                                ColorAnimation {
                                    duration: 140
                                }

                            }

                        }

                    }

                }

                // Fine-grained levels (volume, screen brightness): continuous bar.
                Rectangle {
                    visible: bar.statusOsdVisible && bar.statusOsdMaxLevel > 10
                    implicitWidth: 160
                    implicitHeight: 8
                    radius: 4
                    color: bar.surface1

                    Rectangle {
                        width: parent.width * Math.min(1, bar.statusOsdLevel / Math.max(1, bar.statusOsdMaxLevel))
                        height: parent.height
                        radius: parent.radius
                        color: bar.mauve

                        Behavior on width {
                            NumberAnimation {
                                duration: 140
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                }

                Behavior on implicitWidth {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on implicitHeight {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }

                }

            }

            SequentialAnimation {
                id: islandContentFade

                PropertyAction {
                    target: clockPill
                    property: "contentOpacity"
                    value: 0
                }

                // The pill is ~90% open by then, so the content is not cut by its edges.
                PauseAnimation {
                    duration: 110
                }

                NumberAnimation {
                    target: clockPill
                    property: "contentOpacity"
                    to: 1
                    duration: 140
                    easing.type: Easing.OutCubic
                }

            }

            Timer {
                id: statusOsdHideDelay

                interval: 1500
                onTriggered: bar.statusOsdVisible = false
            }

            Timer {
                id: calendarCloseDelay

                interval: 180
                onTriggered: {
                    bar.calendarOpenPending = false;
                    bar.calendarVisible = false;
                    calendarHideDelay.restart();
                }
            }

            Timer {
                id: calendarHideDelay

                // Slightly longer than the 280 ms fold so the card is back on the pill first.
                interval: 320
                onTriggered: bar.calendarPopupVisible = false
            }

            PopupWindow {
                id: calendarPopup

                readonly property date currentDate: clock.date
                readonly property int currentYear: currentDate.getFullYear()
                readonly property int currentMonth: currentDate.getMonth()
                readonly property int currentDay: currentDate.getDate()
                property int monthOffset: 0
                readonly property date displayedMonth: new Date(currentYear, currentMonth + monthOffset, 1)
                readonly property int displayedYear: displayedMonth.getFullYear()
                readonly property int displayedMonthNumber: displayedMonth.getMonth()
                readonly property int firstWeekday: (displayedMonth.getDay() + 6) % 7
                readonly property int daysInMonth: new Date(displayedYear, displayedMonthNumber + 1, 0).getDate()
                readonly property int weekRows: Math.ceil((firstWeekday + daysInMonth) / 7)
                // Card height for the displayed month, measured from the real layout.
                readonly property real contentHeight: calendarBody.y + calendarBody.implicitHeight + 18
                property int pendingMonthDelta: 0

                function changeMonth(delta) {
                    if (monthTransition.running)
                        return ;

                    pendingMonthDelta = delta;
                    monthTransition.start();
                }

                visible: bar.calendarPopupVisible

                Connections {
                    function onFrameSwapped() {
                        if (bar.calendarOpenPending) {
                            bar.calendarOpenPending = false;
                            bar.calendarVisible = true;
                        }
                    }

                    target: calendarCard.Window.window
                }

                mask: Region {
                    item: calendarCard
                }
                implicitWidth: 322
                // Sized for a six-week month so the card can animate without being cut.
                // Not derived from weekRows: the layout updates a frame later, and the
                // popup would be resized twice (the whole content shakes).
                implicitHeight: calendarBody.y + calendarMonthLabel.implicitHeight + calendarBody.spacing + calendarGrid.sixWeekHeight + 18
                color: "transparent"
                grabFocus: false

                anchor {
                    item: clockPill
                    edges: Edges.Top
                    gravity: Edges.Bottom
                    adjustment: PopupAdjustment.SlideX
                }

                ClippingRectangle {
                    id: calendarCard

                    // 0 at the pill's size, 1 once fully open (follows the width animation).
                    readonly property real openness: Math.max(0, Math.min(1, (width - clockPill.width) / Math.max(1, calendarPopup.width - clockPill.width)))

                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: bar.calendarVisible ? calendarPopup.width : clockPill.width
                    height: bar.calendarVisible ? calendarPopup.contentHeight : clockPill.height
                    radius: bar.calendarVisible ? 24 : clockPill.radius
                    color: "transparent"

                    // Same card as the player: surface0 (the pill) to base at 0.9, blurred by
                    // the hyprpunk-bar blur_popups layer rule, with the glass rim.
                    GlassSurface {
                        radius: calendarCard.radius
                        tinted: false
                        backgroundColor: Qt.rgba((49 - 19 * calendarCard.openness) / 255, (50 - 20 * calendarCard.openness) / 255, (68 - 22 * calendarCard.openness) / 255, 1 - 0.1 * calendarCard.openness)
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: (wheel) => {
                            if (wheel.angleDelta.y > 0)
                                calendarPopup.changeMonth(-1);
                            else if (wheel.angleDelta.y < 0)
                                calendarPopup.changeMonth(1);
                            wheel.accepted = true;
                        }
                    }

                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered) {
                                calendarCloseDelay.stop();
                                calendarHideDelay.stop();
                                bar.calendarPopupVisible = true;
                                bar.calendarVisible = true;
                            } else {
                                calendarCloseDelay.restart();
                            }
                        }
                    }

                    Item {
                        id: expandedClockHeader

                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: clockPill.width
                        height: clockPill.height

                        Label {
                            anchors.centerIn: parent
                            text: Qt.formatDateTime(clock.date, "HH:mm")
                        }

                    }

                    Rectangle {
                        id: calendarSeparator

                        anchors.top: expandedClockHeader.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        height: 1
                        color: bar.surface1
                        opacity: bar.calendarVisible ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    IconText {
                        id: calendarDate

                        anchors.top: calendarSeparator.bottom
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        icon: "󰃭"
                        text: Qt.formatDate(clock.date, "dddd d MMMM yyyy")
                        color: bar.lavender
                        font.pixelSize: 15
                        opacity: bar.calendarVisible ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    Rectangle {
                        id: dateSeparator

                        anchors.top: calendarDate.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: 10
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        height: 1
                        color: bar.surface1
                        opacity: bar.calendarVisible ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    ColumnLayout {
                        id: calendarBody

                        property real monthSlideY: 0
                        property real monthTransitionOpacity: 1

                        anchors.top: dateSeparator.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        anchors.topMargin: 8
                        spacing: 10
                        opacity: (bar.calendarVisible ? 1 : 0) * monthTransitionOpacity

                        Label {
                            id: calendarMonthLabel

                            Layout.alignment: Qt.AlignHCenter
                            text: Qt.formatDate(calendarPopup.displayedMonth, "MMMM yyyy")
                            color: bar.mauve
                            font.pixelSize: 18
                            font.weight: Font.Bold
                        }

                        GridLayout {
                            id: calendarGrid

                            // Weekday row (25) and six weeks (29), with their spacing.
                            readonly property real sixWeekHeight: 25 + 6 * 29 + 6 * rowSpacing

                            Layout.fillWidth: true
                            columns: 7
                            columnSpacing: 4
                            rowSpacing: 4

                            Repeater {
                                model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

                                Label {
                                    required property string modelData

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 25
                                    text: modelData
                                    color: bar.mauve
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                            }

                            Repeater {
                                model: calendarPopup.weekRows * 7

                                Rectangle {
                                    required property int index
                                    readonly property int dayNumber: index - calendarPopup.firstWeekday + 1
                                    readonly property bool validDay: dayNumber >= 1 && dayNumber <= calendarPopup.daysInMonth
                                    readonly property bool isToday: validDay && dayNumber === calendarPopup.currentDay && calendarPopup.displayedMonthNumber === calendarPopup.currentMonth && calendarPopup.displayedYear === calendarPopup.currentYear

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 29
                                    radius: 9
                                    color: isToday ? bar.mauve : "transparent"

                                    Label {
                                        anchors.centerIn: parent
                                        text: parent.validDay ? parent.dayNumber : ""
                                        color: parent.isToday ? bar.base : bar.mauve
                                        font.pixelSize: 14
                                        font.weight: parent.isToday ? Font.Bold : Font.Medium
                                    }

                                }

                            }

                        }

                        transform: Translate {
                            y: calendarBody.monthSlideY
                        }

                    }

                    SequentialAnimation {
                        id: monthTransition

                        ParallelAnimation {
                            NumberAnimation {
                                target: calendarBody
                                property: "monthSlideY"
                                to: calendarPopup.pendingMonthDelta > 0 ? -28 : 28
                                duration: 120
                                easing.type: Easing.InCubic
                            }

                            NumberAnimation {
                                target: calendarBody
                                property: "monthTransitionOpacity"
                                to: 0
                                duration: 100
                                easing.type: Easing.InCubic
                            }

                        }

                        ScriptAction {
                            script: {
                                calendarPopup.monthOffset += calendarPopup.pendingMonthDelta;
                                calendarBody.monthSlideY = calendarPopup.pendingMonthDelta > 0 ? 28 : -28;
                            }
                        }

                        ParallelAnimation {
                            NumberAnimation {
                                target: calendarBody
                                property: "monthSlideY"
                                to: 0
                                duration: 160
                                easing.type: Easing.OutCubic
                            }

                            NumberAnimation {
                                target: calendarBody
                                property: "monthTransitionOpacity"
                                to: 1
                                duration: 140
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: 280
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: 280
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on radius {
                        NumberAnimation {
                            duration: 280
                            easing.type: Easing.OutCubic
                        }

                    }

                }

            }

        }

        RowLayout {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -(bar.implicitHeight - 50) / 2
            spacing: 9
            // When the control pill changes width, it publishes before the row has moved
            // back against the right edge: publish again once the row is in place.
            onXChanged: controlPill.publishGeometry()
            onYChanged: controlPill.publishGeometry()

            Pill {
                visible: bar.updatesText !== ""

                Label {
                    text: bar.updatesText

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: upgradeProcess.running = true
                    }

                }

            }

            // Round cover of the Spotify track, opens the player on hover.
            Rectangle {
                id: musicPill

                // Angle of the front disc: 0 = upright, where every track starts.
                property real spin: 0
                // 0 -> 1 after a new track or a restart: the disc only starts spinning
                // once it is upright in the hole.
                property real spinFactor: 1
                // While the player is open (from the hover until it is fully folded back),
                // the disc stops and goes on from the same angle afterwards: no jump.
                readonly property bool displayFrozen: bar.musicPopupVisible
                readonly property real frontAngle: spin + rewind
                // Degrees per second: speeds up and slows down like a turntable.
                property real spinSpeed: bar.spotifyPlayer !== null && bar.spotifyPlayer.isPlaying ? 45 : 0
                // Angle of the disc rolling out, frozen when the track changed.
                property real outgoingSpin: 0
                // 0 -> 1 while the discs swap, direction 1 = next track, -1 = previous.
                property real swipe: 1
                property int swipeDirection: 1
                property bool frontIsA: true
                property string currentTrackId: ""
                property var trackHistory: []
                // Set by the player buttons just before skipping.
                property int skipHint: 0
                // Extra angle of the front disc while it rewinds (track restarted).
                property real rewind: 0
                // Last position reported by the player (seconds), when and while playing or not.
                property real knownPosition: 0
                property real knownPositionTime: 0
                property bool knownPositionPlaying: false
                property real trackChangeTime: 0

                // Pops out then settles, on play, pause and track changes alike.
                function pulse() {
                    pulseAnimation.restart();
                }

                // Spotify's 64px variant of the 640px art: the pill shows it at 34px and it
                // loads much faster.
                function pillArt() {
                    return bar.spotifyPlayer.trackArtUrl.replace("/ab67616d0000b273", "/ab67616d00004851");
                }

                function frontDisc() {
                    return frontIsA ? discA : discB;
                }

                function trackId() {
                    const player = bar.spotifyPlayer;
                    return player.metadata["mpris:trackid"] ?? (player.trackTitle + player.trackArtist);
                }

                // The front disc comes in from one side, the other one leaves on the opposite side.
                function discX(front) {
                    const travel = discWindow.width + 8;
                    return front ? swipeDirection * travel * (1 - swipe) : -swipeDirection * travel * swipe;
                }

                // Rolls without slipping: one turn every 2πr travelled.
                function discRotation(front, x) {
                    return (front ? frontAngle : outgoingSpin) + x * 180 / (Math.PI * discWindow.width / 2);
                }

                function rememberPosition(position) {
                    knownPosition = position ?? bar.spotifyPlayer.position;
                    knownPositionTime = Date.now();
                    knownPositionPlaying = bar.spotifyPlayer.isPlaying;
                }

                // "Previous" past the first seconds restarts the track instead of changing it:
                // the position jumps back to 0 on the same track.
                function checkRestart(position) {
                    const current = position ?? bar.spotifyPlayer.position;
                    const expected = knownPosition + (knownPositionPlaying ? (Date.now() - knownPositionTime) / 1000 : 0);
                    // Position updates right after a track change are not restarts (they gave
                    // the new disc an extra turn); "previous" that early changes track anyway.
                    const settled = Date.now() - trackChangeTime > 2000;
                    const restarted = settled && trackId() === currentTrackId && current < 1.5 && expected > 2;
                    rememberPosition(current);
                    if (restarted && displayFrozen) {
                        // Hidden under the player's cover: straight back to upright.
                        rewindAnimation.stop();
                        spin = 0;
                        rewind = 0;
                        pulse();
                    } else if (restarted) {
                        // Back to upright, at least one full turn so it shows.
                        spinRamp.stop();
                        spinFactor = 0;
                        rewindAnimation.to = -(spin + (spin < 120 ? 360 : 0));
                        pulse();
                        rewindAnimation.restart();
                    }
                }

                function resetDiscs() {
                    discSwipe.stop();
                    rewindAnimation.stop();
                    swipe = 1;
                    spin = 0;
                    rewind = 0;
                    spinFactor = 1;
                    currentTrackId = bar.spotifyPlayer !== null ? trackId() : "";
                    trackHistory = currentTrackId !== "" ? [currentTrackId] : [];
                    frontDisc().source = bar.spotifyPlayer !== null ? pillArt() : "";
                    if (bar.spotifyPlayer !== null)
                        rememberPosition();

                }

                function changeTrack() {
                    const id = trackId();
                    if (id === currentTrackId)
                        return ;

                    // Without a hint (media keys, phone...): back to the previous track
                    // in the history means backwards.
                    const history = trackHistory.slice();
                    let direction = skipHint;
                    if (direction === 0 && Date.now() < bar.shellState.musicSkipUntil)
                        direction = bar.shellState.musicSkipDirection;

                    if (direction === 0)
                        direction = history.length >= 2 && history[history.length - 2] === id ? -1 : 1;

                    if (direction < 0 && history.length >= 2 && history[history.length - 2] === id)
                        history.pop();
                    else
                        history.push(id);
                    trackHistory = history.slice(-50);
                    skipHint = 0;
                    currentTrackId = id;
                    // The player still reports the old track's position at this point.
                    rememberPosition(0);
                    trackChangeTime = Date.now();
                    discSwipe.stop();
                    // The new disc waits outside the hole, the old one stays in place.
                    swipe = 0;
                    // The old disc keeps its angle, the new one rolls in and lands upright.
                    outgoingSpin = frontAngle;
                    rewindAnimation.stop();
                    rewind = 0;
                    spin = 0;
                    spinRamp.stop();
                    spinFactor = 0;
                    swipeDirection = direction;
                    const previousArt = frontDisc().source;
                    frontIsA = !frontIsA;
                    const art = pillArt();
                    // Spotify sometimes sends the new art a moment later (onTrackArtUrlChanged).
                    const artPending = art === "" || art === previousArt.toString();
                    frontDisc().source = artPending ? "" : art;
                    // No waiting for the cover: it fades in on the disc once loaded.
                    pulse();
                    discSwipe.restart();
                }

                visible: bar.spotifyPlayer !== null
                onDisplayFrozenChanged: {
                    // Starts again gently once the player is folded back.
                    if (!displayFrozen) {
                        spinFactor = 0;
                        spinRamp.restart();
                    }
                }
                Component.onCompleted: Qt.callLater(resetDiscs)
                implicitWidth: 38
                implicitHeight: 38
                radius: 19
                color: bar.surface0

                Behavior on spinSpeed {
                    NumberAnimation {
                        duration: 900
                        easing.type: Easing.InOutQuad
                    }

                }

                // Two discs: on a track change the old one rolls out of the hole and
                // the new one rolls in, forwards or backwards.
                Item {
                    id: discWindow

                    anchors.fill: parent
                    // Slightly larger than the hole: its edge is drawn by the ring above.
                    anchors.margins: 2

                    CoverDisc {
                        id: discA

                        width: parent.width
                        height: parent.height
                        x: musicPill.discX(musicPill.frontIsA)
                        rotation: musicPill.discRotation(musicPill.frontIsA, x)
                        visible: musicPill.frontIsA || musicPill.swipe < 1
                    }

                    CoverDisc {
                        id: discB

                        width: parent.width
                        height: parent.height
                        x: musicPill.discX(!musicPill.frontIsA)
                        rotation: musicPill.discRotation(!musicPill.frontIsA, x)
                        visible: !musicPill.frontIsA || musicPill.swipe < 1
                    }

                }

                Rectangle {
                    id: discWindowMask

                    anchors.fill: discWindow
                    radius: width / 2
                    visible: false
                    layer.enabled: true
                }

                // A layer on discWindow was not redrawn when a disc rotated.
                ShaderEffectSource {
                    id: discWindowSource

                    sourceItem: discWindow
                    hideSource: true
                    live: true
                    visible: false
                }

                MultiEffect {
                    anchors.fill: discWindow
                    source: discWindowSource
                    maskEnabled: true
                    maskSource: discWindowMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }

                // The masks leave a jagged edge (worse while spinning): an antialiased
                // ring of the pill color covers it, the hole stays 32px wide.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1.5
                    radius: width / 2
                    color: "transparent"
                    border.width: 1.5
                    border.color: musicPill.color
                    antialiasing: true
                }

                // Spins while playing, keeps its angle while paused.
                FrameAnimation {
                    running: musicPill.spinSpeed > 0 && !musicPill.displayFrozen
                    onTriggered: musicPill.spin = (musicPill.spin + musicPill.spinSpeed * musicPill.spinFactor * frameTime) % 360
                }

                SequentialAnimation {
                    id: pulseAnimation

                    NumberAnimation {
                        target: musicPill
                        property: "scale"
                        to: 1.16
                        duration: 120
                        easing.type: Easing.OutQuad
                    }

                    NumberAnimation {
                        target: musicPill
                        property: "scale"
                        to: 1
                        duration: 480
                        easing.type: Easing.OutBack
                        easing.overshoot: 3
                    }

                }

                // Leaves time for a real track change (which also resets the position)
                // to be announced first.
                Timer {
                    id: restartCheckDelay

                    interval: 150
                    onTriggered: musicPill.checkRestart()
                }

                // One quick turn backwards, like a record pulled back by hand.
                NumberAnimation {
                    id: rewindAnimation

                    target: musicPill
                    property: "rewind"
                    from: 0
                    duration: 650
                    easing.type: Easing.OutCubic
                    onFinished: {
                        musicPill.spin = 0;
                        musicPill.rewind = 0;
                        spinRamp.restart();
                    }
                }

                // Spotify does not always announce the restart (no Seeked signal): after a
                // "previous" request, its position is asked directly.
                Timer {
                    id: restartProbeDelay

                    interval: 350
                    onTriggered: restartProbe.running = true
                }

                Process {
                    id: restartProbe

                    // Position in microseconds, and the track it belongs to: a real track
                    // change not announced yet must not look like a restart.
                    command: ["playerctl", "-p", "spotify", "metadata", "--format", "{{position}} {{mpris:trackid}}"]

                    stdout: StdioCollector {
                        onStreamFinished: {
                            const [position, track] = text.trim().split(" ");
                            if (bar.spotifyPlayer !== null && track === musicPill.currentTrackId && !isNaN(parseInt(position)))
                                musicPill.checkRestart(parseInt(position) / 1e6);

                        }
                    }

                }

                Connections {
                    function onMusicPreviousRequestsChanged() {
                        restartProbeDelay.restart();
                    }

                    target: bar.shellState
                }

                // Starts spinning gently, like a turntable getting up to speed.
                NumberAnimation {
                    id: spinRamp

                    target: musicPill
                    property: "spinFactor"
                    to: 1
                    duration: 700
                    easing.type: Easing.InQuad
                }

                NumberAnimation {
                    id: discSwipe

                    target: musicPill
                    property: "swipe"
                    from: 0
                    to: 1
                    duration: 520
                    easing.type: Easing.OutCubic
                    onFinished: spinRamp.restart()
                }

                Connections {
                    function onPostTrackChanged() {
                        musicPill.changeTrack();
                    }

                    function onPositionChanged() {
                        restartCheckDelay.restart();
                    }

                    function onIsPlayingChanged() {
                        musicPill.rememberPosition();
                        musicPill.pulse();
                    }

                    function onTrackArtUrlChanged() {
                        // Art sometimes arrives after the track change. It also arrives just
                        // before it, while the old disc is still in front: left to changeTrack.
                        if (musicPill.trackId() === musicPill.currentTrackId)
                            musicPill.frontDisc().source = musicPill.pillArt();

                    }

                    target: bar.spotifyPlayer
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) {
                            musicCloseDelay.stop();
                            musicHideDelay.stop();
                            if (!bar.musicPopupVisible) {
                                bar.musicOpenPending = true;
                                bar.musicPopupVisible = true;
                            } else {
                                bar.musicVisible = true;
                            }
                        } else {
                            musicCloseDelay.restart();
                        }
                    }
                }

                Timer {
                    id: musicCloseDelay

                    interval: 220
                    onTriggered: {
                        bar.musicOpenPending = false;
                        bar.musicVisible = false;
                        musicHideDelay.restart();
                    }
                }

                Timer {
                    id: musicHideDelay

                    // Lets the card fold back onto the pill first.
                    interval: 320
                    onTriggered: bar.musicPopupVisible = false
                }

                // Opens like the calendar: the card grows out of the cover pill and
                // the cover moves to its place in the player.
                PopupWindow {
                    id: musicPopup

                    readonly property real progress: bar.musicProgress
                    // The cover settles during the first 70% so it never crosses the fading-in title.
                    readonly property real coverProgress: Math.min(1, progress / 0.7)
                    // Angle of the pill's disc (-180..180): the cover leaves it at that angle and
                    // straightens up while opening, and turns back to it while folding.
                    readonly property real discAngle: ((musicPill.frontAngle % 360) + 540) % 360 - 180

                    function lerp(from, to) {
                        return from + (to - from) * progress;
                    }

                    visible: bar.musicPopupVisible && bar.spotifyPlayer !== null

                    Connections {
                        function onFrameSwapped() {
                            if (bar.musicOpenPending) {
                                bar.musicOpenPending = false;
                                bar.musicVisible = true;
                            }
                        }

                        target: musicCard.Window.window
                    }

                    implicitWidth: 380
                    implicitHeight: musicPlayerCard.implicitHeight
                    color: "transparent"
                    grabFocus: false

                    anchor {
                        item: musicPill
                        edges: Edges.Top | Edges.Right
                        gravity: Edges.Bottom | Edges.Left
                        adjustment: PopupAdjustment.SlideX
                    }

                    // The anchor is only computed on opening: follow the pill when it
                    // resizes or when the control pill after it changes width.
                    Connections {
                        function onXChanged() {
                            musicPopup.anchor.updateAnchor();
                        }

                        function onYChanged() {
                            musicPopup.anchor.updateAnchor();
                        }

                        function onWidthChanged() {
                            musicPopup.anchor.updateAnchor();
                        }

                        target: musicPill
                    }

                    Connections {
                        function onXChanged() {
                            musicPopup.anchor.updateAnchor();
                        }

                        function onYChanged() {
                            musicPopup.anchor.updateAnchor();
                        }

                        target: musicPill.parent
                    }

                    ClippingRectangle {
                        id: musicCard

                        anchors.top: parent.top
                        anchors.right: parent.right
                        width: musicPopup.lerp(musicPill.width, musicPopup.width)
                        height: musicPopup.lerp(musicPill.height, musicPopup.height)
                        radius: musicPopup.lerp(musicPill.radius, 24)
                        color: "transparent"

                        // Same background as the control center: surface0 (the pill) to base at 0.9,
                        // blurred by the hyprpunk-bar blur_popups layer rule, with the glass rim.
                        GlassSurface {
                            radius: musicCard.radius
                            tinted: false
                            backgroundColor: Qt.rgba(musicPopup.lerp(49, 30) / 255, musicPopup.lerp(50, 30) / 255, musicPopup.lerp(68, 46) / 255, musicPopup.lerp(1, 0.9))
                        }

                        MediaPlayerCard {
                            id: musicPlayerCard

                            active: bar.musicPopupVisible
                            anchors.top: parent.top
                            anchors.right: parent.right
                            width: musicPopup.width
                            opacity: Math.max(0, (musicPopup.progress - 0.7) / 0.3)
                            player: bar.spotifyPlayer
                            glassVisible: false
                            coverVisible: false
                            onSkipRequested: (direction) => {
                                musicPill.skipHint = direction;
                                if (direction < 0)
                                    restartProbeDelay.restart();

                            }
                        }

                        // From the pill's cover (32px circle, 3px inset) to the player's artwork.
                        // Nothing turns: the pill's disc grows at its frozen angle, and the upright
                        // square cover fades in over it (and out again while folding back).
                        Item {
                            readonly property real size: musicPopup.lerp(32, musicPlayerCard.artSize)
                            readonly property real squareOpacity: Math.min(1, Math.max(0, (musicPopup.coverProgress - 0.4) / 0.5))

                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.topMargin: musicPopup.lerp(3, musicPlayerCard.artMargin)
                            // Slides from the right edge to the left one of the growing card, so it is never cut.
                            anchors.leftMargin: (1 - musicPopup.coverProgress) * (musicCard.width - 3 - size) + musicPopup.coverProgress * musicPlayerCard.artMargin
                            width: size
                            height: size

                            CoverDisc {
                                anchors.fill: parent
                                visible: parent.squareOpacity < 1
                                rotation: musicPopup.discAngle
                                antialiasing: true
                                // Same art as the pill's disc, so both match when it folds back.
                                source: bar.spotifyPlayer !== null ? musicPill.pillArt() : ""
                                decodeSize: 64
                            }

                            ClippingRectangle {
                                anchors.fill: parent
                                opacity: parent.squareOpacity
                                visible: opacity > 0
                                radius: musicPlayerCard.artRadius
                                color: bar.surface1

                                Image {
                                    id: musicPopupCover

                                    anchors.fill: parent
                                    source: bar.spotifyPlayer !== null ? bar.spotifyPlayer.trackArtUrl : ""
                                    asynchronous: true
                                    cache: true
                                    fillMode: Image.PreserveAspectCrop
                                    // Its size changes while the player opens: smooth downscaling at any size.
                                    mipmap: true
                                    visible: status === Image.Ready
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: musicPopupCover.status !== Image.Ready
                                    text: "󰎆"
                                    color: bar.mauve
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: musicPopup.lerp(16, 24)
                                }

                            }

                        }

                        HoverHandler {
                            onHoveredChanged: {
                                if (hovered) {
                                    musicCloseDelay.stop();
                                    musicHideDelay.stop();
                                    bar.musicVisible = true;
                                } else {
                                    musicCloseDelay.restart();
                                }
                            }
                        }

                    }

                    mask: Region {
                        item: musicCard
                    }

                }

            }

            // Opens the control center, which grows out of it.
            Pill {
                id: controlPill

                function publishGeometry() {
                    const origin = mapToItem(null, 0, 0);
                    bar.shellState.controlPill = {
                        "right": bar.width - origin.x - width,
                        "top": origin.y,
                        "width": width,
                        "height": height
                    };
                }

                onXChanged: publishGeometry()
                onYChanged: publishGeometry()
                onWidthChanged: publishGeometry()
                onHeightChanged: publishGeometry()
                Component.onCompleted: publishGeometry()
                onHoveredChanged: {
                    bar.shellState.controlPillScreen = bar.screen;
                    bar.shellState.controlPillHovered = hovered;
                }

                // Spinner in place of the icon while NetworkManager connects (VPN included).
                Item {
                    implicitWidth: bar.networkConnecting ? 16 : networkLabel.implicitWidth
                    implicitHeight: networkLabel.implicitHeight

                    Label {
                        id: networkLabel

                        visible: !bar.networkConnecting
                        text: bar.networkIcon()
                    }

                    Shape {
                        id: networkSpinner

                        property real sweep: 90

                        visible: bar.networkConnecting
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.25)
                            strokeWidth: 2

                            PathAngleArc {
                                centerX: networkSpinner.width / 2
                                centerY: networkSpinner.height / 2
                                radiusX: networkSpinner.width / 2 - 1
                                radiusY: networkSpinner.height / 2 - 1
                                startAngle: 0
                                sweepAngle: 360
                            }

                        }

                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: "#cba6f7"
                            strokeWidth: 2
                            capStyle: ShapePath.RoundCap

                            PathAngleArc {
                                centerX: networkSpinner.width / 2
                                centerY: networkSpinner.height / 2
                                radiusX: networkSpinner.width / 2 - 1
                                radiusY: networkSpinner.height / 2 - 1
                                startAngle: -90
                                sweepAngle: networkSpinner.sweep
                            }

                        }

                        RotationAnimator on rotation {
                            running: networkSpinner.visible
                            from: 0
                            to: 360
                            duration: 900
                            loops: Animation.Infinite
                        }

                        // The arc stretches and shrinks as it turns.
                        SequentialAnimation on sweep {
                            running: networkSpinner.visible
                            loops: Animation.Infinite

                            NumberAnimation {
                                to: 270
                                duration: 700
                                easing.type: Easing.InOutCubic
                            }

                            NumberAnimation {
                                to: 40
                                duration: 700
                                easing.type: Easing.InOutCubic
                            }

                        }

                    }

                    // No locked Ethernet glyph in Material Design: a padlock badge instead.
                    Rectangle {
                        visible: bar.wiredLocked && !bar.networkConnecting
                        anchors.right: networkLabel.right
                        anchors.bottom: networkLabel.bottom
                        anchors.rightMargin: -4
                        anchors.bottomMargin: 1
                        width: 11
                        height: 11
                        radius: width / 2
                        color: controlPill.color

                        Label {
                            anchors.centerIn: parent
                            text: "󰌾"
                            font.pixelSize: 9
                        }

                    }

                    ToolTipArea {
                        text: bar.networkTooltip()
                    }

                }

                IconText {
                    visible: bar.audioSink !== null
                    icon: bar.volumeIcon()
                    text: bar.audioVolume + "%"

                    ToolTipArea {
                        text: bar.audioSink !== null ? bar.audioSink.description : ""
                    }

                }

                IconText {
                    visible: bar.hasBattery
                    color: bar.battery.percentage <= 0.2 ? bar.red : bar.mauve
                    icon: bar.batteryIcon()
                    text: Math.round(bar.battery.percentage * 100) + "%"

                    ToolTipArea {
                        text: bar.batteryTooltip()
                    }

                }

            }

        }

    }

    Process {
        id: resourceProcess

        command: ["sh", "-c", "free -m | awk '/^Mem:/ {printf \"%.1fG\\n\", $3/1024}'; sensors 2>/dev/null | awk '/Package id 0:/ {gsub(/[+°C]/, \"\", $4); printf \"%.0f°C\\n\", $4; found=1; exit} /^Tctl:/ {gsub(/[+°C]/, \"\", $2); printf \"%.0f°C\\n\", $2; found=1; exit} /^Tdie:/ {gsub(/[+°C]/, \"\", $2); printf \"%.0f°C\\n\", $2; found=1; exit} END {if (!found) print \"--°C\"}'; awk '/cpu MHz/ {sum += $4; count++} END {printf \"%.0f MHz\\n\", count ? sum/count : 0}' /proc/cpuinfo; lscpu | sed -n 's/^Model name:[[:space:]]*//p' | head -n1; head -n1 /proc/stat"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines.length > 0 && lines[0] !== "")
                    bar.memoryText = lines[0];

                if (lines.length > 1)
                    bar.cpuTemperature = lines[1];

                if (lines.length > 3) {
                    bar.cpuFrequency = lines[2];
                    bar.cpuModel = lines[3];
                }
                const stat = lines.find((line) => {
                    return line.startsWith("cpu ");
                });
                if (stat !== undefined) {
                    const jiffies = stat.trim().split(/\s+/).slice(1).map(Number);
                    const idle = jiffies[3] + (jiffies[4] || 0);
                    const total = jiffies.slice(0, 8).reduce((sum, value) => {
                        return sum + (value || 0);
                    }, 0);
                    if (bar.cpuStat[1] > 0 && total > bar.cpuStat[1])
                        bar.cpuUsage = Math.round(100 * (1 - (idle - bar.cpuStat[0]) / (total - bar.cpuStat[1])));

                    bar.cpuStat = [idle, total];
                }
            }
        }

    }

    Process {
        id: vpnProcess

        // NAME last: it is the only field that can hold an (escaped) colon.
        command: ["nmcli", "-t", "-f", "TYPE,STATE,NAME", "connection", "show", "--active"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const connections = [];
                for (const line of text.trim().split("\n")) {
                    const fields = line.split(":");
                    if (fields.length >= 3 && (fields[0] === "vpn" || fields[0] === "wireguard"))
                        connections.push({
                        "state": fields[1],
                        "name": fields.slice(2).join(":").replace(/\\:/g, ":")
                    });

                }
                bar.vpnConnections = connections;
            }
        }

    }

    // Any NetworkManager change refreshes the VPN list, coalesced.
    Process {
        command: ["nmcli", "monitor"]
        running: true

        stdout: SplitParser {
            onRead: vpnRefresh.restart()
        }

    }

    Timer {
        id: vpnRefresh

        interval: 250
        onTriggered: vpnProcess.running = true
    }

    Process {
        id: updateProcess

        // Official repos and AUR, counted together.
        command: ["sh", "-c", "{ checkupdates; yay -Qua; } 2>/dev/null | wc -l"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const count = parseInt(text.trim());
                bar.updatesText = count > 0 ? " " + count : "";
            }
        }

    }

    Process {
        id: upgradeProcess

        command: ["kitty", "-e", "yay", "-Syu", "--noconfirm", "--removemake"]
        onExited: updateProcess.running = true
    }

    Timer {
        interval: 60 * 60 * 1000
        running: true
        repeat: true
        onTriggered: updateProcess.running = true
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: resourceProcess.running = true
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: updateProcess.running = true
    }

    Process {
        id: lockStateProcess

        command: ["sh", "-c", "hyprctl devices -j 2>/dev/null | jq -r '([.keyboards[]?.capsLock] | any), ([.keyboards[]?.numLock] | any)'"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines.length < 2)
                    return ;

                const newCapsLock = lines[0] === "true";
                const newNumLock = lines[1] === "true";
                if (bar.lockStateInitialized) {
                    if (newCapsLock !== bar.capsLockEnabled)
                        bar.showStatusOsd("󰪛", "Caps Lock", newCapsLock);

                    if (newNumLock !== bar.numLockEnabled)
                        bar.showStatusOsd("󰎤", "Num Lock", newNumLock);

                }
                bar.capsLockEnabled = newCapsLock;
                bar.numLockEnabled = newNumLock;
                bar.lockStateInitialized = true;
            }
        }

    }

    Timer {
        interval: 120
        running: true
        repeat: true
        onTriggered: {
            if (!lockStateProcess.running)
                lockStateProcess.running = true;

        }
    }

    FileView {
        id: touchpadStateFile

        function updateTouchpadState() {
            const match = touchpadStateFile.text().match(/(?:^|\n)enabled=(true|false)(?:\n|$)/);
            if (match === null)
                return ;

            const enabled = match[1] === "true";
            if (bar.touchpadStateInitialized && enabled !== bar.touchpadEnabled)
                bar.showStatusOsd("󰟸", "Touchpad", enabled);

            bar.touchpadEnabled = enabled;
            bar.touchpadStateInitialized = true;
        }

        path: bar.stateHome + "/hyprpunk/touchpad-state.conf"
        watchChanges: true
        preload: true
        printErrors: false
        onLoaded: updateTouchpadState()
        onTextChanged: updateTouchpadState()
        onFileChanged: reload()
    }

    PwObjectTracker {
        objects: bar.micSource !== null ? [bar.micSource] : []
    }

    PwObjectTracker {
        objects: bar.audioSink !== null ? [bar.audioSink] : []
    }

    Timer {
        interval: 600
        running: true
        onTriggered: bar.volumeInitialized = true
    }

    Process {
        id: brightnessProcess

        command: ["brightnessctl", "-m"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split(",");
                if (fields.length < 4)
                    return ;

                const newBrightness = parseInt(fields[3]);
                const changed = bar.brightnessInitialized && newBrightness !== bar.screenBrightness;
                // Changes announced by hypridle are not shown (only the next one).
                const muted = changed && Date.now() < bar.shellState.screenOsdMutedUntil;
                if (muted)
                    bar.shellState.screenOsdMutedUntil = 0;

                bar.screenBrightness = newBrightness;
                if (changed && !muted)
                    bar.showStatusOsd(bar.brightnessIcon(), "Brightness", newBrightness > 0, newBrightness, 100);

                bar.brightnessInitialized = true;
            }
        }

    }

    Process {
        command: ["udevadm", "monitor", "--kernel", "--subsystem-match=backlight"]
        running: true

        stdout: SplitParser {
            onRead: brightnessProcess.running = true
        }

    }

    Timer {
        id: micInitDelay

        interval: 500
        running: true
        onTriggered: bar.micStateInitialized = true
    }

    Process {
        command: ["sh", "-c", "ls -d /sys/class/leds/*::kbd_backlight 2>/dev/null | head -n 1"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: bar.keyboardBacklightPath = text.trim()
        }

    }

    // The ASUS driver changes the keyboard backlight itself on Fn keys and
    // sysfs sends no inotify event for it, so the value is polled.
    FileView {
        id: keyboardBacklightFile

        function updateKeyboardBacklight() {
            const level = parseInt(keyboardBacklightFile.text());
            if (isNaN(level) || level === bar.keyboardBacklight)
                return ;

            const max = parseInt(keyboardBacklightMaxFile.text()) || 3;
            // Changes announced by hypridle are not shown (only the next one).
            const muted = Date.now() < bar.shellState.keyboardOsdMutedUntil;
            if (muted)
                bar.shellState.keyboardOsdMutedUntil = 0;

            if (bar.keyboardBacklight >= 0 && !muted)
                bar.showStatusOsd("󰌌", "Keyboard light", level > 0, level, max);

            bar.keyboardBacklight = level;
        }

        path: bar.keyboardBacklightPath !== "" ? bar.keyboardBacklightPath + "/brightness" : ""
        printErrors: false
        onLoaded: updateKeyboardBacklight()
    }

    // Only updated by the driver, i.e. on Fn key presses, never by brightnessctl
    // (hypridle): such changes always get the OSD.
    FileView {
        id: keyboardBacklightHwFile

        path: bar.keyboardBacklightPath !== "" ? bar.keyboardBacklightPath + "/brightness_hw_changed" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const level = parseInt(text());
            const max = parseInt(keyboardBacklightMaxFile.text()) || 3;
            if (bar.keyboardHwInitialized && !isNaN(level))
                bar.showStatusOsd("󰌌", "Keyboard light", level > 0, level, max);

            // The first load only reads the last value, it is not a key press.
            bar.keyboardHwInitialized = true;
        }
        // Unreadable until the first Fn key press since boot.
        onLoadFailed: bar.keyboardHwInitialized = true
    }

    FileView {
        id: keyboardBacklightMaxFile

        path: bar.keyboardBacklightPath !== "" ? bar.keyboardBacklightPath + "/max_brightness" : ""
        printErrors: false
    }

    Timer {
        interval: 250
        running: bar.keyboardBacklightPath !== ""
        repeat: true
        onTriggered: keyboardBacklightFile.reload()
    }

    Behavior on musicProgress {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }

    }

    Behavior on monitorProgress {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }

    }

    Behavior on clockCenterOffset {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }

    }

}
