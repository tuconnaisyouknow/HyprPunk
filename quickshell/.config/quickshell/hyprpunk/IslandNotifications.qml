import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Widgets

// New notifications, in a card that grows out of the dynamic island of the screen you're
// on when they arrive. They leave after a few seconds unless hovered or critical, Focus
// keeps all but the critical ones away, they wait while an island panel takes the
// island, and they fold back into it when the notification center opens.
Card {
    id: popups

    required property var screen
    required property var shellState
    // Its screen's bar, whose island it grows out of.
    required property var bar
    // The island's card shape, shared with its other cards.
    required property Item islandFrame
    readonly property rect contentRect: islandFrame.contentRect(popups)
    required property var notificationServer
    // Popups currently in the card, newest first, as {id, notification}. An entry stays
    // here until its exit animation is over, so several popups can leave at the same time.
    // The id is kept apart: a dismissed notification is destroyed but lingers here as an
    // empty object, with no id to tell it by.
    property var notifications: []
    // Ids of the popups playing their exit animation.
    property var leavingIds: []
    // Around the notifications: with their 18px corners, the card's 24px ones line up.
    readonly property int cardPadding: 6
    readonly property int maxVisible: 3
    readonly property int stayingCount: notifications.filter((entry) => {
        return !leavingIds.includes(entry.id);
    }).length
    // A session menu or a picker grown out of the island: the popups wait their turn.
    readonly property bool islandTaken: shellState.islandPanels.some((key) => {
        return key.endsWith("@" + screen.name);
    })
    property real progress: opened ? 1 : 0
    // The card's full height, kept while it folds: shrinking with the last popup's gap,
    // it would flatten into a long empty pill before narrowing.
    property real openHeight: 0
    // Where the island is.
    readonly property var island: bar.islandPill

    function show(notification) {
        // Notifications carried over by a config reload are not new.
        if (notification.lastGeneration)
            return ;

        if (shellState.doNotDisturb && notification.urgency !== NotificationUrgency.Critical)
            return ;

        // Another screen's: each one shows those that arrive while you're on it.
        const focused = Hyprland.focusedMonitor;
        if (focused === null ? screen !== Quickshell.screens[0] : focused.name !== screen.name)
            return ;

        // The notification lands straight in the open center, no need for a popup.
        if (shellState.notificationCenterOpen && shellState.notificationScreen === screen)
            return ;

        const id = notification.id;
        notifications = [{
            "id": id,
            "notification": notification
        }].concat(notifications);
        notification.closed.connect(() => {
            return popups.hide(id);
        });
        // Overflowing popups leave with the regular animation instead of vanishing.
        const staying = notifications.filter((entry) => {
            return !leavingIds.includes(entry.id);
        });
        for (const extra of staying.slice(maxVisible)) hide(extra.id)
    }

    // Starts the exit animation; the entry is dropped once it is finished.
    function hide(id) {
        if (leavingIds.includes(id))
            return ;

        leavingIds = leavingIds.concat([id]);
    }

    // Every popup at once, critical ones too: they're all listed in the open center.
    function hideAll() {
        leavingIds = notifications.map((entry) => {
            return entry.id;
        });
    }

    function drop(id) {
        notifications = notifications.filter((entry) => {
            return entry.id !== id;
        });
        leavingIds = leavingIds.filter((leavingId) => {
            return leavingId !== id;
        });
    }

    anchors.fill: parent
    opened: stayingCount > 0 && !islandTaken
    cardWidth: 400
    cardHeight: openHeight
    // With the notifications' 18px corners inside, the padding's width away.
    openRadius: 18 + cardPadding
    // Gone while they wait, or the folded card would catch the island's clicks.
    visible: opened || progress > 0
    pillName: "island"
    covering: visible
    cardRect: Qt.rect(card.x, card.y, card.width, card.height)
    cardRadius: card.radius

    // Folded with nothing left to show: drops whatever is still leaving, so no stray
    // entry keeps its folded card over the island.
    onProgressChanged: {
        if (progress === 0 && stayingCount === 0) {
            notifications = [];
            leavingIds = [];
        }
    }

    // The last popup's gap below it is the card's bottom padding.
    Binding {
        target: popups
        property: "openHeight"
        value: column.height + popups.cardPadding
        when: popups.opened
        restoreMode: Binding.RestoreNone
    }

    Connections {
        function onNotification(notification) {
            popups.show(notification);
        }

        target: popups.notificationServer
    }

    // The center opening takes the popups in: their card folds back into the island
    // as the center grows out of it, where they're listed anyway, and nothing is left
    // over it once the center closes.
    Connections {
        function onNotificationCenterOpenChanged() {
            if (popups.shellState.notificationCenterOpen)
                popups.hideAll();

        }

        target: popups.shellState
    }

    ClippingRectangle {
        id: card

        // Drawn in the island's shape (IslandFrame), shared with its other cards.
        x: popups.contentRect.x
        y: popups.contentRect.y
        width: popups.contentRect.width
        height: popups.contentRect.height
        radius: popups.islandFrame.shape.radius
        color: "transparent"

        // Holds every popup while you read one of them.
        HoverHandler {
            id: cardHover
        }

        // Laid out at full size, only uncovered while the card grows. It stays put on
        // screen rather than following the card's own rounding.
        Column {
            id: column

            x: Math.round(popups.width / 2 + popups.island.centerOffset - popups.cardWidth / 2) - card.x + popups.cardPadding
            y: popups.cardPadding
            width: popups.cardWidth - 2 * popups.cardPadding
            opacity: popups.opened ? 1 : 0

            Repeater {
                model: ScriptModel {
                    values: popups.notifications
                }

                delegate: Item {
                    id: popup

                    required property var modelData
                    readonly property bool leaving: popups.leavingIds.includes(modelData.id)
                    // Let go as soon as it leaves, before it's destroyed: the card keeps the
                    // last content it saw instead of emptying.
                    readonly property var notification: leaving ? null : modelData.notification
                    readonly property bool critical: notification !== null && notification.urgency === NotificationUrgency.Critical
                    // Share of its slot in the stack.
                    property real slot: 0

                    width: column.width
                    height: (notificationCard.implicitHeight + popups.cardPadding) * slot
                    opacity: 0
                    Component.onCompleted: enterAnimation.start()
                    onLeavingChanged: {
                        if (leaving) {
                            enterAnimation.stop();
                            exitAnimation.start();
                        }
                    }

                    NotificationCard {
                        id: notificationCard

                        width: parent.width
                        notification: popup.notification
                    }

                    Timer {
                        // expireTimeout is in milliseconds: -1 means our default, 0 means never.
                        interval: popup.notification !== null && popup.notification.expireTimeout > 0 ? popup.notification.expireTimeout : 5000
                        running: popup.notification !== null && popups.opened && !cardHover.hovered && !popup.critical && popup.notification.expireTimeout !== 0
                        onTriggered: popups.hide(popup.modelData.id)
                    }

                    // Makes room first, then fades in once the card has opened around it.
                    SequentialAnimation {
                        id: enterAnimation

                        NumberAnimation {
                            target: popup
                            property: "slot"
                            to: 1
                            duration: 220
                            easing.type: Easing.OutCubic
                        }

                        NumberAnimation {
                            target: popup
                            property: "opacity"
                            to: 1
                            duration: 160
                            easing.type: Easing.OutCubic
                        }

                    }

                    SequentialAnimation {
                        id: exitAnimation

                        NumberAnimation {
                            target: popup
                            property: "opacity"
                            to: 0
                            duration: 180
                            easing.type: Easing.InCubic
                        }

                        // Then close the gap so the card shrinks around the others.
                        NumberAnimation {
                            target: popup
                            property: "slot"
                            to: 0
                            duration: 200
                            easing.type: Easing.OutCubic
                        }

                        ScriptAction {
                            script: popups.drop(popup.modelData.id)
                        }

                    }

                }

            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }

            }

        }

    }

    // The card covers the island, so the privacy and recording dots move to its right,
    // following its edge as it grows.
    PrivacyDot {
        x: Math.round(card.x + card.width + 8)
        y: Math.round(popups.island.top + popups.island.height / 2 - height / 2)
        camera: popups.shellState.cameraInUse
        microphone: popups.shellState.microphoneInUse
        recording: popups.shellState.recording
        opacity: active ? popups.progress : 0
        visible: opacity > 0
    }

    Behavior on progress {
        NumberAnimation {
            duration: Theme.cardFold
            easing.type: Easing.OutCubic
        }

    }

}
