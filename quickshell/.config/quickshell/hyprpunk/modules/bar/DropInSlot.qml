import QtQuick
import qs.components
import qs.theme

// A spot in the bar for a pill that comes and goes, like the player or the updates.
// Room opens up, the pill drops in from above and bounces into place; when it leaves,
// it flies back up and the room closes behind it. Put the pill inside as its only child.
Item {
    id: slot

    property bool shown: false
    readonly property Item pill: children.length > 0 ? children[0] : null
    // 0 = no room in the row, 1 = the pill's width.
    property real room: 0
    // How far above its place the pill is, 0 in place.
    property real lift: Motion.drop.height

    function show() {
        leave.stop();
        enter.restart();
    }

    function hide() {
        enter.stop();
        leave.restart();
    }

    implicitWidth: pill !== null ? pill.implicitWidth * room : 0
    implicitHeight: pill !== null ? pill.implicitHeight : 0
    visible: room > 0
    onShownChanged: shown ? show() : hide()
    // Already there when the shell starts: no drop.
    Component.onCompleted: {
        if (shown) {
            room = 1;
            lift = 0;
        }
    }

    Binding {
        target: slot.pill
        property: "y"
        value: -slot.lift
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

    }

}
