import QtQuick
import qs.components
import qs.theme

// A part of the island that comes and goes beside the others, in a Row: the time, the
// padlock, the password's squares and why it failed (IslandView), a chip after them
// (IslandChips). Its place, its gap included, opens and closes, and the part grows out of
// that place's middle at the same rate, so it always fills it whole: it shrinks into
// itself as it goes, never cut by an edge.
// Nothing in here is rounded: the island's frame alone sits on whole pixels, and the part
// follows its exact place, so it glides as the island resizes instead of stepping a pixel
// back and forth. Its place at rest is a whole, even number of pixels, so it lands on
// whole pixels by itself.
Item {
    id: part

    property bool shown: false
    property bool animated: true
    // Its size once open, and the gap it brings before it.
    property real openWidth: 0
    property real openHeight: 0
    property real gap: 8
    // Eases to a new size by itself. Off for a part whose size is already eased where it's
    // given (the time, as the island opens): easing it again here would lag behind.
    property bool resizes: true
    // How it comes and goes: in place like the island's faces, or unfolding like a card
    // for the parts the island opens onto.
    property var token: Motion.swap
    // How far it has come, 0 gone, 1 whole, and how much of its place the row leaves it
    // for now: the music's ends and the chips make way as the island opens (IslandView).
    property real arrival: shown ? 1 : 0
    property real room: 1
    // How much it's there.
    readonly property real presence: arrival * room
    // Where its own place starts in the row, past its gap.
    readonly property real placeX: x + presence * gap
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

    Behavior on arrival {
        enabled: part.animated

        Anim {
            token: part.token
        }

    }

    // A count gaining a digit, the recording's time, other words. Closed, it takes its
    // new size at once and opens to it.
    Behavior on openWidth {
        enabled: part.animated && part.visible && part.resizes

        Anim {
            token: Motion.resize.small
        }

    }

}
