import QtQuick
import Quickshell.Widgets
import qs.components
import qs.services
import qs.theme

// The wallpaper and its theme, in the open island over your workspaces (IslandView): its
// picture, its title over the theme's name and the colors the whole desktop takes from
// it. A click opens the wallpaper picker.
IslandBlock {
    id: line

    readonly property var entry: Wallpapers.currentEntry
    readonly property real slot: Metrics.islandBlockHeight

    radius: Metrics.spacing.normal

    ClippingRectangle {
        width: line.slot
        height: line.slot
        radius: line.radius
        color: Colors.alpha(Colors.secondary, 0.1)
        visible: Wallpapers.current !== ""

        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(2 * line.slot, 2 * line.slot)
            // The thumbnail once listed, the picture itself until then.
            source: "file://" + (line.entry?.thumbnail ?? Wallpapers.current)
        }

    }

    Column {
        x: line.slot + Metrics.spacing.normal
        y: (line.height - height) / 2
        width: line.width - x - Metrics.spacing.normal
        visible: Wallpapers.current !== ""

        // Scrolls round when it's too long, while you see it.
        MarqueeText {
            width: parent.width
            running: line.visible
            text: Wallpapers.title(Wallpapers.current)
            color: Colors.primary
            font.family: Metrics.font
            font.pixelSize: Metrics.text.body
            font.weight: Font.DemiBold
        }

        // The theme, and the colors the whole desktop takes from the wallpaper, as the
        // picker shows them. The surface would vanish on the island without its faint
        // outline.
        Row {
            spacing: Metrics.spacing.normal

            Text {
                id: themeName

                text: Wallpapers.theme.charAt(0).toUpperCase() + Wallpapers.theme.slice(1)
                color: Colors.secondary
                font.family: Metrics.font
                font.pixelSize: Metrics.text.small
                font.weight: Font.DemiBold
            }

            Row {
                anchors.verticalCenter: themeName.verticalCenter
                spacing: Metrics.spacing.small

                Repeater {
                    model: line.entry?.colors ?? []

                    Rectangle {
                        required property string modelData

                        width: 8
                        height: 8
                        radius: 4
                        color: modelData
                        border.width: 1
                        border.color: Colors.alpha(Colors.secondary, 0.3)
                    }

                }

            }

        }

    }

    // A wallpaper outside the folders wallpaperctl.sh reads, or none yet.
    IslandLineEmpty {
        width: line.width
        visible: Wallpapers.current === ""
        icon: "wallpaper"
        label: "No wallpaper"
    }

}
