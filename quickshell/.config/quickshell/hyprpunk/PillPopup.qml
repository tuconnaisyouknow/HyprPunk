import QtQuick
import Quickshell
import Quickshell.Widgets

// A card that grows out of one of the bar's pills while you hover it: the workspace
// preview, the system monitor, the calendar and the player. Resting on the pill a
// moment opens it, and leaving both the pill and the card folds it back.
// Its content is laid out at full size and uncovered as the card grows. A click on the
// pill, even once the card covers it, keeps it open until Escape, a click outside or
// another click on the pill.
PopupWindow {
    id: popup

    // The pill it grows from, with the same corners so the pill itself seems to grow.
    required property Item pill
    // The open card's height, the window's by default. Animate it on your side if it
    // changes while open (a calendar month with one more week).
    property real cardHeight: height
    // The open card's width, the window's by default. The window stays at its widest and
    // the card eases inside it, since resizing the window as it animates shakes everything.
    property real cardWidth: width
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
    // Opened on purpose (a shortcut, a click) rather than by hovering: it stays open when
    // the pointer leaves, until closed.
    property bool pinned: false
    // Closed while kept open, until it has folded back: the pointer resting on the card
    // or the pill doesn't open it again as if hovered (the click catcher going away
    // makes the pointer come back to it).
    property bool closedOnPurpose: false
    // 0 folded on the pill, 1 fully open.
    property real progress: expanded ? 1 : 0
    readonly property bool cardHovered: cardHover.hovered
    readonly property alias card: card
    default property alias content: card.data

    // Right before the window maps, to set the content up.
    signal opening()
    // A key other than Escape while it's kept open, for a card that answers the keyboard.
    signal keyPressed(int key)

    function lerp(from, to) {
        return from + (to - from) * progress;
    }

    // The pointer is on the pill (or on what opens the card).
    function hoverStarted() {
        if (closedOnPurpose)
            return ;

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

    // What its shortcut asks ("toggle", "open" or "close"). Open, however it was opened
    // (a click, the pointer, the shortcut), the shortcut closes it; closed, it opens it kept.
    function request(action) {
        if (action === "close" || action === "toggle" && expanded) {
            if (!expanded)
                return ;

            close();
            // Even opened by the pointer, which still rests on it.
            closedOnPurpose = true;
        } else if (action === "open" || action === "toggle") {
            if (!(pinned && expanded))
                togglePinned();

        }
    }

    // Kept open, or closed once kept (a click on the pill).
    function togglePinned() {
        if (pinned && expanded) {
            close();
            return ;
        }
        pinned = true;
        closedOnPurpose = false;
        closeTimer.stop();
        hideTimer.stop();
        if (mapped)
            expanded = true;
        else
            open();
    }

    // Not opening after all, without closing what's open.
    function cancelOpen() {
        openTimer.stop();
    }

    function open() {
        closedOnPurpose = false;
        closeTimer.stop();
        hideTimer.stop();
        opening();
        openPending = true;
        mapped = true;
    }

    function close() {
        closedOnPurpose = pinned;
        pinned = false;
        openPending = false;
        expanded = false;
        hideTimer.restart();
    }

    // Gone at once without folding back, when the island needs the room for an OSD.
    function dismiss() {
        pinned = false;
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

    // While it's kept open, a click anywhere else or Escape closes it. The card can't
    // take the keyboard itself, being a popup of the bar.
    OutsideClick {
        screen: popup.pill.QsWindow.window ? popup.pill.QsWindow.window.screen : null
        active: popup.pinned && popup.expanded
        takesKeyboard: true
        onDismissed: popup.close()
        onKeyPressed: (key) => {
            return popup.keyPressed(key);
        }
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
        onTriggered: {
            if (!popup.pinned)
                popup.close();

        }
    }

    Timer {
        id: hideTimer

        // Lets the card fold back onto the pill first.
        interval: 320
        onTriggered: {
            popup.mapped = false;
            popup.closedOnPurpose = false;
        }
    }

    ClippingRectangle {
        id: card

        // Centered on a whole pixel, as anchors do: half pixels while the width grows
        // make the card and everything in it shake.
        x: popup.align === Qt.AlignRight ? popup.width - width : popup.align === Qt.AlignHCenter ? Math.round((popup.width - width) / 2) : 0
        width: popup.lerp(popup.pill.width, popup.cardWidth)
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
                if (popup.closedOnPurpose)
                    return ;

                if (hovered) {
                    closeTimer.stop();
                    hideTimer.stop();
                    popup.expanded = true;
                } else {
                    closeTimer.restart();
                }
            }
        }

        // Over the content, only watching: the card covers the pill once open, so a click
        // on the pill's spot still keeps it open, or closes it once kept. The content's
        // own buttons still get their clicks, which leave the card as it is.
        Item {
            id: clickWatch

            anchors.fill: parent
            z: 1000

            // Where the pill sits under the card.
            Item {
                id: pillSpot

                x: popup.align === Qt.AlignRight ? parent.width - width : popup.align === Qt.AlignHCenter ? Math.round((parent.width - width) / 2) : 0
                width: popup.pill.width
                height: popup.pill.height

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

            }

            PointHandler {
                acceptedButtons: Qt.LeftButton
                onActiveChanged: {
                    if (!active)
                        return ;

                    const at = point.pressPosition;
                    const onPill = at.x >= pillSpot.x && at.x < pillSpot.x + pillSpot.width && at.y < pillSpot.height;
                    if (onPill)
                        popup.togglePinned();

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
