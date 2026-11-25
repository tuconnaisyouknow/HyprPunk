import QtQuick
import qs.theme

// One side of the open island (IslandView): one block over another, a faint rule between
// them. Both sides alike, so the time stays in the middle: your workspaces over the
// wallpaper, the control center's icons over the machine's load.
IslandPart {
    id: side

    property alias upper: upperSlot.data
    property alias lower: lowerSlot.data
    // Where the lower block starts, under the upper one and the rule.
    readonly property real lowerY: Metrics.islandBlockHeight + Metrics.spacing.normal

    openHeight: lowerY + Metrics.islandBlockHeight
    // It unfolds with the island, like a card.
    token: Motion.unfold.width

    Item {
        id: upperSlot

        width: side.openWidth
        height: Metrics.islandBlockHeight
    }

    Rectangle {
        x: Metrics.spacing.large
        y: Metrics.islandBlockHeight + (Metrics.spacing.normal - height) / 2
        width: side.openWidth - 2 * Metrics.spacing.large
        height: 1
        color: Colors.alpha(Colors.secondary, 0.2)
    }

    Item {
        id: lowerSlot

        y: side.lowerY
        width: side.openWidth
        height: Metrics.islandBlockHeight
    }

}
