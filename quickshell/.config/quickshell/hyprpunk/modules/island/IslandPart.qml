import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

// A part of the island that comes and goes beside the others: the time, the padlock, the
// password's dots and why it failed (IslandView), a chip after them (IslandChips). Its place in
// the row opens and closes, and the part grows out of its own middle at the same rate, so
// it always fills that place whole: it shrinks into itself as it goes, never cut by an
// edge.
Item {
    id: part

    property bool shown: false
    property bool animated: true
    // Its size once open, and the gap it brings before it.
    property real openWidth: 0
    property real openHeight: 0
    property real gap: 8
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
        enabled: part.animated

        Anim {
            token: Motion.swap
        }

    }

    // A count gaining a digit, the recording's time, other words. Closed, it takes its
    // new size at once and opens to it.
    Behavior on openWidth {
        enabled: part.animated && part.visible

        Anim {
            token: Motion.resize.small
        }

    }

}
