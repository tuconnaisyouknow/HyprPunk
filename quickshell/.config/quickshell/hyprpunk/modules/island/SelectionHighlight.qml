import QtQuick
import qs.components
import qs.theme

// The glass under the selected entry of the island panels' lists and grids, given to
// the view as its highlight. One per list, jumping to the selection, rather than one
// waiting hidden in every entry. In neon the glass lights up in the accent, from its edge inward.
Item {
    id: highlight

    // The list or grid it belongs to.
    required property Item view
    property real radius: Metrics.radius.normal
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
        lit: true
        inward: true
        backgroundColor: Colors.emits ? Colors.alpha(Colors.primary, 0.7) : "transparent"
    }

}
