import QtQuick
import QtQuick.Layouts

// A button row on the control center's detail pages: icon, label, glass.
// The dangerous ones (forget, delete) turn red and wait for a second click, like the session menu.
ControlBlock {
    id: action

    required property string icon
    required property string label
    property bool destructive: false
    property string confirmLabel: "Click again to confirm"
    property bool armed: false

    signal triggered()

    implicitHeight: 44
    radius: 14

    Rectangle {
        anchors.fill: parent
        radius: action.radius
        color: Qt.rgba(243 / 255, 139 / 255, 168 / 255, 0.9)
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
            color: action.armed ? "#1e1e2e" : action.destructive ? "#f38ba8" : "#cba6f7"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 17
        }

        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: action.armed ? action.confirmLabel : action.label
            color: action.armed ? "#1e1e2e" : action.destructive ? "#f38ba8" : "#cba6f7"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            font.weight: Font.Bold
        }

    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: {
            action.bounce();
            if (action.destructive && !action.armed) {
                action.armed = true;
                disarmDelay.restart();
            } else {
                action.armed = false;
                action.triggered();
            }
        }
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
