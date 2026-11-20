import QtQuick
import qs.theme

// How a card that draws its own shape unfolds out of its pill and folds back onto it
// (Motion.unfold): its width and its height each on their own, going past and coming
// back, and its content taking the pill's place quicker. The cards of the island share
// one shape, which moves the same way (IslandFrame).
Item {
    id: unfold

    property bool open: false
    // From 0 on the pill to 1 open, a little past either end as it bounces.
    property real widthProgress: open ? 1 : 0
    property real heightProgress: open ? 1 : 0
    // From 0 the pill's content to 1 the card's.
    property real contentProgress: open ? 1 : 0
    // Out from the moment it opens until it has folded back, bounce included.
    readonly property bool out: open || widthMotion.running || heightMotion.running || contentMotion.running

    // From a value to another, the given share of the way.
    function lerp(from, to, share) {
        return from + (to - from) * share;
    }

    visible: false

    Behavior on widthProgress {
        Anim {
            id: widthMotion

            token: Motion.unfold.width
        }

    }

    Behavior on heightProgress {
        Anim {
            id: heightMotion

            token: Motion.unfold.height
        }

    }

    Behavior on contentProgress {
        Anim {
            id: contentMotion

            token: Motion.unfold.content
        }

    }

}
