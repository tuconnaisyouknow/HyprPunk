import QtQuick
import Quickshell.Widgets
import qs.components
import qs.theme

// Beside the file picker's list: the selected entry, or the folder itself when nothing
// is. A picture shows itself, anything else its icon, with its size and date.
Column {
    id: preview

    // {name, path, isDir, size, modified}, null for the folder.
    required property var entry
    required property string folder
    // How many entries the folder shows.
    required property int count
    readonly property bool showsImage: entry !== null && !entry.isDir && Files.isImage(entry.name)

    spacing: Metrics.spacing.normal

    ClippingRectangle {
        id: frame

        width: parent.width
        height: parent.width
        radius: Metrics.radius.normal
        color: "transparent"

        GlassSurface {
            radius: frame.radius
        }

        Image {
            anchors.fill: parent
            anchors.margins: Metrics.spacing.normal
            visible: preview.showsImage
            source: preview.showsImage ? Files.url(preview.entry.path) : ""
            // Twice its size, sharp on a scaled screen.
            sourceSize: Qt.size(2 * width, 2 * height)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
        }

        Text {
            anchors.centerIn: parent
            visible: !preview.showsImage
            text: Files.icon(preview.entry ?? {
                "name": "",
                "isDir": true
            })
            color: Colors.primary
            font.family: Metrics.font
            // The picture's place, filled by its icon.
            font.pixelSize: frame.width * 0.3
        }

    }

    Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WrapAnywhere
        maximumLineCount: 3
        elide: Text.ElideRight
        text: preview.entry ? preview.entry.name : Files.name(preview.folder)
        color: Colors.primary
        font.family: Metrics.font
        font.pixelSize: Metrics.text.emphasis
    }

    Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: !preview.entry ? preview.count + (preview.count === 1 ? " item" : " items") : (preview.entry.isDir ? "Folder" : Files.size(preview.entry.size)) + " · " + preview.entry.modified.toLocaleDateString(Qt.locale(), Locale.ShortFormat)
        color: Colors.secondary
        font.family: Metrics.font
        font.pixelSize: Metrics.text.small
    }

}
