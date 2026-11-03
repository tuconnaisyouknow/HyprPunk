import QtQuick
import Quickshell
import Quickshell.Wayland

// A see-through layer over the screen, under the panels and the bar's cards, while one
// is kept open: a click anywhere else closes it, and Escape too when it takes the keyboard.
PanelWindow {
    id: outside

    property bool active: false
    // For a panel that can't have the keyboard itself (a card grown from the bar).
    property bool takesKeyboard: false

    signal dismissed()

    visible: active
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    // Above the windows and the bar, under the bar's cards (popups stay above their bar),
    // the control center and the island's panels.
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "hyprpunk-outside"
    WlrLayershell.keyboardFocus: active && takesKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    onActiveChanged: {
        if (active)
            keys.forceActiveFocus();

    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    MouseArea {
        id: catcher

        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: outside.dismissed()
    }

    Item {
        id: keys

        focus: true
        Keys.onEscapePressed: outside.dismissed()
    }

    mask: Region {
        item: catcher
    }

}
