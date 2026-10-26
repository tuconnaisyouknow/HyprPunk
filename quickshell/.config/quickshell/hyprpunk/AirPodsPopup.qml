import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

// AirPods card growing out of the dynamic island, laid out like the iPhone's: the
// name, the pods and their case, a battery ring under each when their case opens or
// they connect, a Connect button instead for AirPods in pairing mode next to the
// computer. It folds back once both pods are in the ears. It never takes the keyboard, clicks around it go through,
// and it folds back on its own.
PanelWindow {
    id: popup

    required property var shellState
    required property var airPods
    property color base: "#1e1e2e"
    property color overlay1: "#7f849c"
    property color textColor: "#cdd6f4"
    property color mauve: "#cba6f7"
    property color red: "#f38ba8"
    property color green: "#a6e3a1"
    // BR/EDR address of the AirPods shown, and why: "lid", "connected", "pairing" or
    // "manual" (ipc).
    property string address: ""
    property string reason: ""
    readonly property var device: address !== "" ? airPods.device(address) : null
    readonly property var candidate: airPods.pairing !== null && airPods.pairing.address === address ? airPods.pairing : null
    readonly property bool pairingView: reason === "pairing" && candidate !== null
    readonly property var shownAirPods: pairingView ? candidate : device
    readonly property bool headphones: shownAirPods !== null && shownAirPods.kind === "headphones"
    // Apple's renders ({buds, case} paths), null for models without any or until downloaded.
    readonly property var images: shownAirPods !== null && shownAirPods.images ? shownAirPods.images : null
    // [{level, charging, label}] under the pods: one ring while both pods agree.
    readonly property var podBatteries: {
        if (device === null)
            return [];

        if (headphones)
            return [device.headset];

        const left = device.left;
        const right = device.right;
        if (left.level === null && right.level === null)
            return [left];

        if (right.level === null || (left.level === right.level && left.charging === right.charging))
            return [Object.assign({
                "label": right.level === null ? "L" : ""
            }, left)];

        if (left.level === null)
            return [Object.assign({
                "label": "R"
            }, right)];

        return [Object.assign({
            "label": "L"
        }, left), Object.assign({
            "label": "R"
        }, right)];
    }
    // The case is left out while its battery is unknown (pods out of it, lid shut).
    readonly property bool caseShown: !headphones && images !== null && (pairingView || (device !== null && device["case"].level !== null))
    // Both pods worn: the card has done its job.
    readonly property bool worn: inEars(device)
    // No timeout while the case is open; both pods worn still fold it back (onWornChanged).
    readonly property bool held: (reason === "lid" || reason === "connected") && device !== null && device.lidOpen
    property real cardWidth: 420
    property real cardHeight: layout.implicitHeight + 28 + 26
    property bool shown: false
    property bool opened: false
    // Set while the window is mapping: the card only grows once its first frame is on screen.
    property bool openPending: false
    property real progress: opened ? 1 : 0
    readonly property var island: shellState.islandPill

    function lerp(from, to) {
        return from + (to - from) * progress;
    }

    function inEars(airPods) {
        return airPods !== null && airPods.kind === "buds" && airPods.left.inEar && airPods.right.inEar;
    }

    function open(address, reason) {
        popup.address = address;
        popup.reason = reason;
        hideDelay.stop();
        dismissDelay.interval = reason === "pairing" ? 45000 : 8000;
        restartDismiss();

        if (shown) {
            opened = true;
        } else {
            openPending = true;
            shown = true;
        }
    }

    // Folds back on its own after a while, unless held or under the pointer.
    function restartDismiss() {
        if (held || cardHover.hovered)
            dismissDelay.stop();
        else
            dismissDelay.restart();
    }

    function close() {
        dismissDelay.stop();
        openPending = false;
        opened = false;
        hideDelay.restart();
    }

    // The cross and "Not now": AirPods in pairing mode stay quiet for a while.
    function dismiss() {
        if (pairingView)
            airPods.ignore(address);

        close();
    }

    function pairingButtonText() {
        if (candidate.state === "pairing")
            return "Connecting…";

        return candidate.state === "failed" ? "Try again" : "Connect";
    }

    visible: shown
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hyprpunk-island"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    onHeldChanged: {
        if (opened)
            restartDismiss();

    }
    onWornChanged: {
        if (!worn || !opened || pairingView)
            return ;

        // The island turns into the AirPods OSD and the card folds back onto it.
        const left = device.left.level;
        const right = device.right.level;
        shellState.airPodsOsd = {
            "screen": screen.name,
            "image": images !== null ? images.buds : "",
            "level": left === null ? right : right === null ? left : Math.min(left, right),
            "charging": device.left.charging && device.right.charging
        };
        shellState.airPodsOsdRequests += 1;
        close();
    }
    // Paired: the card of the AirPods follows. Ignored or gone: nothing left to show.
    onCandidateChanged: {
        if (candidate !== null || reason !== "pairing" || !opened)
            return ;

        if (device !== null)
            reason = "connected";
        else
            close();
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Connections {
        function onPopupRequested(address, reason) {
            const focused = Hyprland.focusedMonitor;
            if (focused === null || focused.name !== popup.screen.name)
                return ;

            // Connected once in the ears: nothing to show (but on request, "manual").
            if ((reason === "lid" || reason === "connected") && popup.inEars(popup.airPods.device(address)))
                return ;

            popup.open(address, reason);
        }

        function onLidClosed(address) {
            if (popup.opened && popup.address === address && (popup.reason === "lid" || popup.reason === "connected"))
                popup.close();

        }

        target: popup.airPods
    }

    Connections {
        function onFrameSwapped() {
            if (popup.openPending) {
                popup.opened = true;
                popup.openPending = false;
            }
        }

        target: card.Window.window
    }

    ClippingRectangle {
        id: card

        x: popup.width / 2 + popup.island.centerOffset - width / 2
        y: popup.island.top
        width: popup.lerp(popup.island.width, popup.cardWidth)
        height: popup.lerp(popup.island.height, popup.cardHeight)
        // The island's corners: rounder ones would let the island's show under the card.
        radius: popup.island.height / 2
        color: "transparent"

        // Same card as the island panels and the pills: base at 0.9, blurred
        // by the hyprpunk-island layer rule, with the glass rim.
        GlassSurface {
            radius: card.radius
            tinted: false
            backgroundColor: Qt.rgba(30 / 255, 30 / 255, 46 / 255, 0.9)
        }

        HoverHandler {
            id: cardHover

            onHoveredChanged: {
                if (popup.opened)
                    popup.restartDismiss();

            }
        }

        // Laid out at full size, only uncovered while the card grows.
        Item {
            id: contentArea

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: popup.cardWidth
            height: popup.cardHeight
            opacity: popup.opened ? 1 : 0

            ColumnLayout {
                id: layout

                anchors.top: parent.top
                anchors.topMargin: 28
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 48
                spacing: 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 300
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    lineHeight: 0.95
                    text: popup.shownAirPods !== null ? popup.shownAirPods.name : ""
                    color: popup.textColor
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 24
                    font.weight: Font.Bold
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 22
                    spacing: 36

                    // The pods (or the headphones), their rings below.
                    ColumnLayout {
                        Layout.alignment: Qt.AlignTop
                        spacing: 16

                        AirPodsImage {
                            source: popup.images !== null ? "file://" + popup.images.buds : ""
                            glyph: popup.headphones ? "󰋋" : "󱡏"
                        }

                        Row {
                            visible: !popup.pairingView
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 18

                            Repeater {
                                model: popup.podBatteries

                                BatteryRing {
                                    required property var modelData

                                    battery: modelData
                                }

                            }

                        }

                    }

                    ColumnLayout {
                        visible: popup.caseShown
                        Layout.alignment: Qt.AlignTop
                        spacing: 16

                        AirPodsImage {
                            source: popup.images !== null ? "file://" + popup.images["case"] : ""
                        }

                        BatteryRing {
                            visible: !popup.pairingView
                            Layout.alignment: Qt.AlignHCenter
                            battery: popup.device !== null ? popup.device["case"] : null
                        }

                    }

                }

                CardButton {
                    visible: popup.pairingView
                    Layout.topMargin: 22
                    text: popup.pairingView ? popup.pairingButtonText() : ""
                    enabled: popup.pairingView && popup.candidate.state !== "pairing"
                    onClicked: popup.airPods.pair(popup.address)
                }

                Text {
                    visible: popup.pairingView
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 10
                    text: "Not now"
                    color: notNowArea.containsMouse ? popup.textColor : popup.overlay1
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12

                    MouseArea {
                        id: notNowArea

                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.dismiss()
                    }

                }

            }

            // Small neutral close cross in the top-right corner, as on the notifications.
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 14
                width: 22
                height: 22
                radius: 11
                color: "transparent"

                // Glass halo on hover only, so the cross stays discreet.
                GlassSurface {
                    radius: parent.radius
                    hovered: true
                    opacity: closeArea.containsMouse ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                        }

                    }

                }

                Text {
                    anchors.centerIn: parent
                    text: ""
                    color: closeArea.containsMouse ? popup.mauve : popup.overlay1
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                }

                MouseArea {
                    id: closeArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: popup.dismiss()
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

    Timer {
        id: dismissDelay

        onTriggered: popup.close()
    }

    Timer {
        id: hideDelay

        // Lets the card fold back onto the island first.
        interval: 320
        onTriggered: popup.shown = false
    }

    mask: Region {
        item: card
    }

    Behavior on progress {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }

    }

    Behavior on cardHeight {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }

    }

    // Battery ring: a bolt inside while charging, else the pod's letter, the level below.
    component BatteryRing: Column {
        id: ring

        // {level, charging, label}, level 0-100 or null when unknown.
        property var battery: null
        readonly property var level: battery !== null ? battery.level : null
        readonly property bool charging: battery !== null && battery.charging
        readonly property bool low: level !== null && level <= 20 && !charging

        spacing: 6

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 40
            height: 40

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: Qt.rgba(69 / 255, 71 / 255, 90 / 255, 0.8)
                    strokeWidth: 4
                    fillColor: "transparent"

                    PathAngleArc {
                        centerX: 20
                        centerY: 20
                        radiusX: 18
                        radiusY: 18
                        startAngle: 0
                        sweepAngle: 360
                    }

                }

                ShapePath {
                    strokeColor: ring.low ? popup.red : popup.green
                    strokeWidth: 4
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap

                    PathAngleArc {
                        centerX: 20
                        centerY: 20
                        radiusX: 18
                        radiusY: 18
                        startAngle: -90
                        sweepAngle: ring.level === null ? 0 : 3.6 * ring.level

                        Behavior on sweepAngle {
                            NumberAnimation {
                                duration: 450
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                }

            }

            Text {
                anchors.centerIn: parent
                text: ring.charging ? "󱐋" : ring.battery !== null && ring.battery.label ? ring.battery.label : ""
                color: ring.charging ? popup.green : popup.textColor
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: ring.charging ? 17 : 13
                font.weight: Font.Bold
            }

        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ring.level === null ? "--" : ring.level + "%"
            color: ring.low ? popup.red : popup.textColor
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 17
            font.weight: Font.Medium
        }

    }

    // Mauve glass button, like the notification actions.
    component CardButton: Rectangle {
        id: button

        property string text

        signal clicked()

        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 240
        implicitHeight: 38
        radius: 12
        color: "transparent"
        opacity: enabled ? 1 : 0.6

        GlassSurface {
            radius: button.radius
            hovered: buttonArea.containsMouse
            backgroundColor: Qt.rgba(203 / 255, 166 / 255, 247 / 255, buttonArea.containsMouse ? 0.95 : 0.8)
        }

        Text {
            anchors.centerIn: parent
            text: button.text
            color: popup.base
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            font.weight: Font.Bold
        }

        MouseArea {
            id: buttonArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: button.enabled
            onClicked: button.clicked()
        }

    }

}
