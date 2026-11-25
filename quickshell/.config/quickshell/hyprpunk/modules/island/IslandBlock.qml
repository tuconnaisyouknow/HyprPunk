import QtQuick
import qs.components
import qs.theme

// A block of the open island (IslandView): the time with the date, the control center's
// icons, the music or the window you're on. It lights up a little under the pointer, and a
// click on it does its one thing.
Item {
    id: block

    property bool interactive: true
    readonly property bool hovered: hover.hovered
    // Round ends, unless what it holds has corners of its own (the music's cover).
    property real radius: Math.min(height, width) / 2

    signal clicked()

    Rectangle {
        anchors.fill: parent
        radius: block.radius
        color: Colors.alpha(Colors.primary, block.hovered ? 0.14 : 0)

        ColorFade on color {
            token: Motion.color.small
        }

    }

    HoverHandler {
        id: hover

        enabled: block.interactive
        cursorShape: Qt.PointingHandCursor
    }

    // Taken on press, so the island under it doesn't answer the click too.
    TapHandler {
        enabled: block.interactive
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: block.clicked()
    }

}
