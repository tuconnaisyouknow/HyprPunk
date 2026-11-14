import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.theme
import qs.services

// Every notification still waiting, newest first, with a button to clear them all.
// It sits next to the calendar, in the card that grows out of the island.
ColumnLayout {
    id: list

    // The card is open: only then do closed notifications animate out.
    property bool shown: false
    // The notifications listed, newest first.
    readonly property ExitingEntries listed: ExitingEntries {
    }
    property var clearQueue: []
    // Waiting, not counting the ones on their way out.
    readonly property int count: listed.staying
    // The ones already slid out of sight, their gap still closing.
    property var slidOutIds: []
    // Still in sight, those sliding out included: the card only narrows once the last one
    // has slid out, or the calendar would come sliding in under it.
    readonly property int shownCount: listed.entries.length - slidOutIds.length

    // Dismisses the notifications one after another, from top to bottom.
    function clearAll() {
        clearQueue = listed.entries.filter((entry) => {
            return !listed.leaving(entry.id);
        });
        clearStep.restart();
    }

    function sync() {
        const waiting = Notifications.waiting;
        const ids = waiting.map((notification) => {
            return notification.id;
        });
        listed.add(waiting.filter((notification) => {
            return !listed.includes(notification.id);
        }).reverse());
        const gone = listed.entries.filter((entry) => {
            return !ids.includes(entry.id) && !listed.leaving(entry.id);
        }).map((entry) => {
            return entry.id;
        });
        // Hidden, the card draws no frames and its animations stand still: they would
        // all play at once the next time it opens. The ones closed meanwhile just go.
        if (!shown)
            for (const id of gone) drop(id)
        else
            listed.leave(gone);
    }

    function drop(id) {
        listed.drop(id);
        slidOutIds = slidOutIds.filter((slidId) => {
            return slidId !== id;
        });
    }

    // Closing the card: the ones still leaving go at once, for the same reason.
    onShownChanged: {
        if (!shown)
            for (const id of listed.leavingIds.slice()) drop(id)
    }
    Component.onCompleted: sync()
    spacing: Metrics.spacing.large

    Connections {
        function onWaitingChanged() {
            list.sync();
        }

        target: Notifications
    }

    RowLayout {
        Layout.fillWidth: true

        IconText {
            Layout.fillWidth: true
            icon: "󰂚"
            text: "Notifications"
            color: Colors.primary
            font.pixelSize: Metrics.text.title
            font.weight: Font.Bold
        }

        GlassButton {
            icon: "󰎟"
            label: "Clear"
            accent: true
            onClicked: list.clearAll()
        }

    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        // The gap is part of each entry, so it closes with the exit animation.
        spacing: 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        model: ScriptModel {
            values: list.listed.entries
        }

        delegate: Item {
            id: entry

            required property var modelData
            readonly property int notificationId: modelData.id
            readonly property bool leaving: list.listed.leaving(notificationId)
            // Card offset from its resting place, and share of its slot in the list.
            property real slide: 0
            property real slot: 1

            width: ListView.view.width
            height: (card.implicitHeight + Metrics.spacing.normal) * slot
            Component.onCompleted: {
                if (leaving)
                    exitAnimation.start();

            }
            onLeavingChanged: {
                if (leaving)
                    exitAnimation.start();

            }
            // A card scrolled out of view is destroyed before its animation ends.
            Component.onDestruction: {
                if (leaving) {
                    const id = notificationId;
                    Qt.callLater(() => {
                        return list.drop(id);
                    });
                }
            }

            NotificationCard {
                id: card

                x: entry.slide
                width: parent.width
                // Let go as it leaves, before it's destroyed: the card keeps what it showed.
                notification: entry.leaving ? null : entry.modelData.notification
            }

            // Slides out to the right, then closes the gap.
            SequentialAnimation {
                id: exitAnimation

                // Past the list's edge, its glass's glow with it.
                Anim {
                    target: entry
                    property: "slide"
                    to: entry.width + Metrics.spacing.section
                    token: Motion.leave.normal
                }

                ScriptAction {
                    script: list.slidOutIds = list.slidOutIds.concat([entry.notificationId])
                }

                Anim {
                    target: entry
                    property: "slot"
                    to: 0
                    token: Motion.resize.normal
                }

                ScriptAction {
                    script: list.drop(entry.notificationId)
                }

            }

        }

    }

    Timer {
        id: clearStep

        interval: Motion.stagger
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (list.clearQueue.length === 0) {
                stop();
                return ;
            }
            const entry = list.clearQueue[0];
            list.clearQueue = list.clearQueue.slice(1);
            // Still there: not closed by its app meanwhile.
            if (entry.notification && !list.listed.leaving(entry.id))
                entry.notification.dismiss();

        }
    }

}
