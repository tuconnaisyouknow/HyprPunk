import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.components
import qs.services
import qs.state
import qs.theme
import qs.windows

// The AirPods card that grows out of the island when you open the case or they
// connect, like on an iPhone. AirPods waiting to pair get a Connect button instead.
// It never takes the keyboard and folds away by itself, or once both pods are in.
// It waits while an island panel or the calendar has the island, and the notifications
// wait while it's out.
Card {
    id: popup

    required property var screen
    // Its screen's bar, whose island it grows out of.
    required property var bar
    // The island's card shape, shared with its other cards.
    required property Item islandFrame
    readonly property rect contentRect: islandFrame.contentRect(popup)
    property color base: Colors.base
    property color secondary: Colors.secondary
    property color primary: Colors.primary
    // BR/EDR address of the AirPods shown, and why: "lid", "connected", "pairing" or
    // "manual" (ipc).
    property string address: ""
    property string reason: ""
    readonly property var device: address !== "" ? AirPods.device(address) : null
    readonly property var candidate: AirPods.pairing !== null && AirPods.pairing.address === address ? AirPods.pairing : null
    readonly property bool pairingView: reason === "pairing" && candidate !== null
    readonly property var shownAirPods: pairingView ? candidate : device
    readonly property bool headphones: shownAirPods !== null && shownAirPods.kind === "headphones"
    // Apple's renders ({buds, case} paths), null for models without any or until downloaded.
    readonly property var images: shownAirPods !== null && shownAirPods.images ? shownAirPods.images : null
    // [{level, charging, label}] under the pods: one ring while both pods agree.
    readonly property var podBatteries: AirPods.podBatteries(device)
    // The case is left out while its battery is unknown (pods out of it, lid shut).
    readonly property bool caseShown: !headphones && images !== null && (pairingView || (device !== null && device["case"].level !== null))
    // Both pods worn: the card has done its job.
    readonly property bool worn: inEars(device)
    // No timeout while the case is open; both pods worn still fold it back (onWornChanged).
    readonly property bool held: (reason === "lid" || reason === "connected") && device !== null && device.lidOpen
    property real progress: opened ? 1 : 0
    // Out, from open() until folded back onto the island.
    readonly property bool shown: opened || progress > 0
    // Where the island is.
    readonly property var island: bar.islandPill
    // What's asked for, until the island is free to show it: {address, reason, at (ms),
    // waited}. It claims the island like a card that comes on its own (ScreenState).
    property var pending: null
    readonly property var screenState: ShellState.forScreen(screen)
    readonly property bool owns: screenState !== null && screenState.islandOwner === "airpods"

    function inEars(device) {
        return device !== null && device.kind === "buds" && device.left.inEar && device.right.inEar;
    }

    function open(address, reason) {
        pending = {
            "address": address,
            "reason": reason,
            "at": Date.now(),
            "waited": false
        };
        if (owns) {
            showPending();
            return ;
        }
        screenState?.claim("airpods", 3);
        // Not shown right away: something else holds the island.
        if (pending !== null)
            pending.waited = true;

    }

    // What was asked, once the island is free: unless it no longer matters after waiting
    // (the case shut, the pairing over, or a connection from a while ago).
    function showPending() {
        const asked = pending;
        pending = null;
        const device = asked !== null ? AirPods.device(asked.address) : null;
        const stillThere = asked !== null && (!asked.waited || (asked.reason === "pairing" ? AirPods.pairing !== null && AirPods.pairing.address === asked.address : asked.reason === "lid" ? device !== null && device.lidOpen : Date.now() - asked.at < 8000));
        if (!stillThere) {
            if (!opened)
                close();

            return ;
        }
        popup.address = asked.address;
        popup.reason = asked.reason;
        dismissDelay.interval = asked.reason === "pairing" ? 45000 : 8000;
        restartDismiss();
        opened = true;
    }

    // Folds back on its own after a while, unless held or under the pointer.
    function restartDismiss() {
        if (held || cardHover.hovered)
            dismissDelay.stop();
        else
            dismissDelay.restart();
    }

    // Folds back onto the island, and gives it back.
    function close() {
        dismissDelay.stop();
        pending = null;
        opened = false;
        screenState?.release("airpods");
    }

    // The cross and "Not now": AirPods in pairing mode stay quiet for a while.
    function dismiss() {
        if (pairingView)
            AirPods.ignore(address);

        close();
    }

    function pairingButtonText() {
        if (candidate.state === "pairing")
            return "Connecting…";

        return candidate.state === "failed" ? "Try again" : "Connect";
    }

    anchors.fill: parent
    cardWidth: 420
    cardHeight: layout.implicitHeight + 28 + 26
    // The island's corners: rounder ones would let the island's show under the card.
    openRadius: island.height / 2
    visible: shown
    pillName: "island"
    covering: shown
    cardRect: Qt.rect(card.x, card.y, card.width, card.height)
    cardRadius: card.radius
    // Given the island, or no longer: a panel or a prompt took it, and the card comes back
    // once they're done if it still matters then.
    onOwnsChanged: {
        if (owns) {
            showPending();
        } else if (opened) {
            dismissDelay.stop();
            opened = false;
            pending = {
                "address": address,
                "reason": reason,
                "at": Date.now(),
                "waited": true
            };
        }
    }
    Component.onDestruction: screenState?.release("airpods")
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
        ShellState.airPodsOsd = {
            "screen": screen.name,
            "image": images !== null ? images.buds : "",
            "level": left === null ? right : right === null ? left : Math.min(left, right),
            "charging": device.left.charging && device.right.charging
        };
        ShellState.airPodsOsdRequests += 1;
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

    Connections {
        function onPopupRequested(address, reason) {
            const focused = Hyprland.focusedMonitor;
            if (focused === null || focused.name !== popup.screen.name)
                return ;

            // They connected because they went in your ears: nothing to show, unless asked for ("manual").
            if ((reason === "lid" || reason === "connected") && popup.inEars(AirPods.device(address)))
                return ;

            popup.open(address, reason);
        }

        function onLidClosed(address) {
            if (popup.pending !== null && popup.pending.address === address && !popup.opened)
                popup.close();

            if (popup.opened && popup.address === address && (popup.reason === "lid" || popup.reason === "connected"))
                popup.close();

        }

        target: AirPods
    }

    ClippingRectangle {
        id: card

        // Drawn in the island's shape (IslandFrame), shared with its other cards.
        x: popup.contentRect.x
        y: popup.contentRect.y
        width: popup.contentRect.width
        height: popup.contentRect.height
        radius: popup.islandFrame.shape.radius
        color: "transparent"

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
                    color: popup.primary
                    font.family: Metrics.font
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
                    onClicked: AirPods.pair(popup.address)
                }

                Text {
                    visible: popup.pairingView
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 10
                    text: "Not now"
                    color: notNowArea.containsMouse ? popup.primary : popup.secondary
                    font.family: Metrics.font
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
                    color: closeArea.containsMouse ? popup.primary : popup.secondary
                    font.family: Metrics.font
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

    Behavior on progress {
        NumberAnimation {
            duration: Motion.resize.large.duration
            easing.type: Easing.OutCubic
        }

    }

    Behavior on cardHeight {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }

    }

    // Accent glass button, like the notification actions.
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
            backgroundColor: Colors.alpha(Colors.primary, buttonArea.containsMouse ? 0.95 : 0.8)
        }

        Text {
            anchors.centerIn: parent
            text: button.text
            color: popup.base
            font.family: Metrics.font
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
