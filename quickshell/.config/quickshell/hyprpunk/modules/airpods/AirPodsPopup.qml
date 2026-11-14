import QtQuick
import QtQuick.Layouts
import Quickshell
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
    readonly property bool worn: AirPods.inEars(device)
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
    cardHeight: layout.implicitHeight + 2 * Metrics.spacing.section
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
        Osd.showAirPods(Object.assign({
            "screen": screen.name,
            "image": images !== null ? images.buds : ""
        }, AirPods.budsBattery(device)));
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
        // On the screen you're on.
        function onPopupRequested(address, reason) {
            if (ShellState.focused() === popup.screenState)
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
                anchors.topMargin: Metrics.spacing.section
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 2 * Metrics.spacing.section
                spacing: 0

                Text {
                    // Clear of the cross on both sides, so it stays centred.
                    Layout.fillWidth: true
                    Layout.leftMargin: Metrics.spacing.section
                    Layout.rightMargin: Metrics.spacing.section
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    lineHeight: 0.95
                    text: popup.shownAirPods !== null ? popup.shownAirPods.name : ""
                    color: Colors.primary
                    font.family: Metrics.font
                    font.pixelSize: Metrics.text.heading
                    font.weight: Font.Bold
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Metrics.spacing.section
                    spacing: Metrics.spacing.section

                    // The pods (or the headphones), their rings below.
                    ColumnLayout {
                        Layout.alignment: Qt.AlignTop
                        spacing: Metrics.spacing.huge

                        AirPodsImage {
                            source: popup.images !== null ? "file://" + popup.images.buds : ""
                            glyph: popup.headphones ? "󰋋" : "󱡏"
                        }

                        Row {
                            visible: !popup.pairingView
                            Layout.alignment: Qt.AlignHCenter
                            spacing: Metrics.spacing.huge

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
                        spacing: Metrics.spacing.huge

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

                GlassButton {
                    visible: popup.pairingView
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 240
                    Layout.topMargin: Metrics.spacing.section
                    label: popup.pairingView ? popup.pairingButtonText() : ""
                    enabled: popup.pairingView && popup.candidate.state !== "pairing"
                    onClicked: AirPods.pair(popup.address)
                }

                Text {
                    visible: popup.pairingView
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Metrics.spacing.normal
                    text: "Not now"
                    color: notNowArea.containsMouse ? Colors.primary : Colors.secondary
                    font.family: Metrics.font
                    font.pixelSize: Metrics.text.body

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

            // Closes the card.
            IconButton {
                icon: ""
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Metrics.spacing.normal
                onClicked: popup.dismiss()
            }

            Behavior on opacity {
                Anim {
                    token: Motion.color.small
                }

            }

        }

    }

    Timer {
        id: dismissDelay

        onTriggered: popup.close()
    }

    Behavior on progress {
        Anim {
            token: Motion.resize.large
        }

    }

    Behavior on cardHeight {
        Anim {
            token: Motion.resize.normal
        }

    }

}
