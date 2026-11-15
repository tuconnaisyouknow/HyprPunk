import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

// One chip after the island's time (IslandChips). Its place beside the time opens and
// closes, and the chip grows out of its own middle at the same rate, so it always fills
// that place whole: it shrinks into itself as it goes, never cut by an edge.
Item {
    id: chip

    property bool shown: false
    property bool animated: true
    // Its size once open, and the gap it brings before it.
    property real openWidth: 0
    property real openHeight: 24
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
        width: chip.openWidth
        height: chip.openHeight
        scale: chip.presence
        // Faster than it shrinks, so it's gone before it's a speck, and whole as it lands.
        opacity: chip.presence * chip.presence
    }

    Behavior on presence {
        enabled: chip.animated

        Anim {
            token: Motion.resize.normal
        }

    }

    // A count gaining a digit, or the recording's time.
    Behavior on openWidth {
        enabled: chip.animated

        Anim {
            token: Motion.resize.small
        }

    }

}
