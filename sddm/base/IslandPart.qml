import QtQuick

// A part of the island that comes and goes beside the others in a Row, as in the shell's:
// the padlock, the password's squares, why a try failed. Its place, its gap included,
// opens and closes, and the part grows out of that place's middle at the same rate, so it
// always fills it whole: it shrinks into itself as it goes, never cut by an edge.
// Nothing in here is rounded: the island alone sits on whole pixels, and the part follows
// its exact place, so it glides as the island resizes instead of stepping a pixel back and
// forth. Its place at rest is a whole, even number of pixels, so it lands on whole pixels
// by itself.
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
    width: presence * (gap + openWidth)
    height: openHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    Item {
        id: face

        x: part.presence * part.gap + (part.presence - 1) * part.openWidth / 2
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

    // More squares, other words. Closed, it takes its new size at once and opens to it.
    Behavior on openWidth {
        enabled: part.visible

        NumberAnimation {
            duration: Motion.move.duration
            easing.type: Motion.move.easing
        }

    }

}
