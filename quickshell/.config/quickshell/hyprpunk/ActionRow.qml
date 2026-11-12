import QtQuick
import QtQuick.Layouts

// A button row on the control center's detail pages: icon, label, glass.
// The dangerous ones (forget, delete) turn red and wait for a second click or Enter, like
// the session menu.
ControlBlock {
    id: action

    required property string icon
    required property string label
    property bool destructive: false
    property string confirmLabel: "Click again to confirm"
    property bool armed: false

    signal triggered()

    function activate() {
        bounce();
        if (destructive && !armed) {
            armed = true;
            disarmDelay.restart();
        } else {
            armed = false;
            triggered();
        }
    }

    implicitHeight: 44
    radius: 14
    activeFocusOnTab: true

    Rectangle {
        anchors.fill: parent
        radius: action.radius
        color: Theme.alpha(Theme.red, 0.9)
        opacity: action.armed ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 140
            }

        }

    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 12

        Text {
            text: action.icon
            color: action.armed ? Theme.base : action.destructive ? Theme.red : Theme.primary
            font.family: Theme.font
            font.pixelSize: 17
        }

        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: action.armed ? action.confirmLabel : action.label
            color: action.armed ? Theme.base : action.destructive ? Theme.red : Theme.primary
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.Bold
        }

    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: action.activate()
    }

    // Disarmed after a while, or when the pointer leaves.
    Timer {
        id: disarmDelay

        interval: 3000
        onTriggered: action.armed = false
    }

    onHoveredChanged: {
        if (!hovered)
            armed = false;

    }
}
