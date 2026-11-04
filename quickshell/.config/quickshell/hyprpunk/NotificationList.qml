import QtQuick
import QtQuick.Layouts
import Quickshell

// Every notification still waiting, newest first, with a button to clear them all.
// It sits next to the calendar, in the card that grows out of the island.
ColumnLayout {
    id: list

    required property var notificationServer
    // The card is open: the notifications come in one after another each time it opens.
    property bool shown: false
    readonly property var trackedValues: notificationServer.trackedNotifications.values
    // The notifications listed. A closed one stays until its exit animation is over.
    property var entryIds: []
    property var notificationObjects: ({})
    property var leavingIds: []
    property var clearQueue: []
    // Waiting, not counting the ones on their way out.
    readonly property int count: entryIds.length - leavingIds.length

    // Dismisses the notifications one after another, from top to bottom.
    function clearAll() {
        clearQueue = entryIds.filter((id) => {
            return !leavingIds.includes(id);
        });
        clearStep.restart();
    }

    function syncEntries() {
        const tracked = trackedValues;
        const trackedIds = tracked.map((notification) => {
            return notification.id;
        });
        const fresh = tracked.filter((notification) => {
            return !entryIds.includes(notification.id);
        });
        if (fresh.length > 0) {
            const objects = Object.assign({}, notificationObjects);
            for (const notification of fresh) objects[notification.id] = notification
            notificationObjects = objects;
            entryIds = fresh.map((notification) => {
                return notification.id;
            }).reverse().concat(entryIds);
        }
        const gone = entryIds.filter((id) => {
            return !trackedIds.includes(id) && !leavingIds.includes(id);
        });
        // Hidden, the card draws no frames and its animations stand still: they would
        // all play at once the next time it opens. The ones closed meanwhile just go.
        if (!shown)
            for (const id of gone) drop(id)
        else if (gone.length > 0)
            leavingIds = leavingIds.concat(gone);
    }

    function drop(id) {
        entryIds = entryIds.filter((entryId) => {
            return entryId !== id;
        });
        leavingIds = leavingIds.filter((leavingId) => {
            return leavingId !== id;
        });
        const objects = Object.assign({}, notificationObjects);
        delete objects[id];
        notificationObjects = objects;
    }

    onTrackedValuesChanged: syncEntries()
    // Closing the card: the ones still leaving go at once, for the same reason.
    onShownChanged: {
        if (!shown)
            for (const id of leavingIds.slice()) drop(id)
    }
    Component.onCompleted: syncEntries()
    spacing: 12

    RowLayout {
        Layout.fillWidth: true

        IconText {
            Layout.fillWidth: true
            icon: "󰂚"
            text: "Notifications"
            color: Theme.mauve
            font.pixelSize: 16
            font.weight: Font.Bold
        }

        Rectangle {
            implicitWidth: clearLabel.implicitWidth + 18
            implicitHeight: 30
            radius: 11
            color: "transparent"

            // Mauve glass.
            GlassSurface {
                radius: parent.radius
                hovered: clearHover.hovered
                backgroundColor: Theme.alpha(Theme.mauve, clearHover.hovered ? 0.95 : 0.8)
            }

            IconText {
                id: clearLabel

                anchors.centerIn: parent
                icon: "󰎟"
                text: "Clear"
                color: Theme.base
                font.pixelSize: 13
                font.weight: Font.Bold
            }

            HoverHandler {
                id: clearHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: list.clearAll()
            }

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
            values: list.entryIds
        }

        delegate: Item {
            id: entry

            required property int modelData
            required property int index
            readonly property int notificationId: modelData
            readonly property bool leaving: list.leavingIds.includes(notificationId)
            // Card offset from its resting place, and share of its slot in the list.
            property real slide: 0
            property real slot: 1
            property real intro: 1

            width: ListView.view.width
            opacity: intro
            height: (card.implicitHeight + 10) * slot
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
                // Looked up once: the object is destroyed while the card leaves.
                notification: list.notificationObjects[entry.notificationId] ?? null
            }

            transform: Translate {
                y: (1 - entry.intro) * -16
            }

            Connections {
                function onShownChanged() {
                    if (list.shown)
                        entryIntro.restart();

                }

                target: list
            }

            // Cards come in one after another, once the card has opened.
            SequentialAnimation {
                id: entryIntro

                PropertyAction {
                    target: entry
                    property: "intro"
                    value: 0
                }

                PauseAnimation {
                    duration: 140 + Math.min(entry.index, 6) * 45
                }

                NumberAnimation {
                    target: entry
                    property: "intro"
                    to: 1
                    duration: 320
                    easing.type: Easing.OutCubic
                }

            }

            // Slides out to the right, then closes the gap.
            SequentialAnimation {
                id: exitAnimation

                NumberAnimation {
                    target: entry
                    property: "slide"
                    to: entry.width + 24
                    duration: 200
                    easing.type: Easing.InCubic
                }

                NumberAnimation {
                    target: entry
                    property: "slot"
                    to: 0
                    duration: 180
                    easing.type: Easing.OutCubic
                }

                ScriptAction {
                    script: list.drop(entry.notificationId)
                }

            }

        }

    }

    Timer {
        id: clearStep

        interval: 70
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (list.clearQueue.length === 0) {
                stop();
                return ;
            }
            const id = list.clearQueue[0];
            list.clearQueue = list.clearQueue.slice(1);
            const notification = list.notificationObjects[id];
            if (notification)
                notification.dismiss();

        }
    }

}
