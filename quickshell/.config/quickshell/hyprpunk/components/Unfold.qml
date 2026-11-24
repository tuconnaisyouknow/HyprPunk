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
    // Out from the moment it opens until it has folded back, bounce included: until the
    // shape is back on the pill. Not from the motions running, which only start once the
    // shape is told to fold, a moment after it's closed.
    readonly property bool out: open || widthProgress !== 0 || heightProgress !== 0 || contentProgress !== 0

    // From a value to another, the given share of the way.
    function lerp(from, to, share) {
        return from + (to - from) * share;
    }

    visible: false

    Behavior on widthProgress {
        Anim {
            token: Motion.unfold.width
        }

    }

    Behavior on heightProgress {
        Anim {
            token: Motion.unfold.height
        }

    }

    Behavior on contentProgress {
        Anim {
            token: Motion.unfold.content
        }

    }

}
