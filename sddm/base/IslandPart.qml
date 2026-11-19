import QtQuick
import QtQuick.Layouts

// A part of the island that comes and goes beside the others, as in the shell's: the
// padlock, the password's dots, why a try failed. Its place in the row opens and closes,
// and the part grows out of its own middle at the same rate, so it always fills that place
// whole: it shrinks into itself as it goes, never cut by an edge.
Item {
    id: part

    property bool shown: false
    // Its size once open, and the gap it brings before it.
    property real openWidth: 0
    property real openHeight: 0
    property real gap: 0
    // How much it's there: 0 gone, 1 whole.
    property real presence: shown ? 1 : 0
    default property alias content: face.data

    visible: presence > 0
    Layout.preferredWidth: presence * openWidth
    Layout.leftMargin: presence * gap
    implicitHeight: openHeight

    Item {
        id: face

        anchors.centerIn: parent
        width: part.openWidth
        height: part.openHeight
        scale: part.presence
        // Faster than it shrinks, so it's gone before it's a speck, and whole as it lands.
        opacity: part.presence * part.presence
    }

    Behavior on presence {
        NumberAnimation {
            duration: Motion.swap.duration
            easing.type: Motion.swap.easing
        }

    }

    // More dots, other words. Closed, it takes its new size at once and opens to it.
    Behavior on openWidth {
        enabled: part.visible

        NumberAnimation {
            duration: Motion.move.duration
            easing.type: Motion.move.easing
        }

    }

}
