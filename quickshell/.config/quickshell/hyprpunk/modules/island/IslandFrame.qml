import QtQuick
import qs.components
import qs.modules.island
import qs.theme
import qs.windows

// The one card shape every card of the island is drawn in: the panels, the calendar, the
// notifications and the AirPods card. It unfolds out of the island to the open card's size
// and folds back once none is open, its width and height each going past and coming back
// (Motion.unfold). When a card takes the island from another, the shape only glides to
// its size while the old content fades out and the new one in, rather than one card
// folding back behind the other. The cards draw their content clipped to it.
// It eases where it sits too: the island moves and changes height when it takes an OSD
// (Bar.islandOsdShown), which happens as soon as the last card closes.
// The island itself is hidden while a card covers it, so the shape shows its content
// while it's still the island's (PillContent): nothing pops as a card grows out or folds
// back.
Card {
    id: frame

    required property var bar
    // The cards that grow out of the island.
    property var cards: []
    // The card open on the island.
    readonly property Item openCard: cards.find((card) => {
        return card.showing;
    }) ?? null
    // The card whose shape it heads to: the open one, taken once the shape it's in has
    // been noted, so that nothing heading to the new card moves before.
    property Item owner: null
    // The card that held the shape last, kept while it folds back.
    property Item lastOwner: null
    readonly property var island: bar.islandPill
    // Folded, it's the island as you see it, zoomed past its place under the pointer.
    readonly property real targetWidth: owner !== null ? owner.cardWidth : island.width + 2 * island.spreadX
    readonly property real targetHeight: owner !== null ? owner.cardHeight : island.height + 2 * island.spreadY
    readonly property real targetRadius: owner !== null ? owner.openRadius : island.height / 2 + island.spreadY
    readonly property real targetTop: owner !== null ? island.top : island.top - island.spreadY
    // The shape it was in when the open card last changed, and how far it has eased from
    // there. It eases from wherever it is, so a card taking over mid-animation never jumps,
    // and then follows the open card's size as that changes (the calendar taking the
    // notifications beside it).
    property real fromWidth: 0
    property real fromHeight: 0
    property real fromRadius: 0
    property real fromCenter: 0
    property real fromTop: 0
    // How far it has gone across and down: past 1 as it bounces.
    property real travelX: 1
    property real travelY: 1
    // How far its middle is from the screen's, and where its top is.
    readonly property real shapeCenter: lerp(fromCenter, island.centerOffset, travelX)
    readonly property real shapeTop: lerp(fromTop, targetTop, travelY)
    // The shape as it would be without going past its size: the bounce is the glass's
    // alone, and what the player carries out of the island keeps to this one.
    readonly property rect steadyShape: {
        const width = lerp(fromWidth, 2 * Math.round(targetWidth / 2), Math.min(1, travelX));
        const top = Math.round(lerp(fromTop, targetTop, Math.min(1, travelY)));
        return Qt.rect(middle - width / 2, top, width, lerp(fromTop + fromHeight, targetTop + targetHeight, Math.min(1, travelY)) - top);
    }
    readonly property real steadyRadius: Math.max(0, lerp(fromRadius, targetRadius, Math.min(1, travelY)))
    // How much the shape shows the island's own content, the time or an OSD: 1 folded on
    // it, 0 a card's. It crosses over with the card's content, quicker than the shape.
    property real islandShare: owner === null ? 1 : 0
    readonly property alias shape: shape
    // The shape's middle on a whole pixel, which it and the content are centred on: each
    // rounded on its own, they took turns rounding the other way as the shape bounced,
    // and the content shook by a pixel inside it.
    readonly property int middle: Math.round(width / 2 + shapeCenter)

    // From a value to another, the given share of the way: the share is passed in so the
    // bindings follow it as it changes.
    function lerp(from, to, share) {
        return from + (to - from) * share;
    }

    // Where a card shows its content: in the shape, on whole pixels (between two,
    // everything drawn in it would shake), but never past the card's own size.
    // Coming from a wider card, the shape is wider than the card for a moment, and what
    // the card lays out beyond its edge (the calendar's notification side, empty) must
    // stay hidden. Never above the island's top either, where the shape starts from the
    // zoomed island: the content stays still while the shape heads to its place.
    // Every card that's out follows it, the one fading out as another takes the island
    // too: left at its own size, it cut the bar's pills out from under itself. The closed
    // ones keep their own size, or every card's content would be laid out again at each
    // step of the island (an OSD).
    function contentRect(card) {
        if (!card.covering)
            return Qt.rect(0, 0, card.cardWidth, card.cardHeight);

        const top = Math.max(shape.y, Math.round(island.top));
        const width = 2 * Math.round(Math.min(shape.width, card.cardWidth) / 2);
        const height = Math.min(shape.y + shape.height - top, card.cardHeight);
        return Qt.rect(middle - width / 2, top, width, height);
    }

    // Where a card stands once open, around the island's middle.
    function openRect(card) {
        return Qt.rect(width / 2 + island.centerOffset - card.cardWidth / 2, island.top, card.cardWidth, card.cardHeight);
    }

    onOpenCardChanged: {
        fromWidth = shape.width;
        fromHeight = shape.height;
        fromRadius = shape.radius;
        fromCenter = shapeCenter;
        fromTop = shapeTop;
        // Unfolding out of the island or folding back onto it bounces; a card taking the
        // island from another glides.
        const unfolds = openCard === null || owner === null;
        travelXAnimation.token = unfolds ? Motion.unfold.width : Motion.unfold.glideWidth;
        travelYAnimation.token = unfolds ? Motion.unfold.height : Motion.unfold.glideHeight;
        owner = openCard;
        if (openCard !== null)
            lastOwner = openCard;

        travelX = 0;
        travelY = 0;
        travelXAnimation.restart();
        travelYAnimation.restart();

    }
    anchors.fill: parent
    // Under the cards' content.
    z: -1
    visible: covering
    pillName: "island"
    covering: owner !== null || travelXAnimation.running || travelYAnimation.running
    cardRect: Qt.rect(shape.x, shape.y, shape.width, shape.height)
    cardRadius: shape.radius

    Item {
        id: shape

        property real radius: Math.max(0, frame.lerp(frame.fromRadius, frame.targetRadius, frame.travelY))

        // The glass alone, so its width moves freely between two pixels: on whole ones
        // its sides stepped, a few times a second as the bounce slows down. It heads to
        // a whole, even width, where its edges are sharp around its middle.
        x: frame.middle - width / 2
        y: Math.round(frame.shapeTop)
        width: frame.lerp(frame.fromWidth, 2 * Math.round(frame.targetWidth / 2), frame.travelX)
        height: frame.lerp(frame.fromHeight, frame.targetHeight, frame.travelY)

        // Same look as the island it grows from: base color at 0.9, blurred, with the
        // glass rim, and lit under the pointer as it folds back onto the island that is.
        GlassSurface {
            radius: shape.radius
            tinted: false
            hovered: frame.owner === null && frame.island.lit
            backgroundColor: Colors.panel
        }

        // A click on the shape stays in it, away from the bar under it, where it's wider
        // than the card shown in it.
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
        }

    }

    // The island's own content (the time and its chips, or an OSD), at its place.
    PillContent {
        pill: frame.bar.islandItem
        active: frame.covering
        share: frame.islandShare
        x: frame.width / 2 + frame.island.centerOffset - frame.island.width / 2
        y: frame.island.top
    }

    Anim {
        id: travelXAnimation

        target: frame
        property: "travelX"
        to: 1
    }

    Anim {
        id: travelYAnimation

        target: frame
        property: "travelY"
        to: 1
    }

    Behavior on islandShare {
        Anim {
            token: Motion.unfold.content
        }

    }

}
