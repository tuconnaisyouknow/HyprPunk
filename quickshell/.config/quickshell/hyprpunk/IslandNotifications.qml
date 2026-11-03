import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland
import Quickshell.Widgets

// New notifications, in a card that grows out of the dynamic island on the focused
// screen. They leave after a few seconds unless hovered or critical, Focus keeps all but
// the critical ones away, and they wait while an island panel takes the island.
PanelWindow {
    id: popups

    required property var shellState
    required property var notificationServer
    // Popups currently in the card, newest first, as {id, notification}. An entry stays
    // here until its exit animation is over, so several popups can leave at the same time.
    // The id is kept apart: a dismissed notification is destroyed but lingers here as an
    // empty object, with no id to tell it by.
    property var notifications: []
    // Ids of the popups playing their exit animation.
    property var leavingIds: []
    readonly property int cardWidth: 400
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
    readonly property bool opened: stayingCount > 0 && !islandTaken
    property real progress: opened ? 1 : 0
    // The card's full height, kept while it folds: shrinking with the last popup's gap,
    // it would flatten into a long empty pill before narrowing.
    property real openHeight: 0
    // Geometry of the island (the clock pill), published by the bar.
    readonly property var island: shellState.islandPill

    function lerp(from, to) {
        return from + (to - from) * progress;
    }

    function show(notification) {
        // Notifications carried over by a config reload are not new.
        if (notification.lastGeneration)
            return ;

        if (shellState.doNotDisturb && notification.urgency !== NotificationUrgency.Critical)
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

    function drop(id) {
        notifications = notifications.filter((entry) => {
            return entry.id !== id;
        });
        leavingIds = leavingIds.filter((leavingId) => {
            return leavingId !== id;
        });
    }

    screen: {
        const monitor = Hyprland.focusedMonitor;
        for (const screen of Quickshell.screens) {
            if (monitor !== null && screen.name === monitor.name)
                return screen;

        }
        return Quickshell.screens[0];
    }
    // Kept while the last popups fade and the card folds back onto the island. Gone while
    // they wait, or the folded card would catch the island's clicks.
    visible: opened || progress > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    // Above the bar, whose island the card covers. Never takes the keyboard.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hyprpunk-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Folded with nothing left to show: drops whatever is still leaving, so no stray
    // entry keeps the window, and its folded card, over the island.
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

    ClippingRectangle {
        id: card

        // On whole pixels, like the content below: half pixels while the card grows make
        // everything in it shake.
        x: Math.round(popups.width / 2 + popups.island.centerOffset - width / 2)
        y: popups.island.top
        width: popups.lerp(popups.island.width, popups.cardWidth)
        height: popups.lerp(popups.island.height, popups.openHeight)
        radius: popups.lerp(popups.island.height / 2, 18 + popups.cardPadding)
        color: "transparent"

        // Same look as the island it grows from: base color at 0.9, blurred, with the glass rim.
        GlassSurface {
            radius: card.radius
            tinted: false
            backgroundColor: Theme.panel
        }

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
            duration: 280
            easing.type: Easing.OutCubic
        }

    }

    // Only the card catches the pointer, the rest of the screen stays yours.
    mask: Region {
        item: card
    }

}
