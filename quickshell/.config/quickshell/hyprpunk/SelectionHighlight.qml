import QtQuick

// The glass under the selected entry of the island panels' lists and grids, given to
// the view as its highlight. One per list, jumping to the selection, rather than one
// waiting hidden in every entry.
Item {
    id: highlight

    // The list or grid it belongs to.
    required property Item view
    property real radius: 14
    // Space around it inside a grid's cell.
    property real inset: 0

    width: view.cellWidth !== undefined ? view.cellWidth : view.currentItem ? view.currentItem.width : 0
    height: view.cellHeight !== undefined ? view.cellHeight : view.currentItem ? view.currentItem.height : 0
    visible: view.currentIndex >= 0
    // Shrinks with an entry being pressed, if the entry says how much.
    scale: view.currentItem && view.currentItem.pressScale !== undefined ? view.currentItem.pressScale : 1

    GlassSurface {
        anchors.margins: highlight.inset
        radius: highlight.radius
        hovered: true
    }

}
