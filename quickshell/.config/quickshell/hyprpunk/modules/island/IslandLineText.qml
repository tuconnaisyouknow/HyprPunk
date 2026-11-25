import QtQuick
import qs.theme

// What a line of the open island says (IslandMusicLine, IslandWindowLine): a title over
// its detail, cut short at the line's end.
Column {
    property string title: ""
    property string detail: ""

    // At its exact middle, never centred by anchors, which round: the line glides as the
    // island opens.
    y: ((parent ? parent.height : 0) - height) / 2

    Text {
        width: parent.width
        elide: Text.ElideRight
        text: parent.title
        color: Colors.primary
        font.family: Metrics.font
        font.pixelSize: Metrics.text.body
        font.weight: Font.DemiBold
    }

    Text {
        width: parent.width
        elide: Text.ElideRight
        visible: text !== ""
        text: parent.detail
        color: Colors.secondary
        font.family: Metrics.font
        font.pixelSize: Metrics.text.small
        font.weight: Font.DemiBold
    }

}
