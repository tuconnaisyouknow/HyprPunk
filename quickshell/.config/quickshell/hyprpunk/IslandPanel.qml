import QtQuick
import Quickshell.Widgets

// The card that grows out of the dynamic island, behind every island panel (session
// menu, wallpaper picker…), drawn in the island's shape (IslandFrame). While open it has
// the keyboard: Escape or Backspace closes it and other keys go to keyTargets. Clicking anywhere
// outside closes it too.
// One panel at a time on the island: opening one takes the shape from the others and the
// calendar, which close.
// The prompts (a password, a file, a screen to share) can't be pushed away: the other
// panels don't open over them, and a second prompt waits for the first one to be done.
Card {
    id: panel

    required property var screen
    required property var shellState
    // Its screen's bar, whose island it grows out of.
    required property var bar
    // The island's card shape, shared with its other cards.
    required property Item islandFrame
    // Name used by the panel requests (ipc), e.g. "session".
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
    // The Vim left and right keys for the current layout: h/l, or j/m on AZERTY.
    readonly property string keyboardLayout: Session.keyboardLayout
    // Panel whose request opened this one ("menu" from the main menu), read on opening.
    property string openedFrom: ""
    // It answers an app, see shellState.promptPanels.
    readonly property bool isPrompt: shellState.promptPanels.includes(panelName)
    // A prompt asked for while another one holds the island: it opens once that one is done.
    property bool queued: false

    // Emitted before the card grows, to reset the panel's state.
    signal opening()

    function open() {
        if (shellState.promptShown(screen.name, panelName)) {
            queued = isPrompt;
            return ;
        }
        queued = false;
        opening();
        // Before opened: the panel may hand the keyboard on to a field of its own then.
        card.forceActiveFocus();
        opened = true;
        shellState.islandClaimed(screen.name, panelName);
    }

    // Folds back onto the island.
    function close() {
        queued = false;
        opened = false;
    }

    function clickedOutside() {
        close();
    }

    // Escape or Backspace: back to the main menu when it opened this panel, closed otherwise.
    function back() {
        close();
        if (openedFrom === "menu")
            shellState.requestPanel("menu", "open", screen.name, panelName);

    }

    // -1 or 1 for the layout's left/right keys (no modifier), 0 otherwise.
    function horizontalKey(event) {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return 0;

        const left = keyboardLayout === "fr" ? Qt.Key_J : Qt.Key_H;
        const right = keyboardLayout === "fr" ? Qt.Key_M : Qt.Key_L;
        return event.key === left ? -1 : event.key === right ? 1 : 0;
    }

    // [dx, dy] for Ctrl + the Vim keys (Ctrl+h/j/k/l, or j/k/l/m on AZERTY), null
    // otherwise. For the panels with a search field, where the letters alone are typed.
    function controlMove(event) {
        if (!(event.modifiers & Qt.ControlModifier))
            return null;

        const keys = keyboardLayout === "fr" ? [Qt.Key_J, Qt.Key_M, Qt.Key_K, Qt.Key_L] : [Qt.Key_H, Qt.Key_L, Qt.Key_J, Qt.Key_K];
        const moves = [[-1, 0], [1, 0], [0, 1], [0, -1]];
        const index = keys.indexOf(event.key);
        return index >= 0 ? moves[index] : null;
    }

    // Gives the keyboard back to the card (and keyTargets), e.g. after a text field.
    function focusCard() {
        card.forceActiveFocus();
    }

    // Tells the island's notifications to wait while the card is open. Not until it has
    // folded back: they take the island's shape from it as it closes.
    onOpenedChanged: {
        const key = panelName + "@" + screen.name;
        const others = shellState.islandPanels.filter((item) => {
            return item !== key;
        });
        shellState.islandPanels = opened ? others.concat([key]) : others;
    }
    Component.onDestruction: {
        if (opened)
            shellState.islandPanels = shellState.islandPanels.filter((item) => {
            return item !== panelName + "@" + screen.name;
        });

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

    Connections {
        // Another panel or the calendar takes the island. Not a prompt, which is waiting
        // for an answer.
        function onIslandClaimed(screenName, owner) {
            if (screenName === panel.screen.name && owner !== panel.panelName && !panel.isPrompt && panel.opened)
                panel.close();

        }

        // The prompt holding the island is done: this one's turn.
        function onIslandPanelsChanged() {
            if (panel.queued && !panel.shellState.promptShown(panel.screen.name, panel.panelName))
                panel.open();

        }

        function onPanelRequestsChanged() {
            const action = panel.shellState.requestedAction(panel.panelName, panel.screen);
            if (action === "")
                return ;

            if (action === "open" || (action === "toggle" && !panel.opened)) {
                panel.openedFrom = panel.shellState.panelRequest.origin;
                panel.open();
            } else
                panel.close();
        }

        target: panel.shellState
    }

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
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }

            }

        }

    }

    // The card covers the island, so the privacy and recording dots move to its right,
    // following its edge as it grows.
    PrivacyDot {
        x: Math.round(card.x + card.width + 8)
        y: Math.round(panel.island.top + panel.island.height / 2 - height / 2)
        camera: panel.shellState.cameraInUse
        microphone: panel.shellState.microphoneInUse
        recording: panel.shellState.recording
        opacity: active ? panel.progress : 0
        visible: opacity > 0
    }

    Behavior on progress {
        NumberAnimation {
            duration: Theme.cardFold
            easing.type: Easing.OutCubic
        }

    }

}
