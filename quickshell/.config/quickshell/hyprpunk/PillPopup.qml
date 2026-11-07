import QtQuick
import Quickshell.Widgets

// A card that grows out of one of the bar's pills while you hover it: the workspace
// preview, the system monitor, the calendar and the player. Resting on the pill a
// moment opens it, and leaving both the pill and the card folds it back.
// Its content is laid out at full size and uncovered as the card grows. A click on the
// pill, even once the card covers it, keeps it open until Escape, a click outside or
// another click on the pill.
Card {
    id: popup

    required property var shellState
    // Where the screen draws its cards (ScreenShell).
    required property Item cardLayer
    // The pill it grows from, with the same corners so the pill itself seems to grow.
    required property Item pill
    // The shape it shares with the other cards of its pill (IslandFrame, for the
    // calendar), drawn in instead of its own.
    property Item frame: null
    readonly property rect frameContent: frame !== null ? frame.contentRect(popup) : Qt.rect(0, 0, 0, 0)
    // The side of the pill the card lines up with: Qt.AlignLeft, Qt.AlignRight or
    // Qt.AlignHCenter.
    property int align: Qt.AlignLeft
    // How long the pointer rests on the pill before the card opens, and how long the card
    // waits once it has left, the same for every card (Theme).
    property int openDelay: Theme.cardOpenDelay
    property int closeDelay: Theme.cardCloseDelay
    // False hides it (no player anymore).
    property bool available: true
    // Checked when the delay is up: false and it doesn't open after all (the pointer
    // left the workspace it was resting on).
    property bool openable: true
    // True and it doesn't open at all, however asked (a prompt holds the island).
    property bool blocked: false
    // Unfolded, or unfolding.
    property bool expanded: false
    // Out, from the opening until folded back.
    readonly property bool mapped: expanded || progress > 0
    // Opened on purpose (a shortcut, a click) rather than by hovering: it stays open when
    // the pointer leaves, until closed.
    property bool pinned: false
    // Closed while kept open, until it has folded back: the pointer resting on the card
    // or the pill doesn't open it again as if hovered.
    property bool closedOnPurpose: false
    // 0 folded on the pill, 1 fully open.
    property real progress: expanded ? 1 : 0
    readonly property bool cardHovered: cardHover.hovered
    property bool pillHovered: false
    // It stays while the pointer is on the pill or on the card. The card opens over the
    // pill, so the pointer enters one as it leaves the other, in either order: only
    // leaving both folds it back.
    readonly property bool pointerInside: pillHovered || cardHovered
    readonly property alias card: card
    default property alias content: card.data

    // Right before it opens, to set the content up.
    signal opening()
    // A key other than Escape while it's kept open, for a card that answers the keyboard.
    signal keyPressed(int key)

    function lerp(from, to) {
        return from + (to - from) * progress;
    }

    // The pointer is on the pill (or on what opens the card).
    function hoverStarted() {
        pillHovered = true;
        if (closedOnPurpose)
            return ;

        if (mapped)
            expanded = true;
        else
            openTimer.restart();
    }

    function hoverEnded() {
        pillHovered = false;
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
        if (blocked)
            return ;

        pinned = true;
        closedOnPurpose = false;
        closeTimer.stop();
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
        if (blocked) {
            pinned = false;
            return ;
        }
        closedOnPurpose = false;
        closeTimer.stop();
        opening();
        followPill();
        expanded = true;
    }

    // Folds back onto the pill.
    function close() {
        closedOnPurpose = pinned;
        pinned = false;
        expanded = false;
    }

    function clickedOutside() {
        close();
    }

    // Hangs from the pill, kept on the screen.
    function followPill() {
        // Still being set up.
        if (pill === null || cardLayer === null)
            return ;

        const origin = pill.mapToItem(cardLayer, 0, 0);
        const left = align === Qt.AlignRight ? origin.x + pill.width - width : align === Qt.AlignHCenter ? origin.x + (pill.width - width) / 2 : origin.x;
        x = Math.round(Math.max(0, Math.min(cardLayer.width - width, left)));
        y = Math.round(origin.y);
    }

    parent: cardLayer
    opened: expanded
    // The open card's size, the full size by default. Animate it on your side if it
    // changes while open (a calendar month with one more week). The room the card needs
    // stays at its widest and the card eases inside it.
    cardWidth: width
    cardHeight: height
    // The pill's corners: rounder ones would let the pill's show under the card.
    openRadius: pill.radius
    width: implicitWidth
    height: implicitHeight
    visible: mapped && available
    covering: visible
    cardRect: Qt.rect(x + card.x, y + card.y, card.width, card.height)
    cardRadius: card.radius
    takesKeyboard: pinned && visible
    dismissable: pinned && visible
    onMappedChanged: {
        if (!mapped)
            closedOnPurpose = false;

    }
    onPointerInsideChanged: {
        if (pointerInside) {
            closeTimer.stop();
        } else {
            openTimer.stop();
            closeTimer.restart();
        }
    }
    // Kept open: Escape closes it, and the card's own keys reach it.
    onPinnedChanged: {
        if (pinned)
            keys.forceActiveFocus();

    }
    onWidthChanged: followPill()

    Connections {
        function onWidthChanged() {
            popup.followPill();
        }

        target: popup.cardLayer
    }

    // The pill moves, or the pills before it change width.
    Connections {
        function onXChanged() {
            popup.followPill();
        }

        function onYChanged() {
            popup.followPill();
        }

        function onWidthChanged() {
            popup.followPill();
        }

        target: popup.pill
    }

    Connections {
        function onXChanged() {
            popup.followPill();
        }

        function onYChanged() {
            popup.followPill();
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
        onTriggered: {
            if (!popup.pinned)
                popup.close();

        }
    }

    ClippingRectangle {
        id: card

        // Centered on a whole pixel, as anchors do: half pixels while the width grows
        // make the card and everything in it shake.
        x: popup.frame !== null ? popup.frameContent.x - popup.x : popup.align === Qt.AlignRight ? popup.width - width : popup.align === Qt.AlignHCenter ? Math.round((popup.width - width) / 2) : 0
        y: popup.frame !== null ? popup.frameContent.y - popup.y : 0
        width: popup.frame !== null ? popup.frameContent.width : popup.lerp(popup.pill.width, popup.cardWidth)
        height: popup.frame !== null ? popup.frameContent.height : popup.lerp(popup.pill.height, popup.cardHeight)
        radius: popup.frame !== null ? popup.frame.shape.radius : popup.openRadius
        color: "transparent"
        visible: popup.covering

        // The shared shape draws its own.
        GlassSurface {
            visible: popup.frame === null
            radius: card.radius
            tinted: false
            backgroundColor: Theme.panel
        }

        // Has the keyboard while it's kept open.
        Item {
            id: keys

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape)
                    popup.close();
                else
                    popup.keyPressed(event.key);
            }
        }

        HoverHandler {
            id: cardHover

            // Caught again while folding back onto the pill.
            onHoveredChanged: {
                if (hovered && !popup.closedOnPurpose)
                    popup.expanded = true;

            }
        }

        // A click on the card stays in it, away from the bar and the pill under it.
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
        }

        // Where the pill sits under the card: a click there still keeps it open, or closes
        // it once kept. Under the content, so it only gets the clicks no control keeps
        // (their TapHandlers take the click on press).
        Item {
            x: popup.align === Qt.AlignRight ? parent.width - width : popup.align === Qt.AlignHCenter ? Math.round((parent.width - width) / 2) : 0
            width: popup.pill.width
            height: popup.pill.height

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: popup.togglePinned()
            }

        }

    }

    Behavior on progress {
        NumberAnimation {
            duration: Theme.cardFold
            easing.type: Easing.OutCubic
        }

    }

}
