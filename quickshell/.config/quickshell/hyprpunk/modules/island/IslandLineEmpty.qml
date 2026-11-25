import QtQuick
import qs.components
import qs.theme

// A line of the open island with nothing to show (IslandWallpaperLine):
// an empty square where the picture would be, and why.
Item {
    id: empty

    property string icon: ""
    property string label: ""
    readonly property real slot: Metrics.islandBlockHeight

    height: slot
    visible: opacity > 0

    Rectangle {
        width: empty.slot
        height: empty.slot
        radius: Metrics.spacing.normal
        color: Colors.alpha(Colors.secondary, 0.1)

        Icon {
            x: (parent.width - implicitWidth) / 2
            y: (parent.height - implicitHeight) / 2
            text: empty.icon
            color: Colors.alpha(Colors.secondary, 0.5)
            size: Metrics.text.title
        }

    }

    Text {
        x: empty.slot + Metrics.spacing.normal
        y: (empty.slot - height) / 2
        width: empty.width - x
        elide: Text.ElideRight
        text: empty.label
        color: Colors.alpha(Colors.secondary, 0.5)
        font.family: Metrics.font
        font.pixelSize: Metrics.text.body
        font.weight: Font.DemiBold
    }

}
