import QtQuick
import qs.modules.island
import qs.theme

// While a card is open on the island, its OSD shows here instead, on the card's
// left (the privacy dots take its right). An OSD that starts then drops in, and
// flies back up once over, like the bar's pills that come and go (DropInSlot). The
// one the island was showing comes out of it as a card opens, and goes back into it
// as the card folds onto it, so there's only ever one: drawn over the cards, its
// glass fades as it enters and its content lands where the island shows the same.
Item {
    id: sideOsd

    required property var bar

    readonly property Item frame: sideOsd.bar.islandFrame
    // Off screen above the bar, 0 in place.
    property real lift: Motion.drop.height
    // Beside the card, or in the middle of the island's shape (IslandFrame.islandShare).
    // Only while it shows: over, it has nothing to bring into the island.
    readonly property real besideX: frame.shape.x - Metrics.spacing.normal - width
    readonly property real insideX: frame.shape.x + (frame.shape.width - width) / 2

    // The OSD starts or ends: it drops in beside a card or flies away from it. In the
    // island, it's in place for a card that opens over it.
    function follow() {
        sideOsdEnter.stop();
        sideOsdLeave.stop();
        sideOsdSettle.stop();
        if (sideOsd.bar.osdVisible) {
            if (frame.owner !== null)
                sideOsdEnter.restart();
            else
                lift = 0;
        } else {
            if (visible)
                sideOsdLeave.restart();
            else
                lift = Motion.drop.height;
        }
    }

    // The card starts folding back. Still showing, the OSD goes into the island with
    // it: it settles in line with the island in the first half, before it reaches
    // the card's content, and lands where the island shows it. Already over and
    // flying off, it stops and fades where it is.
    function fold() {
        sideOsdEnter.stop();
        sideOsdLeave.stop();
        if (sideOsd.bar.osdVisible)
            sideOsdSettle.restart();

    }

    x: Math.round(besideX + (insideX - besideX) * (sideOsd.bar.osdVisible ? frame.islandShare : 0))
    y: Math.round(frame.islandMiddle - height / 2 - lift)
    width: sideOsdPill.width
    height: sideOsdPill.height
    // Only over a card: in the island, the island shows it.
    visible: (sideOsd.bar.osdVisible || lift < Motion.drop.height) && sideOsd.bar.islandCovered && !sideOsd.bar.sessionLocked
    // Over, it fades beside the card in the first half of its folding back (fold),
    // never crossing what the card still shows.
    opacity: sideOsd.bar.osdVisible ? 1 : Math.max(0, 1 - 2 * frame.islandShare)
    // Gone into the island or flown off: ready to come out of the island, or to
    // drop in from above for the next OSD.
    onVisibleChanged: {
        if (visible)
            return ;

        sideOsdEnter.stop();
        sideOsdLeave.stop();
        sideOsdSettle.stop();
        lift = sideOsd.bar.osdVisible ? 0 : Motion.drop.height;
    }

    Pill {
        id: sideOsdPill

        horizontalPadding: Metrics.islandOsdPadding
        glassOpacity: 1 - sideOsd.frame.islandShare

        // Still showing as it flies away: the OSD is already over.
        IslandOsd {
            shown: true
            content: sideOsd.bar.osdShown
        }

    }

    NumberAnimation {
        id: sideOsdEnter

        target: sideOsd
        property: "lift"
        to: 0
        duration: Motion.drop.fallDuration
        easing.type: Motion.drop.fallEasing
    }

    Connections {
        function onOwnerChanged() {
            if (sideOsd.frame.owner === null)
                sideOsd.fold();

        }

        target: sideOsd.frame
    }

    NumberAnimation {
        id: sideOsdSettle

        target: sideOsd
        property: "lift"
        to: 0
        // The first half of the card's folding back.
        duration: Motion.resize.large.duration / 2
        easing.type: Motion.resize.large.easing
    }

    NumberAnimation {
        id: sideOsdLeave

        target: sideOsd
        property: "lift"
        to: Motion.drop.height
        duration: Motion.drop.riseDuration
        easing.type: Motion.drop.riseEasing
    }

}
