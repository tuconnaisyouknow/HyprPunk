import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.components
import qs.config
import qs.modules.island
import qs.modules.music
import qs.modules.notifications
import qs.modules.workspaces
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
    readonly property var workspaceIcons: ["", "", "", "", "", "", "", "", "", "", ""]
    // Which of your other workspaces the preview card opens on.
    property var previewWorkspace: null
    readonly property var previewWorkspaces: workspaceSwitcher.workspaces.filter((workspace) => {
        return !workspace.focused;
    }).sort((a, b) => {
        return a.id - b.id;
    })
    // The workspace you were on before this one, which the preview opens on when you
    // ask for it with the keyboard: the one you most likely want back.
    property var lastWorkspace: null
    property var shownWorkspace: null
    readonly property var activeWorkspace: workspaceSwitcher.hyprlandMonitor !== null ? workspaceSwitcher.hyprlandMonitor.activeWorkspace : null
    // A snapshot of the bar for the previews (keeping grabToImage's result keeps it alive).
    property var barSnapshot: null
    readonly property int workspacePreviewWidth: 400
    // The screen's shape, 16:9 until Hyprland has told which monitor the bar is on.
    readonly property int workspacePreviewHeight: {
        const monitor = Hyprland.monitorFor(bar.screen);
        return Math.round(workspacePreviewWidth * (monitor !== null && monitor.width > 0 ? monitor.height / monitor.width : 9 / 16));
    }
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
    // The island shows the OSD unless a card is open on it, where it shows beside the card
    // instead (sideOsd). As soon as the card closes the island takes it back, hidden, so
    // the card folds straight into the OSD's shape.
    readonly property bool islandOsdShown: osdVisible && !sessionLocked && islandFrame.owner === null
    // The OSD is going into the island under a card folding back onto it: its time
    // running out waits for the card to land (Osd.landing).
    readonly property bool osdLanding: islandOsdShown && islandCovered
    // The island resizes at once while hidden under a card: animating it there made the
    // bar and the blur behind the card redraw every frame for nothing, and the card's own
    // animations drop frames (the calendar while a notification slides out of it).
    readonly property bool islandAnimated: !pillHidden("island")
    // Seconds since the recording started, for the island.
    property int recordingElapsed: 0
    property real clockCenterOffset: bar.islandOsdShown ? 3 : -3
    // The regional formats you picked (locale-profilectl.sh). The calendar's day names
    // and first day of the week follow them, even though the shell keeps its startup locale.
    readonly property var regionalLocale: Qt.locale(Session.regionalProfile === "us" ? "en_US" : "fr_FR")

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
                if (child === monitorPill || child === clockPill || child === controlPill || !child.visible || child.width <= 0)
                    continue;

                // A drop-in slot: the pill inside it.
                others.push(rect(child.pill !== undefined && child.pill !== null ? child.pill : child));
            }
        }
        return {
            "monitor": monitorPill.visible ? rect(monitorPill) : null,
            "island": rect(clockPill),
            "control": rect(controlPill),
            "others": others
        };
    }

    function capitalized(text) {
        return text.charAt(0).toUpperCase() + text.slice(1);
    }

    onActiveWorkspaceChanged: {
        lastWorkspace = shownWorkspace;
        shownWorkspace = activeWorkspace;
    }
    // The island's new content fades in while the pill resizes around it.
    onOsdChanged: {
        if (osd !== null)
            osdShown = osd;

    }
    onOsdVisibleChanged: {
        islandContentFade.restart();
        sideOsd.follow();
    }
    onOsdLabelChanged: islandContentFade.restart()
    // Where its island and control pill are, for the cards growing out of them:
    // centerOffset is how far the island sits from the middle, right and top are the
    // control pill's distances from the screen's edges. spreadX and spreadY are how far
    // its zoom draws the pill past its place, where a card starts and ends.
    property var islandPill: ({
        "centerOffset": 0,
        "top": 6,
        "width": 70,
        "height": Metrics.pillHeight,
        "spreadX": 0,
        "spreadY": 0
    })
    property var controlPill: ({
        "right": Metrics.barMargin,
        "top": 6,
        "width": 120,
        "height": Metrics.pillHeight,
        "spreadX": 0,
        "spreadY": 0
    })
    // The pointer is on the control pill's spot in the control center, which keeps the
    // pill lit (Pill.spotHovered).
    property bool controlSpotHovered: false
    // The bar's own cards, for the screen to watch.
    readonly property var ownCards: [workspacePopup, monitorPopup, calendarPopup, musicPill.popup]

    implicitHeight: 56

    Item {
        id: barContent

        anchors.fill: parent
        anchors.leftMargin: Metrics.barMargin
        anchors.rightMargin: Metrics.barMargin

        RowLayout {
            id: leftGroup

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -(bar.implicitHeight - 50) / 2
            spacing: 9

            // Previews a workspace on hover, in a card that grows out of it.
            Pill {
                id: workspacePill

                opacity: bar.pillHidden("workspaces") ? 0 : 1

                onHoveredChanged: {
                    if (!hovered)
                        workspacePopup.hoverEnded();

                }

                WorkspaceSwitcher {
                    id: workspaceSwitcher

                    screen: bar.screen
                    icons: bar.workspaceIcons
                    // Waits like the other pills. No need to preview the workspace you're on.
                    onHoveredWorkspaceChanged: {
                        if (hoveredWorkspace !== null && !hoveredWorkspace.focused && !workspacePopup.mapped)
                            workspacePopup.hoverStarted();
                        else
                            workspacePopup.cancelOpen();
                    }
                }

                PillPopup {
                    id: workspacePopup

                    cardLayer: bar.cardLayer
                    pill: workspacePill
                    pillName: "workspaces"
                    panelName: "workspaces"
                    screenState: bar.screenState
                    // Nothing to preview while your other workspaces are all empty.
                    requestable: bar.previewWorkspaces.length > 0
                    opensOnHover: true
                    openable: workspaceSwitcher.hoveredWorkspace !== null
                    // The preview inside the control center's padding.
                    implicitWidth: bar.workspacePreviewWidth + 28
                    implicitHeight: bar.workspacePreviewHeight + 28
                    // Ask Hyprland where the windows are (it only says when asked), and
                    // snapshot the bar to lay over every preview.
                    onOpening: {
                        Hyprland.refreshToplevels();
                        barContent.grabToImage((result) => {
                            bar.barSnapshot = result;
                        });
                        if (workspaceSwitcher.hoveredWorkspace !== null)
                            bar.previewWorkspace = workspaceSwitcher.hoveredWorkspace;
                        else
                            bar.previewWorkspace = bar.previewWorkspaces.includes(bar.lastWorkspace) ? bar.lastWorkspace : null;
                    }
                    // Opened with its shortcut: the arrows (Vim's too) or Tab go through
                    // the workspaces, Enter takes you there.
                    onKeyPressed: (key) => {
                        const card = previewLoader.item;
                        if (card === null)
                            return ;

                        const french = Session.keyboardLayout === "fr";
                        if (key === Qt.Key_Left || key === Qt.Key_Backtab || key === (french ? Qt.Key_J : Qt.Key_H))
                            card.step(-1);
                        else if (key === Qt.Key_Right || key === Qt.Key_Tab || key === (french ? Qt.Key_M : Qt.Key_L))
                            card.step(1);
                        else if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space)
                            card.choose();
                    }

                    // Rebuilt on every opening, so the windows are captured fresh.
                    Loader {
                        id: previewLoader

                        x: 14
                        y: 14
                        width: bar.workspacePreviewWidth
                        height: bar.workspacePreviewHeight
                        active: workspacePopup.mapped
                        opacity: workspacePopup.expanded ? 1 : 0

                        sourceComponent: WorkspacePreviewCard {
                            workspaces: bar.previewWorkspaces
                            initialWorkspace: bar.previewWorkspace
                            monitor: workspaceSwitcher.hyprlandMonitor
                            wallpaper: Session.wallpaper
                            barImage: bar.barSnapshot !== null ? bar.barSnapshot.url : ""
                            barRect: Qt.rect(barContent.x, barContent.y, barContent.width, barContent.height)
                            onWorkspaceChosen: (workspace) => {
                                workspace.activate();
                                workspacePopup.close();
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

            }

            // Opens the system monitor, which grows out of it like the player.
            Pill {
                id: monitorPill

                visible: bar.width >= 1200
                opacity: bar.pillHidden("monitor") ? 0 : 1
                clickable: true
                onClicked: monitorPopup.togglePinned()

                IconText {
                    icon: ""
                    text: SystemStats.memoryText
                }

                IconText {
                    icon: ""
                    text: Math.round(SystemStats.cpuUsage * 100) + "%"
                }

                PillPopup {
                    id: monitorPopup

                    cardLayer: bar.cardLayer
                    pill: monitorPill
                    pillName: "monitor"
                    panelName: "systemmonitor"
                    screenState: bar.screenState
                    // Nothing to open from on a bar too narrow for its pill.
                    requestable: monitorPill.visible
                    implicitWidth: monitorContent.implicitWidth
                    implicitHeight: monitorContent.implicitHeight

                    SystemMonitorCard {
                        id: monitorContent

                        width: monitorPopup.width
                        opacity: monitorPopup.expanded ? 1 : 0
                        active: monitorPopup.mapped

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                }

            }

        }

        // When the calendar covers the island, the privacy and recording dots move to its
        // right, following its edge as it grows: the edge it's drawn with, or the gap
        // between them would wobble as the card's left side snaps to whole pixels.
        PrivacyDot {
            parent: bar.cardLayer
            x: Math.round(calendarPopup.cardRect.x + calendarPopup.cardRect.width + 8)
            y: Math.round(bar.islandPill.top + bar.islandPill.height / 2 - height / 2)
            camera: Privacy.cameraInUse
            microphone: Privacy.microphoneInUse
            recording: ShellState.recording
            opacity: active ? calendarPopup.progress : 0
            visible: calendarPopup.mapped && opacity > 0
        }

        // Same when the island is busy with an OSD: they sit to its right.
        PrivacyDot {
            x: Math.round(centerGroup.x + clockPill.x + clockPill.width + 8)
            y: Math.round(centerGroup.y + clockPill.y + clockPill.height / 2 - height / 2)
            camera: Privacy.cameraInUse
            microphone: Privacy.microphoneInUse
            recording: ShellState.recording
            opacity: active && bar.islandOsdShown && !calendarPopup.mapped ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }

            }

        }

        // While a card is open on the island, its OSD shows here instead, on the card's
        // left (the privacy dots take its right). An OSD that starts then drops in, and
        // flies back up once over, like the bar's pills that come and go (DropInSlot). The
        // one the island was showing comes out of it as a card opens, and goes back into it
        // as the card folds onto it, so there's only ever one: drawn over the cards, its
        // glass fades as it enters and its content lands where the island shows the same.
        Item {
            id: sideOsd

            parent: bar.cardLayer

            readonly property Item frame: bar.islandFrame
            // Off screen above the bar, 0 in place.
            property real lift: 60
            // Beside the card, or in the middle of the island's shape (IslandFrame.islandShare).
            // Only while it shows: over, it has nothing to bring into the island.
            readonly property real besideX: frame.shape.x - 10 - width
            readonly property real insideX: frame.shape.x + (frame.shape.width - width) / 2

            // The OSD starts or ends: it drops in beside a card or flies away from it. In the
            // island, it's in place for a card that opens over it.
            function follow() {
                sideOsdEnter.stop();
                sideOsdLeave.stop();
                sideOsdSettle.stop();
                if (bar.osdVisible) {
                    if (frame.owner !== null)
                        sideOsdEnter.restart();
                    else
                        lift = 0;
                } else {
                    if (visible)
                        sideOsdLeave.restart();
                    else
                        lift = 60;
                }
            }

            // The card starts folding back. Still showing, the OSD goes into the island with
            // it: it settles in line with the island in the first half, before it reaches
            // the card's content, and lands where the island shows it. Already over and
            // flying off, it stops and fades where it is.
            function fold() {
                sideOsdEnter.stop();
                sideOsdLeave.stop();
                if (bar.osdVisible)
                    sideOsdSettle.restart();

            }

            x: Math.round(besideX + (insideX - besideX) * (bar.osdVisible ? frame.islandShare : 0))
            y: Math.round(frame.islandMiddle - height / 2 - lift)
            width: sideOsdPill.width
            height: sideOsdPill.height
            // Only over a card: in the island, the island shows it.
            visible: (bar.osdVisible || lift < 60) && bar.islandCovered && !bar.sessionLocked
            // Over, it fades beside the card in the first half of its folding back (fold),
            // never crossing what the card still shows.
            opacity: bar.osdVisible ? 1 : Math.max(0, 1 - 2 * frame.islandShare)
            // Gone into the island or flown off: ready to come out of the island, or to
            // drop in from above for the next OSD.
            onVisibleChanged: {
                if (visible)
                    return ;

                sideOsdEnter.stop();
                sideOsdLeave.stop();
                sideOsdSettle.stop();
                lift = bar.osdVisible ? 0 : 60;
            }

            Pill {
                id: sideOsdPill

                horizontalPadding: 28
                glassOpacity: 1 - sideOsd.frame.islandShare

                // Still showing as it flies away: the OSD is already over.
                IslandOsd {
                    shown: true
                    content: bar.osdShown
                }

            }

            NumberAnimation {
                id: sideOsdEnter

                target: sideOsd
                property: "lift"
                to: 0
                duration: 700
                easing.type: Easing.OutBounce
            }

            Connections {
                function onOwnerChanged() {
                    if (sideOsd.frame.owner === null)
                        sideOsd.fold();

                }

                target: sideOsd.frame
            }

            NumberAnimation {
                id: sideOsdSettle

                target: sideOsd
                property: "lift"
                to: 0
                duration: Motion.resize.large.duration / 2
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                id: sideOsdLeave

                target: sideOsd
                property: "lift"
                to: 60
                duration: 300
                easing.type: Easing.InBack
            }

        }

        RowLayout {
            id: centerGroup

            anchors.centerIn: parent
            anchors.verticalCenterOffset: bar.clockCenterOffset
            spacing: 9
            // The island moves with the group (centring and the OSD offset), not inside it.
            onXChanged: clockPill.publishGeometry()
            onYChanged: clockPill.publishGeometry()

            Pill {
                id: clockPill

                opacity: bar.pillHidden("island") ? 0 : 1
                // Not under the recording chip, which answers the pointer itself.
                clickable: (!bar.islandOsdShown || bar.osdShown.kind === "screenshot") && !islandChips.stopHovered

                // Where it rests in its row, and its zoom apart.
                function publishGeometry() {
                    const origin = parent.mapToItem(null, x, y);
                    bar.islandPill = {
                        "centerOffset": origin.x + width / 2 - bar.width / 2,
                        "top": origin.y,
                        "width": width,
                        "height": height,
                        "spreadX": spreadX,
                        "spreadY": spreadY
                    };
                }

                onWidthChanged: publishGeometry()
                onHeightChanged: publishGeometry()
                onSpreadXChanged: publishGeometry()
                onSpreadYChanged: publishGeometry()
                Component.onCompleted: publishGeometry()
                // Each chip brings its own gap after the time.
                spacing: 0

                // A click opens the calendar card, or closes it, unless an OSD has the
                // island: the screenshot or recording just taken then opens in its viewer.
                // The recording chip keeps its own click, which stops the recording.
                onClicked: {
                    if (!bar.islandOsdShown) {
                        bar.toggleNotificationCard();
                    } else {
                        Quickshell.execDetached(["xdg-open", bar.osdShown.file]);
                        Osd.dismiss();
                    }
                }
                horizontalPadding: bar.islandOsdShown ? 36 : 20
                implicitHeight: bar.islandOsdShown ? 50 : Metrics.pillHeight
                // Grows two pixels at a time, so centring it on the bar and its content in it
                // never lands on a half pixel and the content stops shaking as it resizes.
                Layout.preferredWidth: 2 * Math.round(implicitWidth / 2)
                Layout.preferredHeight: 2 * Math.round(implicitHeight / 2)
                contentOpacity: 1

                Label {
                    id: dateTimeLabel

                    visible: !bar.islandOsdShown
                    text: Session.clockText(clock.date)

                    // Ticks every second though it shows minutes: its timer stands still
                    // during sleep, so on waking it would keep the old time up to a minute.
                    SystemClock {
                        id: clock

                        precision: SystemClock.Seconds
                    }

                }

                // Gone at once when an OSD takes the island, or their closing would pull
                // the OSD sideways while it grows.
                IslandChips {
                    id: islandChips

                    bar: bar
                    visible: !bar.islandOsdShown
                    shown: !bar.islandOsdShown
                    animated: bar.islandAnimated
                }

                IslandOsd {
                    shown: bar.osdVisible
                    content: bar.osdShown
                    visible: bar.islandOsdShown
                }

                Behavior on implicitWidth {
                    enabled: bar.islandAnimated

                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on implicitHeight {
                    enabled: bar.islandAnimated

                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }

                }

            }

            SequentialAnimation {
                id: islandContentFade

                PropertyAction {
                    target: clockPill
                    property: "contentOpacity"
                    value: 0
                }

                // The pill is ~90% open by then, so its edges don't clip the content.
                PauseAnimation {
                    duration: 110
                }

                NumberAnimation {
                    target: clockPill
                    property: "contentOpacity"
                    to: 1
                    duration: 140
                    easing.type: Easing.OutCubic
                }

            }

            PillPopup {
                id: calendarPopup

                readonly property date currentDate: clock.date
                readonly property int currentYear: currentDate.getFullYear()
                readonly property int currentMonth: currentDate.getMonth()
                readonly property int currentDay: currentDate.getDate()
                property int monthOffset: 0
                readonly property date displayedMonth: new Date(currentYear, currentMonth + monthOffset, 1)
                readonly property int displayedYear: displayedMonth.getFullYear()
                readonly property int displayedMonthNumber: displayedMonth.getMonth()
                // Column of the month's first day, the week starting on the locale's first day.
                readonly property int firstWeekday: (displayedMonth.getDay() - bar.regionalLocale.firstDayOfWeek + 7) % 7
                readonly property int daysInMonth: new Date(displayedYear, displayedMonthNumber + 1, 0).getDate()
                readonly property int weekRows: Math.ceil((firstWeekday + daysInMonth) / 7)
                // Card height for the displayed month, measured from the real layout, and
                // eased when the next month has a week more or less.
                readonly property real contentHeight: calendarColumn.y + calendarBody.y + calendarBody.implicitHeight + 18
                property real animatedHeight: contentHeight
                readonly property int calendarWidth: 322
                readonly property int notificationWidth: 400
                // The notifications open beside the calendar while some are waiting.
                property real animatedWidth: notificationList.shownCount > 0 ? calendarWidth + notificationWidth : calendarWidth
                property int pendingMonthDelta: 0

                function changeMonth(delta) {
                    if (monthTransition.running)
                        return ;

                    pendingMonthDelta = delta;
                    monthTransition.start();
                }

                cardLayer: bar.cardLayer
                pill: clockPill
                pillName: "island"
                frame: bar.islandFrame
                panelName: "notifications"
                screenState: bar.screenState
                // A password, a file or a screen to share is being asked for on the island.
                blocked: bar.screenState.prompting()
                align: Qt.AlignHCenter
                cardHeight: animatedHeight
                cardWidth: animatedWidth
                implicitWidth: calendarWidth + notificationWidth
                // Sized for a six-week month so the card can animate without clipping. Not taken
                // from weekRows: the layout updates a frame late, and the popup would resize twice
                // (everything shakes).
                implicitHeight: calendarColumn.y + calendarBody.y + calendarMonthLabel.implicitHeight + calendarBody.spacing + calendarGrid.sixWeekHeight + 18
                // It takes the island: an island panel open there folds back. While it
                // holds it, new notifications land in it instead of popping out of the
                // island, and the AirPods card waits.
                onOpening: {
                    monthOffset = 0;
                    bar.screenState.claim("notifications", 2);
                }
                onExpandedChanged: {
                    if (!expanded)
                        bar.screenState.release("notifications");

                }

                // Something else takes the island (a panel, a prompt): the calendar folds
                // back.
                Connections {
                    function onIslandOwnerChanged() {
                        if (calendarPopup.expanded && bar.screenState.islandOwner !== "notifications")
                            calendarPopup.close();

                    }

                    target: bar.screenState
                }

                Item {
                    id: expandedClockHeader

                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: clockPill.width
                    height: clockPill.height
                    // The island's own time, so it stays while the card folds back onto
                    // the island showing the time. Another card taking the island's shape
                    // over, or the island taking an OSD, has no time to meet: it fades
                    // with the rest of the content.
                    opacity: bar.islandFrame.owner === calendarPopup || bar.islandFrame.owner === null && !bar.islandOsdShown ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }

                    }

                    // Starts where the time sits in the island, pushed left by the badge or
                    // the dots, and slides to the card's middle as it opens, then back.
                    Label {
                        readonly property real islandX: dateTimeLabel.parent.x + dateTimeLabel.x
                        readonly property real centerX: (parent.width - width) / 2

                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.round(islandX + (centerX - islandX) * calendarPopup.progress)
                        text: Session.clockText(clock.date)
                    }

                }

                Rectangle {
                    id: calendarSeparator

                    anchors.top: expandedClockHeader.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    height: 1
                    color: Colors.surface1
                    opacity: calendarPopup.expanded ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                // The calendar on the right, the notifications on its left.
                Item {
                    id: calendarColumn

                    anchors.top: calendarSeparator.bottom
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: calendarPopup.calendarWidth

                    // Scrolling over the calendar goes through the months.
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: (wheel) => {
                            if (wheel.angleDelta.y > 0)
                                calendarPopup.changeMonth(-1);
                            else if (wheel.angleDelta.y < 0)
                                calendarPopup.changeMonth(1);
                            wheel.accepted = true;
                        }
                    }

                    IconText {
                        id: calendarDate

                        anchors.top: parent.top
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        icon: "󰃭"
                        text: bar.regionalLocale.toString(clock.date, bar.regionalLocale.dateFormat(Locale.LongFormat))
                        color: Colors.secondary
                        font.pixelSize: 15
                        opacity: calendarPopup.expanded ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    Rectangle {
                        id: dateSeparator

                        anchors.top: calendarDate.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: 10
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        height: 1
                        color: Colors.surface1
                        opacity: calendarPopup.expanded ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    ColumnLayout {
                        id: calendarBody

                        property real monthSlideY: 0
                        property real monthTransitionOpacity: 1

                        anchors.top: dateSeparator.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        anchors.topMargin: 8
                        spacing: 10
                        opacity: (calendarPopup.expanded ? 1 : 0) * monthTransitionOpacity

                        Label {
                            id: calendarMonthLabel

                            Layout.alignment: Qt.AlignHCenter
                            text: bar.capitalized(bar.regionalLocale.standaloneMonthName(calendarPopup.displayedMonthNumber)) + " " + calendarPopup.displayedYear
                            color: Colors.primary
                            font.pixelSize: 18
                            font.weight: Font.Bold
                        }

                        GridLayout {
                            id: calendarGrid

                            // Weekday row (25) and six weeks (29), with their spacing.
                            readonly property real sixWeekHeight: 25 + 6 * 29 + 6 * rowSpacing

                            Layout.fillWidth: true
                            columns: 7
                            columnSpacing: 4
                            rowSpacing: 4

                            Repeater {
                                // From the locale's first day, "Lun" rather than "lun.".
                                model: [0, 1, 2, 3, 4, 5, 6].map((offset) => {
                                    return bar.capitalized(bar.regionalLocale.dayName((bar.regionalLocale.firstDayOfWeek + offset) % 7, Locale.ShortFormat).replace(/\.$/, ""));
                                })

                                Label {
                                    required property string modelData

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 25
                                    text: modelData
                                    color: Colors.primary
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                            }

                            Repeater {
                                model: calendarPopup.weekRows * 7

                                Rectangle {
                                    required property int index
                                    readonly property int dayNumber: index - calendarPopup.firstWeekday + 1
                                    readonly property bool validDay: dayNumber >= 1 && dayNumber <= calendarPopup.daysInMonth
                                    readonly property bool isToday: validDay && dayNumber === calendarPopup.currentDay && calendarPopup.displayedMonthNumber === calendarPopup.currentMonth && calendarPopup.displayedYear === calendarPopup.currentYear

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 29
                                    radius: 9
                                    color: isToday ? Colors.primary : "transparent"

                                    Label {
                                        anchors.centerIn: parent
                                        text: parent.validDay ? parent.dayNumber : ""
                                        color: parent.isToday ? Colors.base : Colors.primary
                                        font.pixelSize: 14
                                        font.weight: parent.isToday ? Font.Bold : Font.Medium
                                    }

                                }

                            }

                        }

                        transform: Translate {
                            y: calendarBody.monthSlideY
                        }

                    }

                }

                Rectangle {
                    anchors.top: calendarSeparator.bottom
                    anchors.bottom: parent.bottom
                    anchors.right: calendarColumn.left
                    anchors.topMargin: 14
                    anchors.bottomMargin: 18
                    width: 1
                    color: Colors.surface1
                    opacity: calendarPopup.expanded ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                NotificationList {
                    id: notificationList

                    anchors.top: calendarSeparator.bottom
                    anchors.bottom: parent.bottom
                    anchors.right: calendarColumn.left
                    anchors.topMargin: 12
                    anchors.bottomMargin: 18
                    anchors.rightMargin: 16
                    width: calendarPopup.notificationWidth - 32
                    shown: calendarPopup.expanded
                    opacity: calendarPopup.expanded ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                SequentialAnimation {
                    id: monthTransition

                    ParallelAnimation {
                        NumberAnimation {
                            target: calendarBody
                            property: "monthSlideY"
                            to: calendarPopup.pendingMonthDelta > 0 ? -28 : 28
                            duration: 120
                            easing.type: Easing.InCubic
                        }

                        NumberAnimation {
                            target: calendarBody
                            property: "monthTransitionOpacity"
                            to: 0
                            duration: 100
                            easing.type: Easing.InCubic
                        }

                    }

                    ScriptAction {
                        script: {
                            calendarPopup.monthOffset += calendarPopup.pendingMonthDelta;
                            calendarBody.monthSlideY = calendarPopup.pendingMonthDelta > 0 ? 28 : -28;
                        }
                    }

                    ParallelAnimation {
                        NumberAnimation {
                            target: calendarBody
                            property: "monthSlideY"
                            to: 0
                            duration: 160
                            easing.type: Easing.OutCubic
                        }

                        NumberAnimation {
                            target: calendarBody
                            property: "monthTransitionOpacity"
                            to: 1
                            duration: 140
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                Behavior on animatedHeight {
                    NumberAnimation {
                        duration: Motion.resize.large.duration
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on animatedWidth {
                    NumberAnimation {
                        duration: Motion.resize.large.duration
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

        RowLayout {
            id: rightGroup

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -(bar.implicitHeight - 50) / 2
            spacing: 9
            // When the control pill changes width, it reports its place before the row has
            // settled against the right edge, so report again once it has.
            onXChanged: controlPill.publishGeometry()
            onYChanged: controlPill.publishGeometry()

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

            // Opens the control center, which grows out of it.
            Pill {
                id: controlPill

                // Hidden under the control center's glass, which lets it through.
                opacity: bar.pillHidden("control") ? 0 : 1
                clickable: true
                spotHovered: bar.controlSpotHovered

                // Where it rests in its row, and its zoom apart.
                function publishGeometry() {
                    const origin = parent.mapToItem(null, x, y);
                    bar.controlPill = {
                        "right": bar.width - origin.x - width,
                        "top": origin.y,
                        "width": width,
                        "height": height,
                        "spreadX": spreadX,
                        "spreadY": spreadY
                    };
                }

                onSpreadXChanged: publishGeometry()
                onSpreadYChanged: publishGeometry()
                onXChanged: publishGeometry()
                onYChanged: publishGeometry()
                onWidthChanged: publishGeometry()
                onHeightChanged: publishGeometry()
                Component.onCompleted: publishGeometry()
                onClicked: bar.screenState.toggle("controlcenter")

                ControlStatus {
                    badgeColor: controlPill.baseColor
                    showsTrayAttention: true
                }

            }

        }

    }

    // Hidden under a card grown out of it: the card's glass would let it through.
    function pillHidden(name) {
        return cards.some((card) => {
            return card.pillName === name && card.covering;
        });
    }

    // The time recorded, for the island.
    Timer {
        interval: 1000
        running: ShellState.recording
        repeat: true
        triggeredOnStart: true
        onTriggered: bar.recordingElapsed = Math.max(0, Math.round((Date.now() - ShellState.recordingStarted) / 1000))
    }

    Behavior on clockCenterOffset {
        enabled: bar.islandAnimated

        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }

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
