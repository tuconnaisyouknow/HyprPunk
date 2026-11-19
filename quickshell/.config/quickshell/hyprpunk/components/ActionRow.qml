import QtQuick
import QtQuick.Layouts
import qs.theme

// A button row on the control center's detail pages and in the settings: icon, label, glass.
// The dangerous ones (forget, delete) turn red and wait for a second click or Enter, like
// the session menu. One with nothing left to act on is off: dimmed, and it doesn't answer.
ControlBlock {
    id: action

    required property string icon
    required property string label
    property bool destructive: false
    property string confirmLabel: "Click again to confirm"
    property bool armed: false
    // What it acts on, read off the machine and shown at its end ("56 copies").
    property string detail: ""
    readonly property color ink: armed ? Colors.base : !enabled ? Colors.secondary : destructive ? Colors.red : Colors.primary

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
    opacity: enabled ? 1 : 0.5
    onEnabledChanged: armed = false

    Rectangle {
        anchors.fill: parent
        radius: action.radius
        color: Colors.alpha(Colors.red, 0.9)
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
            color: action.ink
            font.family: Metrics.font
            font.pixelSize: 17
        }

        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: action.armed ? action.confirmLabel : action.label
            color: action.ink
            font.family: Metrics.font
            font.pixelSize: Metrics.text.emphasis
            font.weight: Font.Bold
        }

        Readout {
            visible: text !== ""
            text: action.detail
            ink: action.armed ? Colors.base : Colors.secondary
        }

    }

    HoverHandler {
        enabled: action.enabled
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

    Behavior on opacity {
        Anim {
            token: Motion.color.normal
        }

    }

}
