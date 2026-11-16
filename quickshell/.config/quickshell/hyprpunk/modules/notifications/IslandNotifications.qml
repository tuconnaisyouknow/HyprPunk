import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs.components
import qs.config
import qs.modules.island
import qs.theme
import qs.services
import qs.state
import qs.windows

// New notifications (Notifications.arrived), in a card that grows out of the dynamic
// island of the screen you're on when they arrive. They leave after the time set in the
// settings unless hovered or critical. They claim the island like a card that comes on its own (ScreenState), so
// they wait while a panel or a prompt holds it, and they fold back into it when the
// notification center opens.
Card {
    id: popups

    required property var screen
    // Its screen's bar, whose island it grows out of.
    required property var bar
    // The island's card shape, shared with its other cards.
    required property Item islandFrame
    readonly property rect contentRect: islandFrame.contentRect(popups)
    // The popups in the card.
    readonly property ExitingEntries popupList: ExitingEntries {
    }
    // The card's margin around the notifications.
    readonly property int cardPadding: Metrics.spacing.small
    readonly property int maxVisible: 3
    readonly property int stayingCount: popupList.staying
    readonly property var screenState: ShellState.forScreen(screen)
    property real progress: opened ? 1 : 0
    // The card's full height, kept while it folds: shrinking with the last popup's gap,
    // it would flatten into a long empty pill before narrowing.
    property real openHeight: 0
    // Where the island is.
    readonly property var island: bar.islandPill
    // The popup being added joins a card that's already out, so it makes its own room in
    // it. The ones a card opens with are whole from the start: the island's shape heads
    // straight to their size, where growing with their room too it first stretched into
    // a flat pill and only then took its height.
    property bool joining: false

    function show(notification) {
        // Another screen's: each one shows those that arrive while you're on it.
        const focused = Hyprland.focusedMonitor;
        if (focused === null ? screen !== Quickshell.screens[0] : focused.name !== screen.name)
            return ;

        // The notification lands straight in the open center, no need for a popup.
        if (screenState?.islandOwner === "notifications")
            return ;

        const id = notification.id;
        joining = opened;
        popupList.add([notification]);
        notification.closed.connect(() => {
            return popupList.leave([id]);
        });
        // Overflowing popups leave with the regular animation instead of vanishing.
        popupList.leave(popupList.entries.filter((entry) => {
            return !popupList.leaving(entry.id);
        }).slice(maxVisible).map((entry) => {
            return entry.id;
        }));
    }

    // Every popup at once, critical ones too: they're all listed in the open center.
    function leaveAll() {
        popupList.leave(popupList.entries.map((entry) => {
            return entry.id;
        }));
    }

    anchors.fill: parent
    opened: stayingCount > 0 && screenState !== null && screenState.islandOwner === "popups"
    cardWidth: 400
    cardHeight: openHeight
    openRadius: Metrics.cardRadius
    // Gone while they wait, or the folded card would catch the island's clicks.
    visible: opened || progress > 0
    pillName: "island"
    covering: visible
    cardRect: Qt.rect(card.x, card.y, card.width, card.height)
    cardRadius: card.radius

    // Wants the island while something stays to show, and gives it back once it's gone.
    onStayingCountChanged: {
        if (stayingCount > 0)
            screenState?.claim("popups", 3);
        else
            screenState?.release("popups");
    }
    Component.onDestruction: screenState?.release("popups")
    // Folded with nothing left to show: drops whatever is still leaving, so no stray
    // entry keeps its folded card over the island.
    onProgressChanged: {
        if (progress === 0 && stayingCount === 0)
            popupList.clear();

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
        function onArrived(notification) {
            popups.show(notification);
        }

        target: Notifications
    }

    // The center opening takes the popups in: their card folds back into the island
    // as the center grows out of it, where they're listed anyway, and nothing is left
    // over it once the center closes.
    Connections {
        function onIslandOwnerChanged() {
            // Once the island has its new owner: giving up their claim while the owner
            // is still changing would change it again from inside the change.
            if (popups.screenState.islandOwner === "notifications")
                Qt.callLater(popups.leaveAll);


        }

        target: popups.screenState
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
                    values: popups.popupList.entries
                }

                delegate: Item {
                    id: popup

                    required property var modelData
                    readonly property bool leaving: popups.popupList.leaving(modelData.id)
                    // Let go as soon as it leaves, before it's destroyed: the card keeps the
                    // last content it saw instead of emptying.
                    readonly property var notification: leaving ? null : modelData.notification
                    readonly property bool critical: notification !== null && notification.urgency === NotificationUrgency.Critical
                    // Share of its slot in the stack.
                    property real slot: 0

                    width: column.width
                    height: (notificationCard.implicitHeight + popups.cardPadding) * slot
                    opacity: 0
                    Component.onCompleted: {
                        if (!popups.joining)
                            slot = 1;

                        enterAnimation.start();
                    }
                    onLeavingChanged: {
                        if (leaving) {
                            enterAnimation.stop();
                            exitAnimation.start();
                        }
                    }

                    NotificationCard {
                        id: notificationCard

                        width: parent.width
                        // Inside the card's padding, its corners parallel to the card's.
                        radius: Metrics.inner(Metrics.cardRadius, popups.cardPadding)
                        notification: popup.notification
                    }

                    Timer {
                        // In milliseconds, -1 when the app leaves it to the settings, 0 for never.
                        readonly property int expireTimeout: popup.notification !== null ? popup.notification.expireTimeout : 0

                        interval: expireTimeout > 0 ? expireTimeout : NotificationSettings.duration * 1000
                        running: interval > 0 && expireTimeout !== 0 && popups.opened && !cardHover.hovered && !popup.critical
                        onTriggered: popups.popupList.leave([popup.modelData.id])
                    }

                    // Makes room first, then fades in once the card has opened around it:
                    // as long after when its room is there from the start.
                    SequentialAnimation {
                        id: enterAnimation

                        Anim {
                            target: popup
                            property: "slot"
                            to: 1
                            token: Motion.resize.normal
                        }

                        Anim {
                            target: popup
                            property: "opacity"
                            to: 1
                            token: Motion.enter.small
                        }

                    }

                    SequentialAnimation {
                        id: exitAnimation

                        Anim {
                            target: popup
                            property: "opacity"
                            to: 0
                            token: Motion.leave.normal
                        }

                        // Then close the gap so the card shrinks around the others.
                        Anim {
                            target: popup
                            property: "slot"
                            to: 0
                            token: Motion.resize.normal
                        }

                        ScriptAction {
                            script: popups.popupList.drop(popup.modelData.id)
                        }

                    }

                }

            }

            Behavior on opacity {
                Anim {
                    token: Motion.color.small
                }

            }

        }

    }

    // The card covers the island, so the privacy and recording dots move to its right,
    // following its edge as it grows.
    PrivacyDot {
        x: Math.round(card.x + card.width + Metrics.spacing.normal)
        y: Math.round(popups.island.top + popups.island.height / 2 - height / 2)
        camera: Privacy.cameraInUse
        microphone: Privacy.microphoneInUse
        recording: Screenshot.recording
        opacity: active ? popups.progress : 0
        visible: opacity > 0
    }

    Behavior on progress {
        Anim {
            token: Motion.resize.large
        }

    }

}
