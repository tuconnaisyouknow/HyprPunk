import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.modules.island
import qs.modules.music
import qs.services
import qs.state
import qs.theme

// The bar along the top of each screen, a row of pills: workspaces and resources on
// the left, the dynamic island in the middle, updates, the Spotify record and the
// control pill on the right. A click on a pill opens its card, the workspaces also
// preview on hover. The island's card holds the calendar and the notifications waiting.
// Drawn in its screen's window (ScreenShell), with the cards.
Item {
    id: bar

    required property var screen
    readonly property var screenState: ShellState.forScreen(screen)
    // Where the screen draws its cards: the bar's own ones go there (PillPopup).
    required property Item cardLayer
    // The shape the island's cards share (IslandFrame).
    required property Item islandFrame
    // Every card on this screen (Card), whichever pill they grow out of.
    property var cards: []
    // The notifications from before Quickshell was restarted.
    readonly property int notificationCount: Notifications.server.trackedNotifications.values.length + Notifications.history.entries.length
    // This screen's OSD (Osd), null while none shows here. The last one shown stays in
    // osdShown, so the island still draws it as it goes away.
    readonly property var osd: Osd.current !== null && (Osd.current.screen === "" || Osd.current.screen === screen.name) ? Osd.current : null
    readonly property bool osdVisible: osd !== null
    property var osdShown: Osd.blank
    readonly property string osdLabel: osdShown.label
    // While the session is locked, the lock's island shows the OSD and the bar's own one
    // stays still. It isn't drawn under the lock, so it would only catch up on its
    // animations once the lock is gone.
    property bool sessionLocked: false
    // A card is drawn over the island (the calendar, an island panel, the notifications,
    // the AirPods), opening or folding back.
    readonly property bool islandCovered: pillHidden("island")
    // The island shows the OSD while nobody holds it (ScreenState). Held, the OSD shows
    // beside the card instead (sideOsd). As soon as the card lets go the island takes it
    // back, hidden, so the card folds straight into the OSD's shape.
    readonly property bool islandOsdShown: osdVisible && !sessionLocked && screenState !== null && screenState.islandOwner === ""
    // The OSD is going into the island under a card folding back onto it: its time
    // running out waits for the card to land (Osd.landing).
    readonly property bool osdLanding: islandOsdShown && islandCovered
    // The island resizes at once while hidden under a card: animating it there made the
    // bar and the blur behind the card redraw every frame for nothing, and the card's own
    // animations drop frames (the calendar while a notification slides out of it).
    readonly property bool islandAnimated: !pillHidden("island")
    // Seconds since the recording started, for the island.
    property int recordingElapsed: 0
    // What the pills are drawn in, for the workspace previews' snapshot of the bar.
    readonly property Item content: barContent

    // Where each pill sits on screen, so the lock screen can start from there: the ones it
    // keeps (resources, island, control pill) and the ones it lets go. Where they rest,
    // like publishGeometry().
    function lockGeometry() {
        const rect = (item) => {
            const origin = item.parent.mapToItem(null, item.x, item.y);
            return {
                "x": origin.x,
                "y": origin.y,
                "width": item.width,
                "height": item.height,
                "radius": item.radius !== undefined ? item.radius : item.height / 2
            };
        };
        const others = [];
        for (const group of [leftGroup, centerGroup, rightGroup]) {
            for (const child of group.children) {
                if (child === monitor || child === island || child === control || !child.visible || child.width <= 0)
                    continue;

                // A drop-in slot: the pill inside it.
                others.push(rect(child.pill !== undefined && child.pill !== null ? child.pill : child));
            }
        }
        return {
            "monitor": monitor.visible ? rect(monitor) : null,
            "island": rect(island),
            "control": rect(control),
            "others": others
        };
    }

    // Hidden under a card grown out of it: the card's glass would let it through.
    function pillHidden(name) {
        return cards.some((card) => {
            return card.pillName === name && card.covering;
        });
    }

    onOsdChanged: {
        if (osd !== null)
            osdShown = osd;

    }
    onOsdVisibleChanged: {
        island.fadeContent();
        sideOsd.follow();
    }
    onOsdLabelChanged: island.fadeContent()
    // Where its island and control pill are, for the cards growing out of them:
    // centerOffset is how far the island sits from the middle, right and top are the
    // control pill's distances from the screen's edges. spreadX and spreadY are how far
    // its zoom draws the pill past its place, where a card starts and ends.
    property var islandPill: ({
        "centerOffset": 0,
        "top": Metrics.barTop,
        "width": 70,
        "height": Metrics.pillHeight,
        "spreadX": 0,
        "spreadY": 0
    })
    property var controlPill: ({
        "right": Metrics.barMargin,
        "top": Metrics.barTop,
        "width": 120,
        "height": Metrics.pillHeight,
        "spreadX": 0,
        "spreadY": 0
    })
    // The pointer is on the control pill's spot in the control center, which keeps the
    // pill lit (Pill.spotHovered).
    property bool controlSpotHovered: false
    // The bar's own cards, for the screen to watch.
    readonly property var ownCards: [workspaces.popup, monitor.popup, calendar, musicPill.popup]

    // Down to the island showing an OSD, which overhangs the bar's strip.
    implicitHeight: Metrics.barTop + Metrics.islandOsdHeight

    Item {
        id: barContent

        anchors.fill: parent
        anchors.leftMargin: Metrics.barMargin
        anchors.rightMargin: Metrics.barMargin

        RowLayout {
            id: leftGroup

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: Metrics.barTop
            spacing: Metrics.spacing.normal

            WorkspacesPill {
                id: workspaces

                bar: bar
            }

            MonitorPill {
                id: monitor

                bar: bar
            }

        }

        // Same when the island is busy with an OSD: they sit to its right.
        PrivacyDot {
            x: Math.round(centerGroup.x + island.x + island.width + Metrics.spacing.normal)
            y: Math.round(centerGroup.y + island.y + island.height / 2 - height / 2)
            camera: Privacy.cameraInUse
            microphone: Privacy.microphoneInUse
            recording: ShellState.recording
            opacity: active && bar.islandOsdShown && !calendar.mapped ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                Anim {
                    token: Motion.color.normal
                }

            }

        }

        SideOsd {
            id: sideOsd

            parent: bar.cardLayer
            bar: bar
        }

        RowLayout {
            id: centerGroup

            // Hung from the same line as the other pills: the island grows downwards
            // to take an OSD.
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Metrics.barTop
            spacing: Metrics.spacing.normal
            // The island moves with the group as it's centred, not inside it.
            onXChanged: island.publishGeometry()
            onYChanged: island.publishGeometry()

            IslandPill {
                id: island

                bar: bar
                calendar: calendar
            }

            CalendarCard {
                id: calendar

                bar: bar
                island: island
            }

        }

        RowLayout {
            id: rightGroup

            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: Metrics.barTop
            spacing: Metrics.spacing.normal
            // When the control pill changes width, it reports its place before the row has
            // settled against the right edge, so report again once it has.
            onXChanged: control.publishGeometry()
            onYChanged: control.publishGeometry()

            // Package updates waiting: a click runs them in your terminal.
            DropInSlot {
                shown: Updates.count > 0

                Pill {
                    clickable: true
                    onClicked: Updates.upgrade()

                    IconText {
                        icon: ""

                        // Keeps the last count while the pill flies away.
                        Binding on text {
                            when: Updates.count > 0
                            value: String(Updates.count)
                            restoreMode: Binding.RestoreNone
                        }

                    }

                }

            }

            // The Spotify track's cover as a spinning record. Click it to open the player.
            DropInSlot {
                shown: Music.player !== null

                MusicPill {
                    id: musicPill

                    opacity: bar.pillHidden("player") ? 0 : 1

                    player: Music.player
                    cardLayer: bar.cardLayer
                    screenState: bar.screenState
                }

            }

            ControlPill {
                id: control

                bar: bar
            }

        }

    }

    // The time recorded, for the island.
    Timer {
        interval: 1000
        running: ShellState.recording
        repeat: true
        triggeredOnStart: true
        onTriggered: bar.recordingElapsed = Math.max(0, Math.round((Date.now() - ShellState.recordingStarted) / 1000))
    }

    ServiceRef {
        service: Osd.landing
        active: bar.osdLanding
    }

    // Caffeine, or media playing when you asked for it (Power), keeps the computer
    // awake. On the bar because the bar is always there.
    IdleInhibitor {
        window: bar
        enabled: ShellState.caffeine || Power.awakeForMedia
    }

}
