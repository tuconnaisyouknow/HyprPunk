import QtQuick

// A pill's content while a card covers the pill, at the pill's place in the card's shape.
// The pill hides under its card, glass and all, so its content moves here and stays the
// one you see: it crosses over with the card's content as the card unfolds and folds
// back, quicker than the shape (Motion.unfold).
Item {
    id: carrier

    required property Item pill
    // The card is out, over the pill.
    property bool active: false
    // How much it still shows: 1 the pill's content, 0 the card's.
    property real share: 0

    width: pill.width
    height: pill.height
    // Never hidden, only clear: Qt doesn't lay out what's hidden, and the pill's content
    // would keep its old size under the card (the island turning into an OSD there, which
    // the card folds onto).
    opacity: share
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
