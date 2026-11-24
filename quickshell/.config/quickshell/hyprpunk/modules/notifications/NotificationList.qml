import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.theme
import qs.services
import qs.state

// Every notification still waiting, newest first, under a button to clear them all: the
// ones in view leave one after another, the rest just goes. Focus's switch closes it.
// It sits next to the calendar, in the card that grows out of the island, and stays
// there empty, so Focus is always at hand.
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
    // While the ones out of view are dismissed together: they're already off the list,
    // and going through it again for each would stall a long one.
    property bool dismissing: false

    // Dismisses the notifications in view one after another, from top to bottom. The
    // others have no exit to show, and waiting for each would never end: they just go.
    function clearAll() {
        const entries = listed.entries;
        const first = view.indexAt(0, view.contentY);
        if (first < 0)
            return ;

        // Nothing under the view's bottom edge: the list ends inside it.
        const atBottom = view.indexAt(0, view.contentY + view.height - 1);
        const last = atBottom < 0 ? entries.length - 1 : atBottom;
        const staying = (entry) => {
            return !listed.leaving(entry.id);
        };
        const outOfView = entries.slice(0, first).concat(entries.slice(last + 1));
        const toDismiss = outOfView.filter(staying);
        clearQueue = entries.slice(first, last + 1).filter(staying);
        listed.drop(outOfView.map((entry) => {
            return entry.id;
        }));
        dismissing = true;
        for (const entry of toDismiss) entry.notification.dismiss()
        dismissing = false;
        clearStep.restart();
    }

    function sync() {
        const waiting = Notifications.waiting;
        const ids = new Set(waiting.map((notification) => {
            return notification.id;
        }));
        const listedIds = new Set(listed.entries.map((entry) => {
            return entry.id;
        }));
        listed.add(waiting.filter((notification) => {
            return !listedIds.has(notification.id);
        }).reverse());
        const gone = listed.entries.filter((entry) => {
            return !ids.has(entry.id) && !listed.leaving(entry.id);
        }).map((entry) => {
            return entry.id;
        });
        // Hidden, the card draws no frames and its animations stand still: they would
        // all play at once the next time it opens. The ones closed meanwhile just go.
        if (!shown)
            listed.drop(gone);
        else
            listed.leave(gone);
    }

    // Closing the card: the ones still leaving go at once, for the same reason.
    onShownChanged: {
        if (!shown)
            listed.drop(listed.leavingIds);

    }
    Component.onCompleted: sync()
    spacing: Metrics.spacing.large

    Connections {
        function onWaitingChanged() {
            if (!list.dismissing)
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
            heading: true
            iconSize: Metrics.text.title
            font.pixelSize: Metrics.text.emphasis
            font.weight: Font.Bold
        }

        // A circle like the calendar's chevrons, so the card's header keeps one rhythm. Its
        // words wait under the pointer.
        GlassButton {
            enabled: list.count > 0
            icon: "󰃢"
            accent: true
            onClicked: list.clearAll()

            ToolTipArea {
                text: "Clear all"
            }

        }

    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        // In once the last one is gone, its exit over, out as soon as a new one comes in. Focus's
        // line hangs under it, so the words stay centred with or without it.
        Item {
            anchors.fill: parent
            opacity: list.listed.entries.length === 0 ? 1 : 0

            Text {
                id: emptyText

                anchors.centerIn: parent
                text: "No notifications"
                color: Colors.secondary
                font.family: Metrics.font
                font.pixelSize: Metrics.text.emphasis
            }

            Text {
                anchors.top: emptyText.bottom
                anchors.topMargin: Metrics.spacing.small
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Focus is on: new ones wait here"
                color: Colors.secondary
                font.family: Metrics.font
                font.pixelSize: Metrics.text.body
                opacity: ShellState.doNotDisturb ? 1 : 0

                Behavior on opacity {
                    Anim {
                        token: Motion.color.small
                    }

                }

            }

            Behavior on opacity {
                Anim {
                    token: Motion.color.small
                }

            }

        }

        ListView {
            id: view

            anchors.fill: parent
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
                            return list.listed.drop([id]);
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

                    Anim {
                        target: entry
                        property: "slot"
                        to: 0
                        token: Motion.resize.normal
                    }

                    ScriptAction {
                        script: list.listed.drop([entry.notificationId])
                    }

                }

            }

        }

    }

    // Focus keeps new notifications from popping out of the island: they wait here, all
    // but the critical ones. Its name flips it too.
    RowLayout {
        Layout.fillWidth: true
        spacing: Metrics.spacing.normal

        IconText {
            Layout.fillWidth: true
            icon: ShellState.doNotDisturb ? "󰂛" : "󰂚"
            text: "Focus"
            color: ShellState.doNotDisturb ? Colors.primary : Colors.secondary
            font.pixelSize: Metrics.text.emphasis

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: focusSwitch.activate()
            }

            ColorFade on color {
                token: Motion.color.small
            }

        }

        ToggleSwitch {
            id: focusSwitch

            checked: ShellState.doNotDisturb
            onToggled: ShellState.doNotDisturb = !ShellState.doNotDisturb
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
