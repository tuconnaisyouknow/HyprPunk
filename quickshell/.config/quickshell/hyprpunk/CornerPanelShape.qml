import QtQuick

// Background of a panel glued to the top-right screen corner: inverted
// corners where it meets the top and right edges, and a rounded bottom-left
// corner. The glass rim follows the free edge, from one screen edge to the other.
GlassEdgeShape {
    id: shape

    readonly property string freeEdge: "M 0 0 " + "C 13 0 24 11 24 24 " + "L 24 " + (height - 48) + " " + "C 24 " + (height - 35) + " 35 " + (height - 24) + " 48 " + (height - 24) + " " + "L " + (width - 24) + " " + (height - 24) + " " + "C " + (width - 11) + " " + (height - 24) + " " + width + " " + (height - 13) + " " + width + " " + height

    fillPath: freeEdge + " L " + width + " 0 L 0 0"
    rimPath: freeEdge
}
