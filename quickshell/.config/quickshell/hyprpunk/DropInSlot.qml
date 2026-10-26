import QtQuick

// Holds a pill that comes and goes (the player, the updates): its room opens in the
// row, then it drops in from the top of the screen and bounces into place; leaving,
// it flies back up before its room closes. The pill is the slot's only child.
Item {
    id: slot

    property bool shown: false
    readonly property Item pill: children.length > 0 ? children[0] : null
    // 0 = no room in the row, 1 = the pill's width.
    property real room: 0
    // How far above its place the pill is, 0 in place: high enough to be off screen.
    property real lift: 60

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

        NumberAnimation {
            target: slot
            property: "room"
            to: 1
            duration: 220
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: slot
            property: "lift"
            to: 0
            duration: 700
            easing.type: Easing.OutBounce
        }

    }

    SequentialAnimation {
        id: leave

        NumberAnimation {
            target: slot
            property: "lift"
            to: 60
            duration: 300
            easing.type: Easing.InBack
        }

        NumberAnimation {
            target: slot
            property: "room"
            to: 0
            duration: 220
            easing.type: Easing.InOutCubic
        }

    }

}
