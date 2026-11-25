import QtQuick
import qs.theme

// An icon a card carries from its place in a pill to the same icon's place in the card
// as it unfolds, and back as it folds (the control center's, out of the island): drawn
// by the card over both, which leave their places empty meanwhile. Both ends are noted
// as a flight starts (measure), and it takes on the other icon's size, color and fill on
// the way.
Icon {
    id: flight

    // The icon it leaves from and the one it lands on, and how far it has gone.
    property Item from: null
    property Item to: null
    property real progress: 0
    property point start
    property point end
    // The card's shape, from its parent, which it never leaves: the shape grows and folds
    // at its own pace, and an icon ahead of it would hang outside the glass.
    property rect bounds: Qt.rect(-1e6, -1e6, 2e6, 2e6)
    // How far it keeps from the shape's edges.
    property real margin: Metrics.spacing.small

    function lerp(a, b) {
        return a + (b - a) * progress;
    }

    // Where both ends are now, from its parent.
    function measure() {
        start = from.mapToItem(parent, from.width / 2, from.height / 2);
        end = to.mapToItem(parent, to.width / 2, to.height / 2);
    }

    // On whole pixels: a glyph across half pixels blurs.
    x: Math.round(Math.max(bounds.x + margin, Math.min(bounds.x + bounds.width - margin - width, lerp(start.x, end.x) - width / 2)))
    y: Math.round(Math.max(bounds.y + margin, Math.min(bounds.y + bounds.height - margin - height, lerp(start.y, end.y) - height / 2)))
    text: to !== null ? to.text : ""
    size: from !== null && to !== null ? lerp(from.size, to.size) : Metrics.text.body
    filled: to !== null && from !== null && (progress > 0.5 ? to.filled : from.filled)
    color: from !== null && to !== null ? Qt.rgba(lerp(from.color.r, to.color.r), lerp(from.color.g, to.color.g), lerp(from.color.b, to.color.b), lerp(from.color.a, to.color.a)) : "transparent"
}
