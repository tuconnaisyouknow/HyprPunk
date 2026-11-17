import QtQuick
import Quickshell.Widgets
import qs.components
import qs.theme
import qs.windows

// A card that grows out of one of the bar's pills: the workspace preview, the system
// monitor, the calendar and the player. A click on the pill or its shortcut opens it,
// and it stays until Escape or Backspace, a click outside, the shortcut or the pill again.
// The workspace preview also opens on hover, for a glance: resting on the pill a moment
// opens it, and leaving both the pill and the card folds it back.
// Its content is laid out at full size and uncovered as the card grows.
Card {
    id: popup

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
    // Opens while the pointer rests on the pill, as a preview (the workspaces).
    property bool opensOnHover: false
    // How long the pointer rests on the pill before a preview opens, and how long it
    // waits once the pointer has left (Motion).
    property int openDelay: Motion.hoverOpenDelay
    property int closeDelay: Motion.hoverCloseDelay
    // False hides it (no player anymore).
    property bool available: true
    // Checked when the delay is up: false and it doesn't open after all (the pointer
    // left the workspace it was resting on).
    property bool openable: true
    // True and it doesn't open at all, however asked (a prompt holds the island).
    property bool blocked: false
    // Its name on its screen (ScreenState), the IPC's, for its shortcut.
    property string panelName: ""
    property var screenState: null
    // False and its shortcut doesn't open it, only closes it: nothing to show (no other
    // workspace to preview, no player) or no pill to open from.
    property bool requestable: true
    // Unfolded, or unfolding.
    property bool expanded: false
    // Out, from the opening until folded back.
    readonly property bool mapped: expanded || progress > 0
    // Opened on purpose (a shortcut, a click) rather than as a preview: it stays open
    // when the pointer leaves, until closed. Always the case for a card that doesn't
    // open on hover.
    property bool pinned: false
    // Closed while kept open, until it has folded back: the pointer resting on the
    // preview's card or pill doesn't open it again.
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
    // The card grows from the pill as you see it, zoomed past its place, to its own place:
    // how far its shape still starts past that place, on whole pixels.
    readonly property int startX: frame !== null ? 0 : Math.round(lerp(pill.spreadX, 0))
    readonly property int startY: frame !== null ? 0 : Math.round(lerp(pill.spreadY, 0))
    // Its own shape's size as it grows and bounces, between two pixels too.
    readonly property real shapeWidth: lerp(pill.width + 2 * pill.spreadX, cardWidth) + settle.width
    readonly property real shapeHeight: lerp(pill.height + 2 * pill.spreadY, cardHeight) + settle.height
    // What draws its shape: its own glass, or its content's place in the shared one.
    readonly property Item shape: frame !== null ? card : glass
    default property alias content: room.data

    // Right before it opens, to set the content up.
    signal opening()
    // Any other key while it's kept open, for a card that answers the keyboard.
    signal keyPressed(int key)

    function lerp(from, to) {
        return from + (to - from) * progress;
    }

    // The pointer is on the pill of a preview (or on what opens it).
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

    // What its shortcut asks ("toggle", "open" or "close"), through ScreenState. Open,
    // however it was opened (a click, a preview, the shortcut), the shortcut closes it;
    // closed, it opens it kept.
    function requestAction(action) {
        if (!requestable && !expanded)
            return ;

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

    // Hangs from the pill, kept on the screen. From where the pill rests in its row: its
    // zoom under the pointer is only drawn, and would leave the card off once it settles.
    function followPill() {
        // Still being set up.
        if (pill === null || cardLayer === null)
            return ;

        const origin = pill.parent.mapToItem(cardLayer, pill.x, pill.y);
        const left = align === Qt.AlignRight ? origin.x + pill.width - width : align === Qt.AlignHCenter ? origin.x + (pill.width - width) / 2 : origin.x;
        x = Math.round(Math.max(0, Math.min(cardLayer.width - width, left)));
        y = Math.round(origin.y);
    }

    parent: cardLayer
    opened: expanded
    // The open card's size, the full size by default. Animate it on your side if it
    // changes while open (the calendar taking the notifications beside it). The room the card needs
    // stays at its widest and the card eases inside it.
    cardWidth: width
    cardHeight: height
    // The pill's corners: rounder ones would let the pill's show under the card.
    openRadius: pill.radius
    width: implicitWidth
    height: implicitHeight
    visible: mapped && available
    covering: visible
    cardRect: Qt.rect(x + shape.x, y + shape.y, shape.width, shape.height)
    cardRadius: card.radius
    takesKeyboard: pinned && visible
    dismissable: pinned && visible
    onMappedChanged: {
        if (!mapped)
            closedOnPurpose = false;

    }
    Component.onCompleted: {
        if (panelName !== "")
            screenState?.register(panelName, popup);

    }
    Component.onDestruction: {
        if (panelName !== "")
            screenState?.unregister(panelName, popup);

    }
    onPointerInsideChanged: {
        if (pointerInside) {
            closeTimer.stop();
        } else {
            openTimer.stop();
            closeTimer.restart();
        }
    }
    // Kept open: Escape or Backspace closes it, and the card's own keys reach it.
    onPinnedChanged: {
        if (pinned)
            keys.forceActiveFocus();

    }
    onWidthChanged: followPill()
    onExpandedChanged: {
        if (expanded)
            settle.play(true, true);

    }

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

    // Its glass, alone so it moves freely between two pixels: on whole ones its edges
    // stepped, a few times a second as the bounce slows down. The shared shape draws
    // its own.
    Item {
        id: glass

        readonly property real startX: popup.lerp(popup.pill.spreadX, 0)

        x: popup.align === Qt.AlignRight ? popup.width - width + startX : popup.align === Qt.AlignHCenter ? (popup.width - width) / 2 : -startX
        y: -popup.lerp(popup.pill.spreadY, 0)
        width: popup.shapeWidth
        height: popup.shapeHeight
        visible: popup.frame === null && popup.covering

        // Lit under the pointer as it folds back onto the pill that is.
        GlassSurface {
            radius: card.radius
            tinted: false
            hovered: !popup.expanded && popup.pill.lit
            backgroundColor: Colors.panel
        }

    }

    ClippingRectangle {
        id: card

        // The content's place in the glass, on whole pixels, its size too: half pixels
        // while the card grows or bounces make everything in it shake (the content is
        // drawn as a picture of its size).
        x: popup.frame !== null ? popup.frameContent.x - popup.x : popup.align === Qt.AlignRight ? popup.width - width + popup.startX : popup.align === Qt.AlignHCenter ? Math.round((popup.width - width) / 2) : -popup.startX
        y: popup.frame !== null ? popup.frameContent.y - popup.y : -popup.startY
        width: popup.frame !== null ? popup.frameContent.width : Math.round(popup.shapeWidth)
        height: popup.frame !== null ? popup.frameContent.height : Math.round(popup.shapeHeight)
        radius: popup.frame !== null ? popup.frame.shape.radius : popup.openRadius
        color: "transparent"
        visible: popup.covering

        // Has the keyboard while it's kept open.
        Item {
            id: keys

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape || Navigation.backs(event))
                    popup.close();
                else
                    popup.keyPressed(event.key);
            }
        }

        HoverHandler {
            id: cardHover

            enabled: popup.opensOnHover
            // A preview caught again while folding back onto the pill.
            onHoveredChanged: {
                if (hovered && !popup.closedOnPurpose)
                    popup.expanded = true;

            }
        }

        // A click on the card stays in it, away from the bar and the pill under it.
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
        }

        // The card's own place, inside the pixels its shape starts with from the zoomed
        // pill: the content sits there, so it stays still while the shape heads to it.
        Item {
            id: room

            x: popup.align === Qt.AlignRight ? 0 : popup.startX
            y: popup.startY
            width: parent.width - (popup.align === Qt.AlignHCenter ? 2 : 1) * popup.startX
            height: parent.height - popup.startY

            // Where the pill sits under the card: a click there still keeps a preview
            // open, or closes the card once kept, and the pointer there keeps the pill lit.
            // Under the content, so it only gets the clicks no control keeps (their
            // TapHandlers take the click on press).
            Item {
                x: popup.align === Qt.AlignRight ? parent.width - width : popup.align === Qt.AlignHCenter ? Math.round((parent.width - width) / 2) : 0
                width: popup.pill.width
                height: popup.pill.height

                HoverHandler {
                    id: spotHover

                    cursorShape: Qt.PointingHandCursor
                }

                Binding {
                    target: popup.pill
                    property: "spotHovered"
                    value: spotHover.hovered
                }

                TapHandler {
                    onTapped: popup.togglePinned()
                }

            }

        }

    }

    // Its own shape's bounce; the island's shared shape has its own (IslandFrame).
    CardSettle {
        id: settle
    }

    Behavior on progress {
        NumberAnimation {
            duration: Motion.resize.large.duration
            easing.type: Easing.OutCubic
        }

    }

}
