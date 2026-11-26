import QtQuick
import qs.components
import qs.theme

// A spot in the bar for a pill that comes and goes, like the updates or a pill you hide.
// Room opens up, the pill drops in from above and bounces into place; when it leaves,
// it flies back up and the room closes behind it. Put the pill inside as its only child.
// Gone, the pill waits back in its place, out of sight: a card opened with its shortcut
// grows from there. It brings the gap that parts it from the next pill toward the bar's
// middle, which opens and closes with its room: a gap left behind closed at once as the
// room did, and the pills beside it jumped.
Item {
    id: slot

    property bool shown: false
    readonly property Item pill: children.length > 0 ? children[0] : null
    // 0 = no room in the row, 1 = the pill's width and its gap.
    property real room: 0
    // The gap, after the pill on the bar's left, before it on its right.
    property real gap: Metrics.spacing.normal
    property bool gapAfter: true
    // How far above its place the pill is, 0 in place.
    property real lift: 0

    function show() {
        leave.stop();
        // From above, unless it was still on its way out.
        if (room === 0)
            lift = Motion.drop.height;

        enter.restart();
    }

    function hide() {
        enter.stop();
        leave.restart();
    }

    implicitWidth: pill !== null ? (pill.implicitWidth + gap) * room : 0
    implicitHeight: pill !== null ? pill.implicitHeight : 0
    visible: room > 0
    onShownChanged: shown ? show() : hide()
    // Already there when the shell starts: no drop.
    Component.onCompleted: {
        if (shown)
            room = 1;

    }

    Binding {
        target: slot.pill
        property: "y"
        value: -slot.lift
    }

    Binding {
        target: slot.pill
        property: "x"
        value: slot.gapAfter ? 0 : slot.gap * slot.room
    }

    SequentialAnimation {
        id: enter

        Anim {
            target: slot
            property: "room"
            to: 1
            token: Motion.resize.normal
        }

        NumberAnimation {
            target: slot
            property: "lift"
            to: 0
            duration: Motion.drop.fallDuration
            easing.type: Motion.drop.fallEasing
        }

    }

    SequentialAnimation {
        id: leave

        NumberAnimation {
            target: slot
            property: "lift"
            to: Motion.drop.height
            duration: Motion.drop.riseDuration
            easing.type: Motion.drop.riseEasing
        }

        Anim {
            target: slot
            property: "room"
            to: 0
            token: Motion.resize.normal
        }

        PropertyAction {
            target: slot
            property: "lift"
            value: 0
        }

    }

}
