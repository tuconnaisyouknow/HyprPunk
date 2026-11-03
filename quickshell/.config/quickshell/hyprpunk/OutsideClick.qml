import QtQuick
import Quickshell
import Quickshell.Wayland

// A see-through layer over the screen, under the panels, while a panel is kept open:
// a click anywhere else closes it, and Escape too when it takes the keyboard.
PanelWindow {
    id: outside

    property bool active: false
    // For a panel that can't have the keyboard itself (a card grown from the bar).
    property bool takesKeyboard: false
    // The panel's own area on screen, when it sits on the same layer: left to it.
    property rect keep: Qt.rect(0, 0, 0, 0)

    signal dismissed()

    visible: active
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    // Above the windows and the bar, under the control center and the island's panels.
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

        Region {
            x: outside.keep.x
            y: outside.keep.y
            width: outside.keep.width
            height: outside.keep.height
            intersection: Intersection.Subtract
        }

    }

}
