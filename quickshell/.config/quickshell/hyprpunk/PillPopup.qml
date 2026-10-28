import QtQuick
import Quickshell
import Quickshell.Widgets

// A card that grows out of one of the bar's pills while you hover it: the workspace
// preview, the system monitor, the calendar and the player. Resting on the pill a
// moment opens it, and leaving both the pill and the card folds it back.
// Its content is laid out at full size and uncovered as the card grows.
PopupWindow {
    id: popup

    // The pill it grows from, with the same corners so the pill itself seems to grow.
    required property Item pill
    // The open card's height, the window's by default. Animate it on your side if it
    // changes while open (a calendar month with one more week).
    property real cardHeight: height
    // The side of the pill the card lines up with: Qt.AlignLeft, Qt.AlignRight or
    // Qt.AlignHCenter. Set the anchor's edges and gravity to match.
    property int align: Qt.AlignLeft
    // How long the pointer rests on the pill before the card opens, so sweeping across
    // the bar on the way to something else doesn't flash cards everywhere.
    property int openDelay: 350
    property int closeDelay: 220
    // False hides it (no player anymore).
    property bool available: true
    // Checked when the delay is up: false and it doesn't open after all (the pointer
    // left the workspace it was resting on).
    property bool openable: true
    // Unfolded, or unfolding.
    property bool expanded: false
    // On screen, also while it folds back.
    property bool mapped: false
    // Set while the window maps: the card only grows once its first frame is on screen.
    property bool openPending: false
    // 0 folded on the pill, 1 fully open.
    property real progress: expanded ? 1 : 0
    readonly property bool cardHovered: cardHover.hovered
    readonly property alias card: card
    default property alias content: card.data

    // Right before the window maps, to set the content up.
    signal opening()

    function lerp(from, to) {
        return from + (to - from) * progress;
    }

    // The pointer is on the pill (or on what opens the card).
    function hoverStarted() {
        closeTimer.stop();
        hideTimer.stop();
        if (mapped)
            expanded = true;
        else
            openTimer.restart();
    }

    function hoverEnded() {
        openTimer.stop();
        closeTimer.restart();
    }

    // Not opening after all, without closing what's open.
    function cancelOpen() {
        openTimer.stop();
    }

    function open() {
        closeTimer.stop();
        hideTimer.stop();
        opening();
        openPending = true;
        mapped = true;
    }

    function close() {
        openPending = false;
        expanded = false;
        hideTimer.restart();
    }

    // Gone at once without folding back, when the island needs the room for an OSD.
    function dismiss() {
        openTimer.stop();
        closeTimer.stop();
        hideTimer.stop();
        openPending = false;
        expanded = false;
        mapped = false;
    }

    visible: mapped && available
    color: "transparent"
    grabFocus: false
    anchor.item: pill
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.SlideX

    Connections {
        function onFrameSwapped() {
            if (popup.openPending) {
                popup.openPending = false;
                popup.expanded = true;
            }
        }

        target: card.Window.window
    }

    // The anchor is only worked out on opening: follow the pill when it moves or
    // resizes, or when the pills before it change width.
    Connections {
        function onXChanged() {
            popup.anchor.updateAnchor();
        }

        function onYChanged() {
            popup.anchor.updateAnchor();
        }

        function onWidthChanged() {
            popup.anchor.updateAnchor();
        }

        target: popup.pill
    }

    Connections {
        function onXChanged() {
            popup.anchor.updateAnchor();
        }

        function onYChanged() {
            popup.anchor.updateAnchor();
        }

        target: popup.pill.parent
    }

    Timer {
        id: openTimer

        interval: popup.openDelay
        onTriggered: {
            if (popup.available && popup.openable)
                popup.open();

        }
    }

    Timer {
        id: closeTimer

        interval: popup.closeDelay
        onTriggered: popup.close()
    }

    Timer {
        id: hideTimer

        // Lets the card fold back onto the pill first.
        interval: 320
        onTriggered: popup.mapped = false
    }

    ClippingRectangle {
        id: card

        // Centered on a whole pixel, as anchors do: half pixels while the width grows
        // make the card and everything in it shake.
        x: popup.align === Qt.AlignRight ? popup.width - width : popup.align === Qt.AlignHCenter ? Math.round((popup.width - width) / 2) : 0
        width: popup.lerp(popup.pill.width, popup.width)
        height: popup.lerp(popup.pill.height, popup.cardHeight)
        // The pill's corners: rounder ones would let the pill's show under the card.
        radius: popup.pill.radius
        color: "transparent"

        GlassSurface {
            radius: card.radius
            tinted: false
            backgroundColor: Theme.panel
        }

        HoverHandler {
            id: cardHover

            onHoveredChanged: {
                if (hovered) {
                    closeTimer.stop();
                    hideTimer.stop();
                    popup.expanded = true;
                } else {
                    closeTimer.restart();
                }
            }
        }

    }

    Behavior on progress {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }

    }

    mask: Region {
        item: card
    }

}
