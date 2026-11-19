import QtQuick

// A pill's content while a card covers the pill, at the pill's place in the card's shape.
// The pill hides under its card, glass and all, so its content moves here and stays the
// one you see: it fades as the card grows out, faster than the shape so it's gone before
// the card's content shows, and comes back as the card folds, whole once it lands.
Item {
    id: carrier

    required property Item pill
    // The card is out, over the pill.
    property bool active: false
    // How much the card's shape is still the pill's: 1 folded on it, 0 open.
    property real share: 0

    width: pill.width
    height: pill.height
    opacity: Math.pow(share, 3)
    visible: opacity > 0
    // The card has the pointer, and the pill's spot in it the clicks.
    enabled: false

    Binding {
        target: carrier.pill
        property: "carrier"
        value: carrier
        when: carrier.active
    }

    // Zoomed with the pill, past its place under the pointer.
    transform: Scale {
        origin.x: carrier.width / 2
        origin.y: carrier.height / 2
        xScale: 1 + 2 * carrier.pill.spreadX / Math.max(carrier.pill.width, 1)
        yScale: 1 + 2 * carrier.pill.spreadY / Math.max(carrier.pill.height, 1)
    }

}
