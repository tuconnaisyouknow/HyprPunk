import QtQuick
import Quickshell.Services.Notifications
import qs.components
import qs.config
import qs.theme

// One popup of the stack (Popups): how much of its room it takes and how much it shows,
// the same in every card that draws it, and the time it has before it leaves.
QtObject {
    id: entry

    // The notification's id, kept apart: a closed notification is destroyed.
    required property int key
    // Let go as soon as it leaves, before it's destroyed: the cards keep the last content
    // they saw instead of emptying.
    property var notification
    readonly property bool critical: notification !== null && notification.urgency === NotificationUrgency.Critical
    // Playing its exit, then out of sight with its gap still closing.
    property bool leaving: false
    property bool vanished: false
    // Share of its slot in the stack. A popup that joins a card already out starts with
    // none and makes its own room.
    property real slot: 0
    property real opacity: 0
    readonly property Timer expiry: Timer {
        // In milliseconds, -1 when the app leaves it to the settings, 0 for never.
        readonly property int expireTimeout: entry.notification !== null ? entry.notification.expireTimeout : 0

        interval: expireTimeout > 0 ? expireTimeout : NotificationSettings.duration * 1000
        running: interval > 0 && expireTimeout !== 0 && Popups.out && !Popups.held && !entry.critical
        onTriggered: Popups.leave([entry.key])
    }
    // Makes room first, then fades in once the card has opened around it: as long after
    // when its room is there from the start.
    readonly property SequentialAnimation enterAnimation: SequentialAnimation {
        Anim {
            target: entry
            property: "slot"
            to: 1
            token: Motion.resize.normal
        }

        Anim {
            target: entry
            property: "opacity"
            to: 1
            token: Motion.enter.small
        }

    }
    readonly property SequentialAnimation exitAnimation: SequentialAnimation {
        Anim {
            target: entry
            property: "opacity"
            to: 0
            token: Motion.leave.normal
        }

        // Its room goes to the next one waiting, which opens its own as this one closes:
        // the card keeps its height between the two.
        ScriptAction {
            script: Popups.vanish(entry)
        }

        // Then close the gap so the card shrinks around the others.
        Anim {
            target: entry
            property: "slot"
            to: 0
            token: Motion.resize.normal
        }

        ScriptAction {
            script: Popups.drop(entry)
        }

    }

    function leave() {
        leaving = true;
        notification = null;
        enterAnimation.stop();
        exitAnimation.start();
    }

    Component.onCompleted: enterAnimation.start()
}
