import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// The card that grows out of the dynamic island, behind every island panel (session
// menu, wallpaper picker…). While open it has the keyboard: Escape closes it and other
// keys go to keyTargets. Clicking anywhere outside closes it too.
PanelWindow {
    id: panel

    required property var shellState
    // Name used by the panel requests (ipc), e.g. "session".
    required property string panelName
    property real cardWidth: 300
    property real cardHeight: 120
    // Items with Keys handlers for the panel's own keys.
    property var keyTargets: []
    default property alias content: contentArea.data
    // Mapped from open() until the card has folded back onto the island.
    property bool shown: false
    property bool opened: false
    // Set while the window is mapping: the card only grows once its first frame is on screen.
    property bool openPending: false
    property real progress: opened ? 1 : 0
    // Geometry of the island (the clock pill), published by the bar.
    readonly property var island: shellState.islandPill
    // The Vim left and right keys for the current layout: h/l, or j/m on AZERTY.
    readonly property string keyboardLayout: Session.keyboardLayout
    // Panel whose request opened this one ("menu" from the main menu), read on opening.
    property string openedFrom: ""

    // Emitted before the card grows, to reset the panel's state.
    signal opening()

    function lerp(from, to) {
        return from + (to - from) * progress;
    }

    function open() {
        hideDelay.stop();
        opening();
        if (shown) {
            opened = true;
        } else {
            openPending = true;
            shown = true;
        }
    }

    function close() {
        openPending = false;
        opened = false;
        hideDelay.restart();
    }

    // Escape: back to the main menu when it opened this panel, closed otherwise.
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

    visible: shown
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hyprpunk-island"
    // Given back as soon as the card closes, e.g. to the panel it opens.
    WlrLayershell.keyboardFocus: shown && (opened || openPending) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Connections {
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

    Connections {
        function onFrameSwapped() {
            if (panel.openPending) {
                // In this order, the keyboard focus stays exclusive.
                panel.opened = true;
                panel.openPending = false;
            }
        }

        target: card.Window.window
    }

    // Anywhere outside the card closes the panel.
    MouseArea {
        anchors.fill: parent
        onClicked: panel.close()
    }

    ClippingRectangle {
        id: card

        // On whole pixels, like the content below: half pixels while the card grows make
        // everything in it shake.
        x: Math.round(panel.width / 2 + panel.island.centerOffset - width / 2)
        y: panel.island.top
        width: panel.lerp(panel.island.width, panel.cardWidth)
        height: panel.lerp(panel.island.height, panel.cardHeight)
        // The island's corners: rounder ones would let the island's show under the card.
        radius: panel.island.height / 2
        color: "transparent"
        focus: true
        Keys.forwardTo: panel.keyTargets
        Keys.onEscapePressed: panel.back()

        // Same look as the island it grows from: base color at 0.9, blurred, with the glass rim.
        GlassSurface {
            radius: card.radius
            tinted: false
            backgroundColor: Theme.panel
        }

        // Swallows the clicks on the card itself, so only the outside closes the panel.
        MouseArea {
            anchors.fill: parent
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

    Timer {
        id: hideDelay

        // Lets the card fold back onto the island first.
        interval: 320
        onTriggered: panel.shown = false
    }

    Behavior on progress {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }

    }

}
