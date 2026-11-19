import QtQuick
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services
import qs.state
import qs.theme
import qs.windows

// The card that grows out of the dynamic island, behind every island panel (session
// menu, wallpaper picker…), drawn in the island's shape (IslandFrame). While open it has
// the keyboard: Escape or Backspace closes it and other keys go to keyTargets. Clicking anywhere
// outside closes it too.
// It's open while it holds its screen's island (ScreenState's claims): one panel at a
// time, so opening one takes the shape from the others and the calendar, which close.
// The prompts (a password, a file, a screen to share) can't be pushed away: the other
// panels don't open over them, and a second prompt waits for the first one to be done.
Card {
    id: panel

    required property var screen
    // Its screen's bar, whose island it grows out of.
    required property var bar
    // The island's card shape, shared with its other cards.
    required property Item islandFrame
    // Its name on its screen (ScreenState), the IPC's, e.g. "session".
    required property string panelName
    // Items with Keys handlers for the panel's own keys.
    property var keyTargets: []
    default property alias content: contentArea.data
    property real progress: opened ? 1 : 0
    // Out, from open() until folded back onto the island.
    readonly property bool shown: opened || progress > 0
    // Where the island is.
    readonly property var island: bar.islandPill
    readonly property Item shape: islandFrame.shape
    readonly property rect contentRect: islandFrame.contentRect(panel)
    // The Vim keys as Qt names them, left, right, down, up: h/l/j/k, or the home row's.
    readonly property var vimKeyCodes: Session.vimKeyCodes
    // Panel whose request opened this one (the launcher, for the menus it lists),
    // where Escape goes back to.
    property string openedFrom: ""
    // Panel that just came back to this one, "" when it was opened afresh.
    property string returnedFrom: ""
    // It answers an app (a password, a file, a screen to share).
    property bool isPrompt: false
    readonly property var screenState: ShellState.forScreen(screen)
    // It holds its screen's island.
    readonly property bool owns: screenState !== null && screenState.islandOwner === panelName

    // Emitted before the card grows, to reset the panel's state.
    signal opening()

    // Asks for the island: a panel doesn't get it while a prompt holds it, a prompt
    // waits its turn.
    function open() {
        screenState?.claim(panelName, isPrompt ? 1 : 2);
    }

    // Folds back onto the island, or no longer waits for it.
    function close() {
        screenState?.release(panelName);
    }

    // What you asked for by name (ScreenState.request).
    function requestAction(action, origin) {
        if (action === "close" || (action === "toggle" && opened)) {
            close();
            return ;
        }
        // Coming back keeps where this one was opened from: the way back goes on.
        returnedFrom = action === "return" ? origin : "";
        if (action !== "return")
            openedFrom = origin;

        open();
    }

    function clickedOutside() {
        close();
    }

    // Escape or Backspace: back to the panel that opened this one, closed otherwise.
    function back() {
        close();
        if (openedFrom !== "")
            screenState?.request(openedFrom, "return", panelName);

    }

    // -1 or 1 for the Vim left/right keys (no modifier), 0 otherwise.
    function horizontalKey(event) {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return 0;

        return event.key === vimKeyCodes[0] ? -1 : event.key === vimKeyCodes[1] ? 1 : 0;
    }

    // [dx, dy] for Ctrl + the Vim keys (Ctrl+h/j/k/l, or the home row's), null
    // otherwise. For the panels with a search field, where the letters alone are typed.
    function controlMove(event) {
        if (!(event.modifiers & Qt.ControlModifier))
            return null;

        const keys = vimKeyCodes;
        const moves = [[-1, 0], [1, 0], [0, 1], [0, -1]];
        const index = keys.indexOf(event.key);
        return index >= 0 ? moves[index] : null;
    }

    // Gives the keyboard back to the card (and keyTargets), e.g. after a text field.
    function focusCard() {
        card.forceActiveFocus();
    }

    // Given the island, or no longer: the panel sets itself up before the card grows,
    // and may hand the keyboard on to a field of its own then.
    onOwnsChanged: {
        if (owns) {
            opening();
            card.forceActiveFocus();
        }
        opened = owns;
    }
    Component.onCompleted: screenState?.register(panelName, panel)
    Component.onDestruction: {
        screenState?.release(panelName);
        screenState?.unregister(panelName, panel);
    }
    anchors.fill: parent
    cardWidth: 300
    cardHeight: 120
    // The island's corners: rounder ones would let the island's show under the card.
    openRadius: island.height / 2
    visible: shown
    pillName: "island"
    covering: shown
    cardRect: Qt.rect(card.x, card.y, card.width, card.height)
    cardRadius: card.radius
    // Given back as soon as the card closes, e.g. to the panel it opens.
    takesKeyboard: opened
    dismissable: opened
    keptUnderFullscreen: isPrompt

    ClippingRectangle {
        id: card

        x: panel.contentRect.x
        y: panel.contentRect.y
        width: panel.contentRect.width
        height: panel.contentRect.height
        radius: panel.shape.radius
        color: "transparent"
        focus: true
        Keys.forwardTo: panel.keyTargets
        Keys.onEscapePressed: panel.back()
        Keys.onPressed: (event) => {
            if (Navigation.backs(event)) {
                panel.back();
                event.accepted = true;
            }
        }

        // A click on the card stays in it, away from the bar under it. Taken on press: a
        // MouseArea misses the clicks a control's TapHandler already watches.
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
        }

        // Laid out at full size, only uncovered while the card grows. It stays put on
        // screen rather than following the card's own rounding, which would nudge it by a
        // pixel now and then.
        Item {
            id: contentArea

            x: Math.round(panel.width / 2 + panel.island.centerOffset - width / 2) - card.x
            anchors.top: parent.top
            width: panel.cardWidth
            height: panel.cardHeight
            opacity: panel.opened ? 1 : 0

            Behavior on opacity {
                Anim {
                    token: Motion.color.small
                }

            }

        }

    }

    // The card covers the island, so the privacy and recording dots move to its right,
    // following its edge as it grows.
    PrivacyDot {
        x: Math.round(card.x + card.width + 8)
        y: Math.round(panel.island.top + panel.island.height / 2 - height / 2)
        camera: Privacy.cameraInUse
        microphone: Privacy.microphoneInUse
        recording: Screenshot.recording
        opacity: active ? panel.progress : 0
        visible: opacity > 0
    }

    Behavior on progress {
        NumberAnimation {
            duration: Motion.resize.large.duration
            easing.type: Easing.OutCubic
        }

    }

}
