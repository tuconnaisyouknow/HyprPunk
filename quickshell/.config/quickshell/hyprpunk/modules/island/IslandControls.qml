import QtQuick
import qs.components
import qs.modules.bar
import qs.theme

// The control center's icons in the open island, when it's alone in the bar: a click
// opens the control center, which grows out of the island like its other cards.
IslandBlock {
    id: block

    required property var bar
    // The icons, and those a card carries out of them for now (Card.carriedIcons).
    readonly property alias status: status
    property var lifted: []

    implicitWidth: status.implicitWidth + 2 * Metrics.spacing.large
    implicitHeight: Metrics.islandBlockHeight
    onClicked: bar.screenState.toggle("controlcenter")

    // At its exact middle, never centred by anchors, which round: the island's parts
    // glide as it opens.
    ControlStatus {
        id: status

        x: (parent.width - implicitWidth) / 2
        y: (parent.height - implicitHeight) / 2
        badgeColor: Colors.panel
        showsTrayAttention: true
        lifted: block.lifted
    }

}
