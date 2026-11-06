import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

// The AirPods card that grows out of the island when you open the case or they
// connect, like on an iPhone. AirPods waiting to pair get a Connect button instead.
// It never takes the keyboard and folds away by itself, or once both pods are in.
// It waits while an island panel or the calendar has the island, and the notifications
// wait while it's out.
Card {
    id: popup

    required property var screen
    required property var shellState
    // Its screen's bar, whose island it grows out of.
    required property var bar
    // The island's card shape, shared with its other cards.
    required property Item islandFrame
    readonly property rect contentRect: islandFrame.contentRect(popup)
    required property var airPods
    property color base: Theme.base
    property color lavender: Theme.lavender
    property color mauve: Theme.mauve
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
    readonly property var podBatteries: airPods.podBatteries(device)
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
    // Asked for while the island was taken: {address, reason, at (ms)}, shown once it's
    // free if it still matters.
    property var pending: null
    readonly property string islandKey: "airpods@" + screen.name
    readonly property bool islandTaken: shellState.islandPanels.some((key) => {
        return key !== islandKey && key.endsWith("@" + screen.name);
    })

    function inEars(airPods) {
        return airPods !== null && airPods.kind === "buds" && airPods.left.inEar && airPods.right.inEar;
    }

    function open(address, reason) {
        if (islandTaken) {
            pending = {
                "address": address,
                "reason": reason,
                "at": Date.now()
            };
            return ;
        }
        pending = null;
        popup.address = address;
        popup.reason = reason;
        dismissDelay.interval = reason === "pairing" ? 45000 : 8000;
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

    // Folds back onto the island.
    function close() {
        dismissDelay.stop();
        opened = false;
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
    // Free again: what was asked meanwhile, unless it no longer matters (the case shut,
    // the pairing over, or a connection from a while ago).
    onIslandTakenChanged: {
        if (islandTaken || pending === null)
            return ;

        const asked = pending;
        pending = null;
        const device = airPods.device(asked.address);
        const stillThere = asked.reason === "pairing" ? airPods.pairing !== null && airPods.pairing.address === asked.address : asked.reason === "lid" ? device !== null && device.lidOpen : Date.now() - asked.at < 8000;
        if (stillThere)
            open(asked.address, asked.reason);

    }
    // The notifications wait while it's open.
    onOpenedChanged: {
        const others = shellState.islandPanels.filter((item) => {
            return item !== islandKey;
        });
        shellState.islandPanels = opened ? others.concat([islandKey]) : others;
    }
    Component.onDestruction: {
        if (opened)
            shellState.islandPanels = shellState.islandPanels.filter((item) => {
            return item !== islandKey;
        });

    }
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


    Connections {
        function onPopupRequested(address, reason) {
            const focused = Hyprland.focusedMonitor;
            if (focused === null || focused.name !== popup.screen.name)
                return ;

            // They connected because they went in your ears: nothing to show, unless asked for ("manual").
            if ((reason === "lid" || reason === "connected") && popup.inEars(popup.airPods.device(address)))
                return ;

            popup.open(address, reason);
        }

        function onLidClosed(address) {
            if (popup.pending !== null && popup.pending.address === address)
                popup.pending = null;

            if (popup.opened && popup.address === address && (popup.reason === "lid" || popup.reason === "connected"))
                popup.close();

        }

        target: popup.airPods
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
                    color: popup.mauve
                    font.family: Theme.font
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
                    color: notNowArea.containsMouse ? popup.mauve : popup.lavender
                    font.family: Theme.font
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
                    color: closeArea.containsMouse ? popup.mauve : popup.lavender
                    font.family: Theme.font
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
            duration: Theme.cardFold
            easing.type: Easing.OutCubic
        }

    }

    Behavior on cardHeight {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
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
            backgroundColor: Theme.alpha(Theme.mauve, buttonArea.containsMouse ? 0.95 : 0.8)
        }

        Text {
            anchors.centerIn: parent
            text: button.text
            color: popup.base
            font.family: Theme.font
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
