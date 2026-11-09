import QtQuick

// The one card shape every card of the island is drawn in: the panels, the calendar, the
// notifications and the AirPods card. It grows out of the island to the open card's size
// and folds back once none is open. When a card takes the island from another, the shape
// only changes size while the old content fades out and the new one in, rather than one
// card folding back behind the other. The cards draw their content clipped to it.
// It eases where it sits too: the island moves and changes height when it takes an OSD
// (Bar.islandOsdShown), which happens as soon as the last card closes.
Card {
    id: frame

    required property var bar
    // The cards that grow out of the island.
    property var cards: []
    // The card open on the island.
    readonly property Item openCard: cards.find((card) => {
        return card.opened;
    }) ?? null
    // The card whose shape it heads to: the open one, taken once the shape it's in has
    // been noted, so that nothing heading to the new card moves before.
    property Item owner: null
    readonly property var island: bar.islandPill
    // Folded, it's the island as you see it, zoomed past its place under the pointer.
    readonly property real targetWidth: owner !== null ? owner.cardWidth : island.width + 2 * island.spreadX
    readonly property real targetHeight: owner !== null ? owner.cardHeight : island.height + 2 * island.spreadY
    readonly property real targetRadius: owner !== null ? owner.openRadius : island.height / 2 + island.spreadY
    readonly property real targetTop: owner !== null ? island.top : island.top - island.spreadY
    // The shape it was in when the open card last changed, and how far it has eased from
    // there. It eases from wherever it is, so a card taking over mid-animation never jumps,
    // and then follows the open card's size as that changes (a month with one more week).
    property real fromWidth: 0
    property real fromHeight: 0
    property real fromRadius: 0
    property real fromCenter: 0
    property real fromTop: 0
    property real fromMiddle: 0
    property real fromIslandShare: 1
    property real travel: 1
    // How far its middle is from the screen's, where its top is, and the height of the
    // island's middle, for what sits beside it.
    readonly property real shapeCenter: lerp(fromCenter, island.centerOffset, travel)
    readonly property real shapeTop: lerp(fromTop, targetTop, travel)
    readonly property real islandMiddle: lerp(fromMiddle, island.top + island.height / 2, travel)
    // How much the shape is the island's own: 1 folded on it, 0 a card's. The OSD beside
    // a card goes into the island with it as it folds back, and comes out as a card opens.
    readonly property real islandShare: lerp(fromIslandShare, owner === null ? 1 : 0, travel)
    readonly property alias shape: shape

    // From a value to another, the given share of the way: the share is passed in so the
    // bindings follow it as it changes.
    function lerp(from, to, share) {
        return from + (to - from) * share;
    }

    // Where a card shows its content: in the shape, but never past the card's own size.
    // Coming from a wider card, the shape is wider than the card for a moment, and what
    // the card lays out beyond its edge (the calendar's notification side, empty) must
    // stay hidden. Never above the island's top either, where the shape starts from the
    // zoomed island: the content stays still while the shape heads to its place.
    function contentRect(card) {
        const top = Math.max(shape.y, Math.round(island.top));
        const width = Math.min(shape.width, card.cardWidth);
        const height = Math.min(shape.y + shape.height - top, card.cardHeight);
        return Qt.rect(Math.round(shape.x + (shape.width - width) / 2), top, width, height);
    }

    onOpenCardChanged: {
        fromWidth = shape.width;
        fromHeight = shape.height;
        fromRadius = shape.radius;
        fromCenter = shapeCenter;
        fromTop = shapeTop;
        fromMiddle = islandMiddle;
        fromIslandShare = islandShare;
        // A card opening bounces, and one taking the island from a smaller one, along the
        // sides it grows; a smaller one doesn't.
        if (openCard !== null)
            settle.play(openCard.cardWidth > fromWidth, openCard.cardHeight > fromHeight);

        owner = openCard;
        travel = 0;
        travelAnimation.restart();

    }
    anchors.fill: parent
    // Under the cards' content.
    z: -1
    visible: covering
    pillName: "island"
    covering: owner !== null || travelAnimation.running
    cardRect: Qt.rect(shape.x, shape.y, shape.width, shape.height)
    cardRadius: shape.radius

    Item {
        id: shape

        property real radius: frame.lerp(frame.fromRadius, frame.targetRadius, frame.travel)

        // On whole pixels, like the cards' content: half pixels while the card grows make
        // everything in it shake.
        x: Math.round(frame.width / 2 + frame.shapeCenter - width / 2)
        y: Math.round(frame.shapeTop)
        width: frame.lerp(frame.fromWidth, frame.targetWidth, frame.travel) + settle.width
        height: frame.lerp(frame.fromHeight, frame.targetHeight, frame.travel) + settle.height

        // Same look as the island it grows from: base color at 0.9, blurred, with the
        // glass rim.
        GlassSurface {
            radius: shape.radius
            tinted: false
            backgroundColor: Theme.panel
        }

        // A click on the shape stays in it, away from the bar under it, where it's wider
        // than the card shown in it.
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
        }

    }

    CardSettle {
        id: settle
    }

    NumberAnimation {
        id: travelAnimation

        target: frame
        property: "travel"
        to: 1
        duration: Theme.cardFold
        easing.type: Easing.OutCubic
    }

}
