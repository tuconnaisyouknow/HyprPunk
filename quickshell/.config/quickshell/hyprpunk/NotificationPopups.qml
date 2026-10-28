import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland

PanelWindow {
    id: popups

    required property var shellState
    required property var notificationServer
    // Popups currently on screen, newest first. An entry stays here until its
    // exit animation is over, so several popups can leave at the same time.
    property var notifications: []
    // Ids of the popups playing their exit animation.
    property var leavingIds: []
    readonly property int cardWidth: 380
    readonly property int cardSpacing: 10
    readonly property int maxVisible: 4
    // Height of the open control center on this screen, follows its animation.
    readonly property real controlCenterBottom: shellState.controlCenterBottomScreen === screen ? shellState.controlCenterBottom : 0

    function show(notification) {
        // Notifications carried over by a config reload are not new.
        if (notification.lastGeneration)
            return ;

        if (shellState.doNotDisturb && notification.urgency !== NotificationUrgency.Critical)
            return ;

        // The notification lands straight in the open center, no need for a popup.
        if (shellState.notificationCenterOpen && shellState.notificationScreen === screen)
            return ;

        notifications = [notification].concat(notifications);
        notification.closed.connect(() => {
            return popups.hide(notification);
        });
        // Overflowing popups leave with the regular animation instead of vanishing.
        const staying = notifications.filter((item) => {
            return item !== null && !leavingIds.includes(item.id);
        });
        for (const extra of staying.slice(maxVisible)) hide(extra)
    }

    // Starts the exit animation; the entry is dropped once it is finished.
    function hide(notification) {
        if (notification === null || leavingIds.includes(notification.id))
            return ;

        leavingIds = leavingIds.concat([notification.id]);
    }

    function drop(id) {
        notifications = notifications.filter((item) => {
            return item !== null && item.id !== id;
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
    visible: notifications.length > 0
    implicitWidth: cardWidth + 72
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.namespace: "hyprpunk-notifications"

    // Always full height: resizing the window while popups move glitches, and the stack
    // needs room when the control center pushes it down.
    anchors {
        top: true
        right: true
        bottom: true
    }

    Connections {
        function onNotification(notification) {
            popups.show(notification);
        }

        target: popups.notificationServer
    }

    Column {
        id: column

        // Lined up with the windows' borders, 10px from the screen's edge and from the bar
        // like Hyprland's gaps_out, with room on the left for the bounce overshoot. The
        // window starts below the bar, and the control center starts at the screen top.
        x: popups.width - width - 10
        y: Math.max(10, popups.controlCenterBottom - (popups.screen.height - popups.height) + 8)
        width: popups.cardWidth

        Repeater {
            model: ScriptModel {
                values: popups.notifications
            }

            delegate: Item {
                id: popup

                required property var modelData
                // Captured once: the notification object may be destroyed while leaving.
                property int notificationId: -1
                readonly property bool leaving: popups.leavingIds.includes(notificationId)
                readonly property bool critical: modelData !== null && modelData.urgency === NotificationUrgency.Critical
                // Card offset from its resting place, and share of its slot in the stack.
                property real slide: popups.cardWidth + 24
                property real slot: 0

                width: column.width
                height: (card.implicitHeight + popups.cardSpacing) * slot
                Component.onCompleted: {
                    notificationId = modelData.id;
                    enterAnimation.start();
                }
                onLeavingChanged: {
                    if (leaving) {
                        enterAnimation.stop();
                        exitAnimation.start();
                    }
                }

                NotificationCard {
                    id: card

                    x: popup.slide + swipeOffset
                    width: parent.width
                    notification: popup.modelData
                    // Floating over the desktop, with the same base as the windows (0.9) and the blur behind.
                    backgroundColor: Theme.panel
                    onSwipedAway: {
                        popup.slide += swipeOffset;
                        swipeOffset = 0;
                    }
                }

                HoverHandler {
                    id: popupHover
                }

                Timer {
                    // expireTimeout is in milliseconds: -1 means our default, 0 means never.
                    interval: popup.modelData !== null && popup.modelData.expireTimeout > 0 ? popup.modelData.expireTimeout : 5000
                    running: popup.modelData !== null && !popup.leaving && !popupHover.hovered && !popup.critical && popup.modelData.expireTimeout !== 0
                    onTriggered: popups.hide(popup.modelData)
                }

                ParallelAnimation {
                    id: enterAnimation

                    NumberAnimation {
                        target: popup
                        property: "slot"
                        to: 1
                        duration: 180
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: popup
                        property: "slide"
                        to: 0
                        duration: 420
                        easing.type: Easing.OutBack
                        // ~15px past the resting place before settling back.
                        easing.overshoot: 1
                    }

                }

                SequentialAnimation {
                    id: exitAnimation

                    NumberAnimation {
                        target: popup
                        property: "slide"
                        to: popups.cardWidth + 24
                        duration: 200
                        easing.type: Easing.InCubic
                    }

                    // Then close the gap so the popups below glide up.
                    NumberAnimation {
                        target: popup
                        property: "slot"
                        to: 0
                        duration: 180
                        easing.type: Easing.OutCubic
                    }

                    ScriptAction {
                        script: popups.drop(popup.notificationId)
                    }

                }

            }

        }

    }

    mask: Region {
        item: column
    }

}
