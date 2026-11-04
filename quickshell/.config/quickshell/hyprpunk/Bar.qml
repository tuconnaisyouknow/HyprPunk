import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Wayland

// The bar along the top of each screen, a row of pills: workspaces and resources on
// the left, the dynamic island in the middle, updates, the Spotify record and the
// control pill on the right. Most pills open a card on hover. The island's card holds
// the calendar and the notifications waiting, and Super+N or a click keeps it open.
PanelWindow {
    id: bar

    required property var shellState
    required property var notificationServer
    readonly property int notificationCount: notificationServer.trackedNotifications.values.length
    readonly property var workspaceIcons: ["", "", "", "", "", "", "", "", "", "", ""]
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery.ready && battery.isLaptopBattery && battery.isPresent
    // Which of your other workspaces the preview card opens on.
    property var previewWorkspace: null
    readonly property var previewWorkspaces: workspaceSwitcher.workspaces.filter((workspace) => {
        return !workspace.focused;
    }).sort((a, b) => {
        return a.id - b.id;
    })
    // The workspace you were on before this one, which the preview opens on when you
    // ask for it with the keyboard: the one you most likely want back.
    property var lastWorkspace: null
    property var shownWorkspace: null
    readonly property var activeWorkspace: workspaceSwitcher.hyprlandMonitor !== null ? workspaceSwitcher.hyprlandMonitor.activeWorkspace : null
    // A snapshot of the bar for the previews (keeping grabToImage's result keeps it alive).
    property var barSnapshot: null
    readonly property int workspacePreviewWidth: 400
    // The screen's shape, 16:9 until Hyprland has told which monitor the bar is on.
    readonly property int workspacePreviewHeight: {
        const monitor = Hyprland.monitorFor(bar.screen);
        return Math.round(workspacePreviewWidth * (monitor !== null && monitor.width > 0 ? monitor.height / monitor.width : 9 / 16));
    }
    // Only Spotify: browsers and other MPRIS players are ignored.
    readonly property var spotifyPlayer: {
        for (const player of Mpris.players.values) {
            if (player.dbusName === "org.mpris.MediaPlayer2.spotify")
                return player;

        }
        return null;
    }
    property bool statusOsdVisible: false
    // While the session is locked, the lock's island shows the OSD and the bar's own one
    // stays still. It isn't drawn under the lock, so it would only catch up on its
    // animations once the lock is gone.
    property bool sessionLocked: false
    readonly property bool islandOsdShown: statusOsdVisible && !sessionLocked
    property string statusOsdIcon: ""
    property string statusOsdLabel: ""
    property bool statusOsdEnabled: false
    // "airpods": a pod and its battery ring instead of an icon, label and gauge.
    // "battery": the battery's alert, its icon, a title and the time left.
    // "screenshot": a thumbnail of what was just captured (for a recording, its first
    // frame), titled statusOsdTitle; a click opens statusOsdFile.
    property string statusOsdKind: ""
    property string statusOsdImage: ""
    property string statusOsdTitle: ""
    property string statusOsdFile: ""
    // Seconds since the recording started, for the island.
    property int recordingElapsed: 0
    property var statusOsdRingLevel: null
    property bool statusOsdRingCharging: false
    // Level gauge shown instead of the On/Off badge when statusOsdMaxLevel > 0.
    property int statusOsdLevel: 0
    property int statusOsdMaxLevel: 0
    readonly property int batteryPercent: Math.round(battery.percentage * 100)
    // The lowest warning level (20, 10 or 5 %) crossed since the last time it was plugged
    // in, 0 above them. Each warning shows once; the critical one stays up.
    property int batteryAlertStage: 0
    readonly property bool batteryCritical: hasBattery && UPower.onBattery && batteryAlertStage === 5
    // Off while the shell starts: UPower's first values aren't a plug or unplug.
    property bool powerEventsReady: false
    // Time left worked out from the battery's own draw, for the first seconds after
    // unplugging when UPower has no estimate yet. 0 when there's none.
    property real batteryDrawEstimate: 0
    readonly property real batteryTimeLeft: battery.timeToEmpty > 0 ? battery.timeToEmpty : batteryDrawEstimate
    readonly property bool batteryEstimating: statusOsdVisible && statusOsdKind === "battery" && statusOsdLabel === "On battery" && batteryTimeLeft <= 0
    readonly property var micSource: Pipewire.defaultAudioSource
    readonly property bool micMuted: micSource !== null && micSource.audio !== null && micSource.audio.muted
    property bool micStateInitialized: false
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property int audioVolume: audioSink !== null && audioSink.audio !== null ? Math.round(audioSink.audio.volume * 100) : 0
    readonly property bool audioMuted: audioSink !== null && audioSink.audio !== null && audioSink.audio.muted
    property bool volumeInitialized: false
    // The output whose volume changes we show, updated whenever the output changes.
    property var volumeSink: audioSink
    property real clockCenterOffset: bar.islandOsdShown ? 3 : -3
    // The regional formats you picked (locale-profilectl.sh). The calendar's day names
    // and first day of the week follow them, even though the shell keeps its startup locale.
    readonly property var regionalLocale: Qt.locale(Session.regionalProfile === "us" ? "en_US" : "fr_FR")

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
    readonly property bool networkConnecting: (networkDevice !== null && !networkDevice.connected) || Vpn.connecting
    readonly property bool wiredLocked: networkDevice !== null && networkDevice.connected && networkDevice.type === DeviceType.Wired && Vpn.connection !== null

    // Where each pill sits on screen, so the lock screen can start from there: the ones it
    // keeps (resources, island, control pill) and the ones it lets go.
    function lockGeometry() {
        const rect = (item) => {
            const origin = item.mapToItem(null, 0, 0);
            return {
                "x": origin.x,
                "y": origin.y,
                "width": item.width,
                "height": item.height,
                "radius": item.radius !== undefined ? item.radius : item.height / 2
            };
        };
        const others = [];
        for (const group of [leftGroup, centerGroup, rightGroup]) {
            for (const child of group.children) {
                if (child === monitorPill || child === clockPill || child === controlPill || !child.visible || child.width <= 0)
                    continue;

                // A drop-in slot: the pill inside it.
                others.push(rect(child.pill !== undefined && child.pill !== null ? child.pill : child));
            }
        }
        return {
            "monitor": monitorPill.visible ? rect(monitorPill) : null,
            "island": rect(clockPill),
            "control": rect(controlPill),
            "others": others
        };
    }

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

        const network = bar.activeWifiNetwork(device);
        return Icons.wifi(network !== null ? network.signalStrength : 0, device.connected && Vpn.connection !== null);
    }

    function capitalized(text) {
        return text.charAt(0).toUpperCase() + text.slice(1);
    }

    // With maxLevel > 0, a gauge of level / maxLevel replaces the On/Off badge.
    function showStatusOsd(icon, label, enabled, level, maxLevel) {
        calendarPopup.dismiss();
        statusOsdKind = "";
        statusOsdHideDelay.interval = 1500;
        statusOsdIcon = icon;
        statusOsdLabel = label;
        statusOsdEnabled = enabled;
        statusOsdLevel = level !== undefined ? level : 0;
        statusOsdMaxLevel = maxLevel !== undefined ? maxLevel : 0;
        statusOsdVisible = true;
        statusOsdHideDelay.restart();
    }

    function showAirPodsOsd(osd) {
        calendarPopup.dismiss();
        statusOsdKind = "airpods";
        statusOsdImage = osd.image;
        statusOsdRingLevel = osd.level;
        statusOsdRingCharging = osd.charging;
        // Fades the content in like a new OSD.
        statusOsdLabel = "AirPods";
        statusOsdHideDelay.interval = 3000;
        statusOsdVisible = true;
        statusOsdHideDelay.restart();
    }

    function updateBatteryAlert() {
        if (!hasBattery)
            return ;

        if (!UPower.onBattery) {
            batteryAlertStage = 0;
            return ;
        }
        const stage = batteryPercent <= 5 ? 5 : batteryPercent <= 10 ? 10 : batteryPercent <= 20 ? 20 : 0;
        if (stage === 0 || (batteryAlertStage > 0 && stage >= batteryAlertStage)) {
            if (stage === 0)
                batteryAlertStage = 0;

            return ;
        }
        batteryAlertStage = stage;
        showBatteryOsd(stage === 5 ? "Battery critical" : "Battery low");
    }

    // m:ss, h:mm:ss past an hour.
    function formatDuration(seconds) {
        const pad = (value) => {
            return String(value).padStart(2, "0");
        };
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor(seconds / 60) % 60;
        return (hours > 0 ? hours + ":" + pad(minutes) : minutes) + ":" + pad(seconds % 60);
    }

    function showScreenshotOsd(taken) {
        calendarPopup.dismiss();
        statusOsdKind = "screenshot";
        statusOsdImage = taken.file;
        statusOsdFile = taken.video || taken.file;
        statusOsdTitle = taken.video ? "Recording" : "Screenshot";
        statusOsdLabel = taken.video ? formatDuration(taken.duration) + " · Saved" : taken.annotated ? "Annotated · Saved" : "Copied · Saved";
        statusOsdHideDelay.interval = 3500;
        statusOsdVisible = true;
        statusOsdHideDelay.restart();
    }

    // The calendar and notifications card, kept open until closed (Escape, a click
    // outside, the shortcut or the clock again).
    function toggleNotificationCard() {
        calendarPopup.togglePinned();
    }

    // Plugging in or unplugging shows in the island, unless unplugging brings up a
    // low-battery warning instead.
    function powerSourceChanged() {
        updateBatteryAlert();
        if (!hasBattery || !powerEventsReady)
            return ;

        if (!UPower.onBattery)
            showBatteryOsd("Charging");
        else if (batteryAlertStage === 0)
            showBatteryOsd("On battery");
    }

    function showBatteryOsd(title) {
        calendarPopup.dismiss();
        statusOsdKind = "battery";
        statusOsdLabel = title;
        batteryDrawEstimate = 0;
        // Unplugged: stays until the time left is known, then a moment to read it.
        statusOsdHideDelay.interval = title === "On battery" && batteryTimeLeft <= 0 ? 8000 : title === "Charging" || title === "On battery" ? 2500 : 6000;
        statusOsdVisible = true;
        // The critical alert stays until the computer is plugged in.
        if (batteryCritical)
            statusOsdHideDelay.stop();
        else
            statusOsdHideDelay.restart();
    }

    // Ends the OSD now, as its delay would. Another OSD over the critical battery alert
    // goes back to the alert, which stays until the computer is plugged in.
    function endStatusOsd() {
        statusOsdHideDelay.stop();
        if (batteryCritical)
            showBatteryOsd("Battery critical");
        else
            statusOsdVisible = false;
    }

    // Green while charging, mauve on battery, red for the alerts.
    function batteryOsdColor() {
        if (statusOsdLabel === "Charging")
            return Theme.green;

        return statusOsdLabel === "On battery" ? Theme.mauve : Theme.red;
    }

    // "64% · 1 h 05 until full" while charging, "64% · 3 h 10 left" on battery,
    // just the percentage until UPower has an estimate.
    function batteryDetail() {
        const seconds = UPower.onBattery ? batteryTimeLeft : battery.timeToFull;
        if (!(seconds > 0))
            return batteryPercent + (batteryEstimating ? "% · Estimating…" : UPower.onBattery ? "%" : "% · Plugged in");

        const hours = Math.floor(seconds / 3600);
        const minutes = Math.round((seconds % 3600) / 60);
        const duration = hours > 0 ? hours + " h " + String(minutes).padStart(2, "0") : minutes + " min";
        return batteryPercent + "% · " + duration + (UPower.onBattery ? " left" : " until full");
    }

    function showVolumeOsd() {
        // Checked here too: the volume can change (dropping to 0 as an output goes away)
        // before the output itself does.
        if (audioSink !== volumeSink) {
            resetVolumeOsd();
            return ;
        }
        if (volumeInitialized && audioSink !== null && audioSink.ready && audioSink.audio !== null)
            // Muted, the gauge keeps its level and turns lavender.
            showStatusOsd(Icons.volume(audioVolume, audioMuted), audioMuted ? "Muted" : "Volume", !audioMuted, audioVolume, 100);

    }

    // Switching output (AirPods coming or going) brings its own volume, that's not a change.
    function resetVolumeOsd() {
        volumeSink = audioSink;
        volumeInitialized = false;
        volumeInitDelay.restart();
    }

    // The island's new content fades in while the pill resizes around it.
    onActiveWorkspaceChanged: {
        lastWorkspace = shownWorkspace;
        shownWorkspace = activeWorkspace;
    }
    onStatusOsdVisibleChanged: islandContentFade.restart()
    onStatusOsdLabelChanged: islandContentFade.restart()
    onAudioVolumeChanged: showVolumeOsd()
    onAudioMutedChanged: showVolumeOsd()
    onAudioSinkChanged: resetVolumeOsd()
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
    // Named so Hyprland's layer rule can blur the player popup too.
    WlrLayershell.namespace: "hyprpunk-bar"

    anchors {
        top: true
        left: true
        right: true
    }

    Item {
        id: barContent

        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24

        RowLayout {
            id: leftGroup

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -(bar.implicitHeight - 50) / 2
            spacing: 9

            // Previews a workspace on hover, in a card that grows out of it.
            Pill {
                id: workspacePill

                onHoveredChanged: {
                    if (!hovered)
                        workspacePopup.hoverEnded();

                }

                WorkspaceSwitcher {
                    id: workspaceSwitcher

                    screen: bar.screen
                    icons: bar.workspaceIcons
                    // Waits like the other pills. No need to preview the workspace you're on.
                    onHoveredWorkspaceChanged: {
                        if (hoveredWorkspace !== null && !hoveredWorkspace.focused && !workspacePopup.mapped)
                            workspacePopup.hoverStarted();
                        else
                            workspacePopup.cancelOpen();
                    }
                }

                PillPopup {
                    id: workspacePopup

                    pill: workspacePill
                    openable: workspaceSwitcher.hoveredWorkspace !== null
                    // The preview inside the control center's padding.
                    implicitWidth: bar.workspacePreviewWidth + 28
                    implicitHeight: bar.workspacePreviewHeight + 28
                    // Ask Hyprland where the windows are (it only says when asked), and
                    // snapshot the bar to lay over every preview.
                    onOpening: {
                        Hyprland.refreshToplevels();
                        barContent.grabToImage((result) => {
                            bar.barSnapshot = result;
                        });
                        if (workspaceSwitcher.hoveredWorkspace !== null)
                            bar.previewWorkspace = workspaceSwitcher.hoveredWorkspace;
                        else
                            bar.previewWorkspace = bar.previewWorkspaces.includes(bar.lastWorkspace) ? bar.lastWorkspace : null;
                    }
                    // Opened with its shortcut: the arrows (Vim's too) or Tab go through
                    // the workspaces, Enter takes you there.
                    onKeyPressed: (key) => {
                        const card = previewLoader.item;
                        if (card === null)
                            return ;

                        const french = Session.keyboardLayout === "fr";
                        if (key === Qt.Key_Left || key === Qt.Key_Backtab || key === (french ? Qt.Key_J : Qt.Key_H))
                            card.step(-1);
                        else if (key === Qt.Key_Right || key === Qt.Key_Tab || key === (french ? Qt.Key_M : Qt.Key_L))
                            card.step(1);
                        else if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space)
                            card.choose();
                    }

                    // Its shortcut, which does nothing while your other workspaces are
                    // all empty: there would be nothing to preview.
                    Connections {
                        function onPanelRequestsChanged() {
                            if (bar.previewWorkspaces.length === 0 && !workspacePopup.expanded)
                                return ;

                            workspacePopup.request(bar.shellState.requestedAction("workspaces", bar.screen));

                        }

                        target: bar.shellState
                    }

                    // Rebuilt on every opening, so the windows are captured fresh.
                    Loader {
                        id: previewLoader

                        x: 14
                        y: 14
                        width: bar.workspacePreviewWidth
                        height: bar.workspacePreviewHeight
                        active: workspacePopup.mapped
                        opacity: workspacePopup.expanded ? 1 : 0

                        sourceComponent: WorkspacePreviewCard {
                            workspaces: bar.previewWorkspaces
                            initialWorkspace: bar.previewWorkspace
                            monitor: workspaceSwitcher.hyprlandMonitor
                            wallpaper: Session.wallpaper
                            barImage: bar.barSnapshot !== null ? bar.barSnapshot.url : ""
                            barRect: Qt.rect(barContent.x, barContent.y, barContent.width, barContent.height)
                            onWorkspaceChosen: (workspace) => {
                                workspace.activate();
                                workspacePopup.close();
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                }

            }

            // Opens the system monitor on hover, which grows out of it like the player.
            Pill {
                id: monitorPill

                visible: bar.width >= 1200
                onHoveredChanged: {
                    if (hovered)
                        monitorPopup.hoverStarted();
                    else
                        monitorPopup.hoverEnded();
                }

                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: monitorPopup.togglePinned()
                }

                IconText {
                    icon: ""
                    text: SystemStats.memoryText
                }

                IconText {
                    icon: ""
                    text: Math.round(SystemStats.cpuUsage * 100) + "%"
                }

                PillPopup {
                    id: monitorPopup

                    pill: monitorPill
                    implicitWidth: monitorContent.implicitWidth
                    implicitHeight: monitorContent.implicitHeight

                    // Its shortcut, with nothing to open from on a bar too narrow for its pill.
                    Connections {
                        function onPanelRequestsChanged() {
                            if (monitorPill.visible)
                                monitorPopup.request(bar.shellState.requestedAction("systemmonitor", bar.screen));

                        }

                        target: bar.shellState
                    }

                    SystemMonitorCard {
                        id: monitorContent

                        width: monitorPopup.width
                        opacity: monitorPopup.expanded ? 1 : 0
                        active: monitorPopup.mapped

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                }

            }

        }

        // When the calendar covers the island, the privacy and recording dots move to its
        // right, following its edge as it grows.
        PrivacyDot {
            x: Math.round(centerGroup.x + clockPill.x + clockPill.width / 2 + calendarPopup.card.width / 2 + 8)
            y: Math.round(centerGroup.y + clockPill.y + clockPill.height / 2 - height / 2)
            camera: bar.shellState.cameraInUse
            microphone: bar.shellState.microphoneInUse
            recording: bar.shellState.recording
            opacity: active ? calendarPopup.progress : 0
            visible: calendarPopup.mapped && opacity > 0
        }

        // Same when the island is busy with an OSD: they sit to its right.
        PrivacyDot {
            x: Math.round(centerGroup.x + clockPill.x + clockPill.width + 8)
            y: Math.round(centerGroup.y + clockPill.y + clockPill.height / 2 - height / 2)
            camera: bar.shellState.cameraInUse
            microphone: bar.shellState.microphoneInUse
            recording: bar.shellState.recording
            opacity: active && bar.islandOsdShown && !calendarPopup.mapped ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
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
                // The whole pill opens the calendar card, like the other pills, unless an
                // OSD has the island.
                onHoveredChanged: {
                    if (hovered && !bar.islandOsdShown)
                        calendarPopup.hoverStarted();
                    else
                        calendarPopup.hoverEnded();
                }
                spacing: 8

                // A click keeps the card open, or closes it once kept.
                TapHandler {
                    enabled: !bar.islandOsdShown
                    cursorShape: Qt.PointingHandCursor
                    onTapped: bar.toggleNotificationCard()
                }

                // The screenshot or recording just taken opens in its viewer.
                TapHandler {
                    enabled: bar.statusOsdVisible && bar.statusOsdKind === "screenshot"
                    cursorShape: Qt.PointingHandCursor
                    onTapped: {
                        Quickshell.execDetached(["xdg-open", bar.statusOsdFile]);
                        bar.statusOsdVisible = false;
                    }
                }
                horizontalPadding: bar.islandOsdShown ? 36 : 20
                implicitHeight: bar.islandOsdShown ? 50 : 38
                // Grows two pixels at a time, so centring it on the bar and its content in it
                // never lands on a half pixel and the content stops shaking as it resizes.
                Layout.preferredWidth: 2 * Math.round(implicitWidth / 2)
                Layout.preferredHeight: 2 * Math.round(implicitHeight / 2)
                contentOpacity: 1

                Label {
                    id: dateTimeLabel

                    visible: !bar.islandOsdShown
                    text: Qt.formatDateTime(clock.date, "HH:mm")

                    // Ticks every second though it shows minutes: its timer stands still
                    // during sleep, so on waking it would keep the old time up to a minute.
                    SystemClock {
                        id: clock

                        precision: SystemClock.Seconds
                    }

                }

                // Privacy: a dot after the time while something is listening or watching,
                // green for the camera, orange for the microphone alone.
                Item {
                    readonly property bool shown: !bar.islandOsdShown && (bar.shellState.cameraInUse || bar.shellState.microphoneInUse)

                    // Gone at once when an OSD takes the island, or its shrinking would pull
                    // the OSD sideways while it grows.
                    visible: !bar.islandOsdShown && Layout.preferredWidth > 0
                    Layout.preferredWidth: shown ? 8 : 0
                    Layout.leftMargin: shown ? -2 : -clockPill.spacing
                    implicitHeight: 8

                    Rectangle {
                        anchors.centerIn: parent
                        width: 8
                        height: 8
                        radius: 4
                        scale: parent.shown ? 1 : 0
                        color: bar.shellState.cameraInUse ? Theme.green : Theme.peach

                        Behavior on scale {
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.OutBack
                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }

                        }

                    }

                    Behavior on Layout.preferredWidth {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on Layout.leftMargin {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                // Recording: a pulsing red dot and how long it's been going, after the time.
                // Click to stop.
                Item {
                    id: recordingChip

                    readonly property bool shown: !bar.islandOsdShown && bar.shellState.recording

                    // Gone at once when an OSD takes the island, like the privacy dot.
                    visible: !bar.islandOsdShown && Layout.preferredWidth > 0
                    Layout.preferredWidth: shown ? recordingRow.implicitWidth + 16 : 0
                    Layout.leftMargin: shown ? 0 : -clockPill.spacing
                    implicitHeight: 24
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: recordingHover.hovered ? Theme.alpha(Theme.red, 0.28) : Theme.alpha(Theme.red, 0.16)

                        Behavior on color {
                            ColorAnimation {
                                duration: 140
                            }

                        }

                    }

                    Row {
                        id: recordingRow

                        anchors.verticalCenter: parent.verticalCenter
                        x: 8
                        spacing: 6

                        // The stop square on hover, the dot otherwise.
                        Rectangle {
                            id: recordingDot

                            anchors.verticalCenter: parent.verticalCenter
                            width: 8
                            height: 8
                            radius: recordingHover.hovered ? 2 : 4
                            color: Theme.red

                            SequentialAnimation on opacity {
                                running: recordingChip.shown && !recordingHover.hovered
                                loops: Animation.Infinite
                                onRunningChanged: {
                                    if (!running)
                                        recordingDot.opacity = 1;

                                }

                                NumberAnimation {
                                    to: 0.3
                                    duration: 700
                                    easing.type: Easing.InOutSine
                                }

                                NumberAnimation {
                                    to: 1
                                    duration: 700
                                    easing.type: Easing.InOutSine
                                }

                            }

                            Behavior on radius {
                                NumberAnimation {
                                    duration: 140
                                }

                            }

                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: bar.formatDuration(bar.recordingElapsed)
                            color: Theme.red
                            font.family: Theme.font
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            font.features: {
                                "tnum": 1
                            }
                        }

                    }

                    HoverHandler {
                        id: recordingHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: bar.shellState.requestScreenshot("stop", "", 0)
                    }

                    Behavior on Layout.preferredWidth {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on Layout.leftMargin {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                // Notifications waiting: a bell and how many, after the time. Lavender at
                // half opacity while Focus keeps them quiet.
                Item {
                    id: notificationBadge

                    readonly property bool shown: !bar.islandOsdShown && bar.notificationCount > 0

                    // Gone at once when an OSD takes the island, like the privacy dot.
                    visible: !bar.islandOsdShown && Layout.preferredWidth > 0
                    Layout.preferredWidth: shown ? notificationBadgeRow.implicitWidth + 14 : 0
                    Layout.leftMargin: shown ? 0 : -clockPill.spacing
                    implicitHeight: 24
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Theme.alpha(bar.shellState.doNotDisturb ? Theme.lavender : Theme.mauve, 0.16)

                        Behavior on color {
                            ColorAnimation {
                                duration: 140
                            }

                        }

                    }

                    Row {
                        id: notificationBadgeRow

                        anchors.verticalCenter: parent.verticalCenter
                        x: 7
                        spacing: 4
                        opacity: bar.shellState.doNotDisturb ? 0.5 : 1

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: bar.shellState.doNotDisturb ? "󰂛" : "󰂚"
                            color: bar.shellState.doNotDisturb ? Theme.lavender : Theme.mauve
                            font.family: Theme.font
                            font.pixelSize: 13
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: bar.notificationCount
                            color: bar.shellState.doNotDisturb ? Theme.lavender : Theme.mauve
                            font.family: Theme.font
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            font.features: {
                                "tnum": 1
                            }
                        }

                    }

                    Behavior on Layout.preferredWidth {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on Layout.leftMargin {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                IslandOsd {
                    bar: bar
                    visible: bar.islandOsdShown
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

                // The pill is ~90% open by then, so its edges don't clip the content.
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
                onTriggered: bar.endStatusOsd()
            }

            PillPopup {
                id: calendarPopup

                readonly property date currentDate: clock.date
                readonly property int currentYear: currentDate.getFullYear()
                readonly property int currentMonth: currentDate.getMonth()
                readonly property int currentDay: currentDate.getDate()
                property int monthOffset: 0
                readonly property date displayedMonth: new Date(currentYear, currentMonth + monthOffset, 1)
                readonly property int displayedYear: displayedMonth.getFullYear()
                readonly property int displayedMonthNumber: displayedMonth.getMonth()
                // Column of the month's first day, the week starting on the locale's first day.
                readonly property int firstWeekday: (displayedMonth.getDay() - bar.regionalLocale.firstDayOfWeek + 7) % 7
                readonly property int daysInMonth: new Date(displayedYear, displayedMonthNumber + 1, 0).getDate()
                readonly property int weekRows: Math.ceil((firstWeekday + daysInMonth) / 7)
                // Card height for the displayed month, measured from the real layout, and
                // eased when the next month has a week more or less.
                readonly property real contentHeight: calendarColumn.y + calendarBody.y + calendarBody.implicitHeight + 18
                property real animatedHeight: contentHeight
                readonly property int calendarWidth: 322
                readonly property int notificationWidth: 400
                // The notifications open beside the calendar while some are waiting.
                property real animatedWidth: notificationList.count > 0 ? calendarWidth + notificationWidth : calendarWidth
                property int pendingMonthDelta: 0

                function changeMonth(delta) {
                    if (monthTransition.running)
                        return ;

                    pendingMonthDelta = delta;
                    monthTransition.start();
                }

                pill: clockPill
                align: Qt.AlignHCenter
                closeDelay: 180
                cardHeight: animatedHeight
                cardWidth: animatedWidth
                anchor.edges: Edges.Top
                anchor.gravity: Edges.Bottom
                implicitWidth: calendarWidth + notificationWidth
                // Sized for a six-week month so the card can animate without clipping. Not taken
                // from weekRows: the layout updates a frame late, and the popup would resize twice
                // (everything shakes).
                implicitHeight: calendarColumn.y + calendarBody.y + calendarMonthLabel.implicitHeight + calendarBody.spacing + calendarGrid.sixWeekHeight + 18
                onOpening: monthOffset = 0
                // While it's open, new notifications land in it instead of popping out of
                // the island.
                onExpandedChanged: {
                    if (expanded) {
                        bar.shellState.notificationScreen = bar.screen;
                        bar.shellState.notificationCenterOpen = true;
                    } else if (bar.shellState.notificationScreen === bar.screen) {
                        bar.shellState.notificationCenterOpen = false;
                    }
                }

                Connections {
                    function onPanelRequestsChanged() {
                        calendarPopup.request(bar.shellState.requestedAction("notifications", bar.screen));

                    }

                    target: bar.shellState
                }

                Item {
                    id: expandedClockHeader

                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: clockPill.width
                    height: clockPill.height

                    // Starts where the time sits in the island, pushed left by the badge or
                    // the dots, and slides to the card's middle as it opens, then back.
                    Label {
                        readonly property real islandX: dateTimeLabel.parent.x + dateTimeLabel.x
                        readonly property real centerX: (parent.width - width) / 2

                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.round(islandX + (centerX - islandX) * calendarPopup.progress)
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
                    color: Theme.surface1
                    opacity: calendarPopup.expanded ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                // The calendar on the right, the notifications on its left.
                Item {
                    id: calendarColumn

                    anchors.top: calendarSeparator.bottom
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: calendarPopup.calendarWidth

                    // Scrolling over the calendar goes through the months.
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

                    IconText {
                        id: calendarDate

                        anchors.top: parent.top
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        icon: "󰃭"
                        text: bar.regionalLocale.toString(clock.date, bar.regionalLocale.dateFormat(Locale.LongFormat))
                        color: Theme.lavender
                        font.pixelSize: 15
                        opacity: calendarPopup.expanded ? 1 : 0

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
                        color: Theme.surface1
                        opacity: calendarPopup.expanded ? 1 : 0

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
                        opacity: (calendarPopup.expanded ? 1 : 0) * monthTransitionOpacity

                        Label {
                            id: calendarMonthLabel

                            Layout.alignment: Qt.AlignHCenter
                            text: bar.capitalized(bar.regionalLocale.standaloneMonthName(calendarPopup.displayedMonthNumber)) + " " + calendarPopup.displayedYear
                            color: Theme.mauve
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
                                // From the locale's first day, "Lun" rather than "lun.".
                                model: [0, 1, 2, 3, 4, 5, 6].map((offset) => {
                                    return bar.capitalized(bar.regionalLocale.dayName((bar.regionalLocale.firstDayOfWeek + offset) % 7, Locale.ShortFormat).replace(/\.$/, ""));
                                })

                                Label {
                                    required property string modelData

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 25
                                    text: modelData
                                    color: Theme.mauve
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
                                    color: isToday ? Theme.mauve : "transparent"

                                    Label {
                                        anchors.centerIn: parent
                                        text: parent.validDay ? parent.dayNumber : ""
                                        color: parent.isToday ? Theme.base : Theme.mauve
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

                }

                Rectangle {
                    anchors.top: calendarSeparator.bottom
                    anchors.bottom: parent.bottom
                    anchors.right: calendarColumn.left
                    anchors.topMargin: 14
                    anchors.bottomMargin: 18
                    width: 1
                    color: Theme.surface1
                    opacity: calendarPopup.expanded ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                NotificationList {
                    id: notificationList

                    anchors.top: calendarSeparator.bottom
                    anchors.bottom: parent.bottom
                    anchors.right: calendarColumn.left
                    anchors.topMargin: 12
                    anchors.bottomMargin: 18
                    anchors.rightMargin: 16
                    width: calendarPopup.notificationWidth - 32
                    notificationServer: bar.notificationServer
                    shown: calendarPopup.expanded
                    opacity: calendarPopup.expanded ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }

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

                Behavior on animatedHeight {
                    NumberAnimation {
                        duration: 280
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on animatedWidth {
                    NumberAnimation {
                        duration: 280
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

        RowLayout {
            id: rightGroup

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -(bar.implicitHeight - 50) / 2
            spacing: 9
            // When the control pill changes width, it reports its place before the row has
            // settled against the right edge, so report again once it has.
            onXChanged: controlPill.publishGeometry()
            onYChanged: controlPill.publishGeometry()

            DropInSlot {
                shown: Updates.count > 0

                Pill {
                    IconText {
                        icon: ""

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Updates.upgrade()
                        }

                        // Keeps the last count while the pill flies away.
                        Binding on text {
                            when: Updates.count > 0
                            value: String(Updates.count)
                            restoreMode: Binding.RestoreNone
                        }

                    }

                }

            }

            // The Spotify track's cover as a spinning record. Hover it to open the player.
            DropInSlot {
                shown: bar.spotifyPlayer !== null

                MusicPill {
                    id: musicPill

                    player: bar.spotifyPlayer
                    shellState: bar.shellState
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

                // Keeps the control center open, like its shortcut.
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: bar.shellState.requestPanel("controlcenter", "pin", bar.screen.name)
                }

                ControlStatus {
                    bar: bar
                    badgeColor: controlPill.baseColor
                    showsTrayAttention: true
                }

            }

        }

    }

    // The time recorded, for the island.
    Timer {
        interval: 1000
        running: bar.shellState.recording
        repeat: true
        triggeredOnStart: true
        onTriggered: bar.recordingElapsed = Math.max(0, Math.round((Date.now() - bar.shellState.recordingStarted) / 1000))
    }

    Connections {
        function onAirPodsOsdRequestsChanged() {
            const osd = bar.shellState.airPodsOsd;
            if (osd.screen === bar.screen.name)
                bar.showAirPodsOsd(osd);

        }

        target: bar.shellState
    }

    // The hardware's changes, in this screen's island too.
    Connections {
        function onCapsLockToggled(enabled) {
            bar.showStatusOsd("󰪛", "Caps Lock", enabled);
        }

        function onNumLockToggled(enabled) {
            bar.showStatusOsd("󰎤", "Num Lock", enabled);
        }

        function onTouchpadToggled(enabled) {
            bar.showStatusOsd("󰟸", "Touchpad", enabled);
        }

        function onBrightnessShown(percent) {
            bar.showStatusOsd(Icons.brightness(percent), "Brightness", percent > 0, percent, 100);
        }

        function onKeyboardBacklightShown(level, max) {
            bar.showStatusOsd("󰌌", "Keyboard light", level > 0, level, max);
        }

        target: Devices
    }

    PwObjectTracker {
        objects: bar.micSource !== null ? [bar.micSource] : []
    }

    PwObjectTracker {
        objects: bar.audioSink !== null ? [bar.audioSink] : []
    }

    Timer {
        id: volumeInitDelay

        interval: 600
        running: true
        onTriggered: bar.volumeInitialized = true
    }

    Timer {
        id: micInitDelay

        interval: 500
        running: true
        onTriggered: bar.micStateInitialized = true
    }

    Behavior on clockCenterOffset {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }

    }

    // The battery's alerts, from UPower's changes (no polling).
    Connections {
        function onPercentageChanged() {
            bar.updateBatteryAlert();
        }

        target: bar.battery
        // Already low when the shell starts.
        Component.onCompleted: Qt.callLater(bar.updateBatteryAlert)
    }

    Timer {
        running: true
        interval: 3000
        onTriggered: bar.powerEventsReady = true
    }

    // The time left as soon as it is known, then the usual moment to read it.
    Connections {
        function onBatteryEstimatingChanged() {
            if (!bar.batteryEstimating && bar.statusOsdVisible && bar.statusOsdLabel === "On battery") {
                statusOsdHideDelay.interval = 2500;
                statusOsdHideDelay.restart();
            }
        }

        target: bar
    }

    // UPower waits for a few readings first, so meanwhile the draw is read every second.
    Timer {
        running: bar.batteryEstimating
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: batteryDrawProcess.running = true
    }

    Process {
        id: batteryDrawProcess

        // Each battery's energy and draw (µWh and µW). Batteries that only report charge
        // and current get multiplied by their voltage. The draw may be negative.
        command: ["sh", "-c", batteryDrawProcess.script]
        readonly property string script: 'for dir in /sys/class/power_supply/*; do
[ "$(cat "$dir/type" 2>/dev/null)" = Battery ] || continue
[ "$(cat "$dir/scope" 2>/dev/null)" = Device ] && continue
if [ -r "$dir/energy_now" ]; then echo "$(cat "$dir/energy_now") $(cat "$dir/power_now" 2>/dev/null || echo 0)"
elif [ -r "$dir/charge_now" ]; then volts=$(cat "$dir/voltage_now" 2>/dev/null || echo 0); echo "$(($(cat "$dir/charge_now") / 1000 * volts / 1000)) $(($(cat "$dir/current_now" 2>/dev/null || echo 0) / 1000 * volts / 1000))"
fi
done'

        stdout: StdioCollector {
            onStreamFinished: {
                let energy = 0;
                let draw = 0;
                for (const line of text.trim().split("\n")) {
                    const values = line.split(" ").map(Number);
                    if (values.length === 2 && !isNaN(values[0]) && !isNaN(values[1])) {
                        energy += values[0];
                        draw += Math.abs(values[1]);
                    }
                }
                // Hours left, in seconds.
                if (energy > 0 && draw > 0)
                    bar.batteryDrawEstimate = energy / draw * 3600;

            }
        }

    }

    Connections {
        function onOnBatteryChanged() {
            bar.powerSourceChanged();
        }

        target: UPower
    }

    Connections {
        function onScreenshotTakenChanged() {
            const taken = bar.shellState.screenshotTaken;
            if (taken !== null && taken.screen === bar.screen.name)
                bar.showScreenshotOsd(taken);

        }

        target: bar.shellState
    }

    // Caffeine lives on the bar because the bar is always there, so it keeps hypridle at bay.
    IdleInhibitor {
        window: bar
        enabled: bar.shellState.caffeine
    }

}
