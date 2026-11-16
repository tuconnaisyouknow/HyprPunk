import QtQuick
import qs.components
import qs.theme

// One of the island's faces (IslandView): the time and its chips (or the lock's padlock),
// an OSD.
// The faces lie on top of each other in the middle of the island and one shows at a time:
// the face going shrinks a little into its middle and fades, while the next one grows
// out of it, and the island goes from one's size to the other's.
Item {
    id: face

    property bool shown: false
    property bool animated: true
    // Its content's size, and the island around it: the padding on each side and the
    // height.
    property real contentWidth: 0
    property real contentHeight: 0
    property real padding: 0
    property real islandHeight: 0
    // Never narrower than tall: around the padlock alone, a circle.
    readonly property real islandWidth: Math.max(contentWidth + 2 * padding, islandHeight)
    // How much it's there: 0 gone, 1 whole.
    property real presence: shown ? 1 : 0
    // Coming or going.
    readonly property bool moving: swap.running

    anchors.centerIn: parent
    width: contentWidth
    height: contentHeight
    visible: presence > 0
    // Mostly gone by the time the next one is halfway in, so the two never read as one.
    opacity: presence * presence
    scale: 0.8 + 0.2 * presence

    Behavior on presence {
        enabled: face.animated

        Anim {
            id: swap

            token: Motion.swap
        }

    }

}
