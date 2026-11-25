import QtQuick
import qs.theme

// One side of the open island (IslandView): a line on what's going on there over a row
// of what you act on, a faint rule between them. Both sides alike, so the time stays in
// the middle: the wallpaper over your workspaces, the machine's load over the control
// center's icons.
IslandPart {
    id: side

    property alias line: lineSlot.data
    property alias row: rowSlot.data
    // Where the row starts, under the line and the rule.
    readonly property real rowY: Metrics.islandBlockHeight + Metrics.spacing.normal

    openHeight: rowY + Metrics.islandBlockHeight
    // It unfolds with the island, like a card.
    token: Motion.unfold.width

    Item {
        id: lineSlot

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
        id: rowSlot

        y: side.rowY
        width: side.openWidth
        height: Metrics.islandBlockHeight
    }

}
