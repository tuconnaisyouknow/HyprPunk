import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

// Modal card growing out of the dynamic island like the calendar (session menu,
// wallpaper picker...). It takes the keyboard while open (Escape closes it, the
// other keys go to keyTargets) and a click outside the card closes it.
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
    // Left/right keys of the Hyprland binds for the keyboard layout (keyboard_state.lua):
    // j/m on AZERTY, h/l on QWERTY.
    property string keyboardLayout: "us"

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

    // -1 or 1 for the layout's left/right keys (no modifier), 0 otherwise.
    function horizontalKey(event) {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return 0;

        const left = keyboardLayout === "fr" ? Qt.Key_J : Qt.Key_H;
        const right = keyboardLayout === "fr" ? Qt.Key_M : Qt.Key_L;
        return event.key === left ? -1 : event.key === right ? 1 : 0;
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

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/hyprpunk/keyboard-layout"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: panel.keyboardLayout = text().trim() || "us"
    }

    Connections {
        function onPanelRequestsChanged() {
            const request = panel.shellState.panelRequest;
            const target = request.screen || (Hyprland.focusedMonitor !== null ? Hyprland.focusedMonitor.name : "");
            if (request.panel !== panel.panelName || target !== panel.screen.name)
                return ;

            if (request.action === "open" || (request.action === "toggle" && !panel.opened))
                panel.open();
            else
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

        x: panel.width / 2 + panel.island.centerOffset - width / 2
        y: panel.island.top
        width: panel.lerp(panel.island.width, panel.cardWidth)
        height: panel.lerp(panel.island.height, panel.cardHeight)
        radius: panel.lerp(panel.island.height / 2, 24)
        color: "transparent"
        focus: true
        Keys.forwardTo: panel.keyTargets
        Keys.onEscapePressed: panel.close()

        // Same card as the calendar: surface0 (the island) to base at 0.9 (blurred by a
        // layer rule) with the glass rim.
        GlassSurface {
            radius: card.radius
            tinted: false
            backgroundColor: Qt.rgba(panel.lerp(49, 30) / 255, panel.lerp(50, 30) / 255, panel.lerp(68, 46) / 255, panel.lerp(1, 0.9))
        }

        // Swallows the clicks on the card itself, so only the outside closes the panel.
        MouseArea {
            anchors.fill: parent
        }

        // Laid out at full size, only uncovered while the card grows.
        Item {
            id: contentArea

            anchors.horizontalCenter: parent.horizontalCenter
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
