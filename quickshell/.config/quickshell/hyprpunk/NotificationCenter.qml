import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// The notification center, tucked against the right edge. A small handle shows there
// while notifications are waiting: push the pointer against it, or press Super+N,
// and the panel slides out with everything you missed.
PanelWindow {
    id: center

    required property var notificationServer
    required property var shellState
    property bool opened: false
    // Opened with the shortcut: it takes the keyboard so Escape closes it.
    property bool openedByKeybind: false
    property bool panelHovered: false
    property bool edgeHovered: false
    // Opening, the panel slides out of the edge (slide) while stretching from the
    // handle's size to its full height (stretch).
    property real slide: 0
    property real stretch: 0
    property int previousCount: 0
    readonly property int notificationCount: notificationServer.trackedNotifications.values.length
    readonly property var trackedValues: notificationServer.trackedNotifications.values
    // The notifications listed, newest first. A closed one stays until its exit
    // animation is over.
    property var entryIds: []
    property var notificationObjects: ({})
    property var leavingIds: []
    property var clearQueue: []

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
        if (gone.length > 0)
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
    Component.onCompleted: syncEntries()

    onOpenedChanged: {
        if (opened) {
            closeAnimation.stop();
            openAnimation.restart();
        } else {
            openAnimation.stop();
            closeAnimation.restart();
        }
        if (opened) {
            shellState.notificationScreen = screen;
            shellState.notificationCenterOpen = true;
            panel.forceActiveFocus();
        } else {
            openedByKeybind = false;
            if (shellState.notificationScreen === screen)
                shellState.notificationCenterOpen = false;

        }
    }
    onNotificationCountChanged: {
        if (notificationCount > previousCount)
            indicatorPulse.restart();

        previousCount = notificationCount;
    }
    implicitWidth: 420
    color: "transparent"
    WlrLayershell.namespace: "hyprpunk-notification-center"
    WlrLayershell.keyboardFocus: opened && openedByKeybind ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusiveZone: 0

    anchors {
        top: true
        right: true
        bottom: true
    }

    // Discreet handle on the screen edge, shown while notifications are waiting.
    Rectangle {
        id: indicator

        x: center.width - width - 2
        // The window starts below the bar, so center on the screen rather than on the window.
        y: center.height - center.screen.height / 2 - height / 2
        width: 4
        height: 44
        radius: 2
        color: Theme.mauve
        opacity: center.notificationCount > 0 && !center.opened ? (center.shellState.doNotDisturb ? 0.35 : 0.9) : 0

        SequentialAnimation {
            id: indicatorPulse

            NumberAnimation {
                target: indicator
                property: "height"
                to: 76
                duration: 220
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: indicator
                property: "height"
                to: 44
                duration: 420
                easing.type: Easing.OutBack
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 220
            }

        }

    }

    Item {
        id: hotEdge

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 80
        width: 3
        // Leave the top-right corner to the control center and the bottom-right one to the tray.
        height: parent.height - 160

        HoverHandler {
            onHoveredChanged: {
                center.edgeHovered = hovered;
                if (hovered) {
                    closeDelay.stop();
                    edgePushDelay.restart();
                } else {
                    edgePushDelay.stop();
                    closeDelay.restart();
                }
            }
        }

    }

    Connections {
        function onPanelRequestsChanged() {
            const action = center.shellState.requestedAction("notifications", center.screen);
            if (action === "")
                return ;

            const open = action === "open" || (action === "toggle" && !center.opened);
            edgePushDelay.stop();
            closeDelay.stop();
            if (open)
                center.openedByKeybind = true;

            center.opened = open;
        }

        target: center.shellState
    }

    Item {
        id: panel

        // Equal margins keep the panel centred in the space left free by the bar.
        readonly property real fullHeight: center.height - 86
        readonly property real handleHeight: 120
        readonly property real handleTop: indicator.y + indicator.height / 2 - handleHeight / 2

        x: center.width + 4 - (width + 4) * center.slide
        y: handleTop + (43 - handleTop) * center.stretch
        width: 420
        height: handleHeight + (fullHeight - handleHeight) * center.stretch
        focus: true
        Keys.onEscapePressed: center.opened = false

        HoverHandler {
            onHoveredChanged: {
                center.panelHovered = hovered;
                if (hovered)
                    closeDelay.stop();
                else
                    closeDelay.restart();
            }
        }

        // Stuck to the right edge: curving into it, rounded on the left, with the same
        // background as the other cards and the glass rim along the free edge.
        GlassEdgeShape {
            readonly property real w: panel.width
            readonly property real h: panel.height
            readonly property string freeEdge: "M " + w + " 0 " + "C " + w + " 13 " + (w - 11) + " 24 " + (w - 24) + " 24 " + "L 24 24 " + "C 11 24 1 35 1 48 " + "L 1 " + (h - 48) + " " + "C 1 " + (h - 35) + " 11 " + (h - 24) + " 24 " + (h - 24) + " " + "L " + (w - 24) + " " + (h - 24) + " " + "C " + (w - 11) + " " + (h - 24) + " " + w + " " + (h - 13) + " " + w + " " + h

            anchors.fill: parent
            fillColor: Theme.panel
            fillPath: freeEdge + " L " + w + " 0"
            rimPath: freeEdge
        }

        Item {
            id: contentClip

            anchors.fill: parent
            clip: true

            // Laid out once at full size, only uncovered while the panel stretches.
            Item {
                y: 43 - panel.y
                width: panel.width
                height: panel.fullHeight

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 14
                    anchors.topMargin: 38
                    anchors.bottomMargin: 38
                    spacing: 14

                    RowLayout {
                        id: header

                        property real intro: 1

                        Layout.fillWidth: true
                        opacity: intro

                        transform: Translate {
                            x: (1 - header.intro) * 48
                        }

                        IconText {
                            Layout.fillWidth: true
                            icon: "󰂚"
                            text: "Notifications"
                            color: Theme.mauve
                            font.pixelSize: 18
                            font.weight: Font.Bold
                        }

                        Rectangle {
                            implicitWidth: clearLabel.implicitWidth + 18
                            implicitHeight: 34
                            radius: 12
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
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }

                            HoverHandler {
                                id: clearHover

                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                onTapped: center.clearAll()
                            }

                        }

                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        // The gap is part of each entry, so it closes with the exit animation.
                        spacing: 0
                        clip: true

                        model: ScriptModel {
                            values: center.entryIds
                        }

                        IconText {
                            anchors.centerIn: parent
                            visible: center.entryIds.length === 0
                            icon: "󰂚"
                            text: "No notifications"
                            color: Theme.overlay1
                            font.pixelSize: 16
                            font.weight: Font.Normal
                        }

                        delegate: Item {
                            id: entry

                            required property int modelData
                            required property int index
                            readonly property int notificationId: modelData
                            readonly property bool leaving: center.leavingIds.includes(notificationId)
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
                                        return center.drop(id);
                                    });
                                }
                            }

                            NotificationCard {
                                id: card

                                x: entry.slide + swipeOffset
                                width: parent.width
                                // Looked up once: the object is destroyed while the card leaves.
                                notification: center.notificationObjects[entry.notificationId] ?? null
                                onSwipedAway: {
                                    entry.slide += swipeOffset;
                                    swipeOffset = 0;
                                }
                            }

                            transform: Translate {
                                x: (1 - entry.intro) * 48
                            }

                            Connections {
                                function onOpenedChanged() {
                                    if (center.opened)
                                        entryIntro.restart();

                                }

                                target: center
                            }

                            // Cards come in one after another, after the header.
                            SequentialAnimation {
                                id: entryIntro

                                PropertyAction {
                                    target: entry
                                    property: "intro"
                                    value: 0
                                }

                                PauseAnimation {
                                    duration: 185 + Math.min(entry.index, 6) * 45
                                }

                                NumberAnimation {
                                    target: entry
                                    property: "intro"
                                    to: 1
                                    duration: 380
                                    easing.type: Easing.OutCubic
                                }

                            }

                            // Same exit as the popups: slide out to the right, then close the gap.
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
                                    script: center.drop(entry.notificationId)
                                }

                            }

                        }

                    }

                }

            }

        }

    }

    ParallelAnimation {
        id: openAnimation

        NumberAnimation {
            target: center
            property: "slide"
            to: 1
            duration: 320
            easing.type: Easing.OutCubic
        }

        SequentialAnimation {
            PauseAnimation {
                duration: 40
            }

            NumberAnimation {
                target: center
                property: "stretch"
                to: 1
                duration: 480
                easing.type: Easing.OutQuint
            }

        }

        SequentialAnimation {
            PropertyAction {
                target: contentClip
                property: "opacity"
                value: 1
            }

            PropertyAction {
                target: header
                property: "intro"
                value: 0
            }

            PauseAnimation {
                duration: 140
            }

            NumberAnimation {
                target: header
                property: "intro"
                to: 1
                duration: 380
                easing.type: Easing.OutCubic
            }

        }

    }

    // The content fades, the panel folds back into the edge handle and leaves.
    ParallelAnimation {
        id: closeAnimation

        NumberAnimation {
            target: contentClip
            property: "opacity"
            to: 0
            duration: 120
        }

        NumberAnimation {
            target: center
            property: "stretch"
            to: 0
            duration: 280
            easing.type: Easing.InOutCubic
        }

        SequentialAnimation {
            PauseAnimation {
                duration: 90
            }

            NumberAnimation {
                target: center
                property: "slide"
                to: 0
                duration: 230
                easing.type: Easing.InCubic
            }

        }

    }

    Timer {
        id: clearStep

        interval: 70
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (center.clearQueue.length === 0) {
                stop();
                return ;
            }
            const id = center.clearQueue[0];
            center.clearQueue = center.clearQueue.slice(1);
            const notification = center.notificationObjects[id];
            if (notification)
                notification.dismiss();

        }
    }

    Timer {
        id: edgePushDelay

        interval: 170
        onTriggered: center.opened = true
    }

    Timer {
        id: closeDelay

        interval: 420
        onTriggered: {
            if (!center.edgeHovered && !center.panelHovered)
                center.opened = false;

        }
    }

    mask: Region {
        Region {
            item: hotEdge
        }

        Region {
            item: panel
        }

    }

}
