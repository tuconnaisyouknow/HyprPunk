import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.modules.island
import qs.modules.notifications
import qs.services
import qs.state
import qs.theme

// The island's card: the calendar, with the notifications waiting beside it. It grows
// out of the island, in the shape all the island's cards share (IslandFrame), holding
// the island like a panel (ScreenState). The wheel goes through the months.
PillPopup {
    id: calendarPopup

    required property var bar
    // The island it grows out of (IslandPill), whose time it shows.
    required property Item island

    function capitalized(text) {
        return text.charAt(0).toUpperCase() + text.slice(1);
    }

    readonly property date currentDate: calendarPopup.island.date
    readonly property int currentYear: currentDate.getFullYear()
    readonly property int currentMonth: currentDate.getMonth()
    readonly property int currentDay: currentDate.getDate()
    property int monthOffset: 0
    readonly property date displayedMonth: new Date(currentYear, currentMonth + monthOffset, 1)
    readonly property int displayedYear: displayedMonth.getFullYear()
    readonly property int displayedMonthNumber: displayedMonth.getMonth()
    // Column of the month's first day, the week starting on the locale's first day.
    readonly property int firstWeekday: (displayedMonth.getDay() - Session.regionalFormats.firstDayOfWeek + 7) % 7
    readonly property int daysInMonth: new Date(displayedYear, displayedMonthNumber + 1, 0).getDate()
    readonly property int weekRows: Math.ceil((firstWeekday + daysInMonth) / 7)
    // Card height for the displayed month, measured from the real layout, and
    // eased when the next month has a week more or less.
    readonly property real contentHeight: calendarColumn.y + calendarBody.y + calendarBody.implicitHeight + inset
    property real animatedHeight: contentHeight
    readonly property int calendarWidth: 322
    // How far the content and the lines' ends keep from the card's edges.
    readonly property int inset: Metrics.spacing.huge
    // The weekdays' row and each week's, which a month change slides the days by.
    readonly property int weekdayHeight: 24
    readonly property int dayHeight: 28
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

    cardLayer: calendarPopup.bar.cardLayer
    pill: calendarPopup.island
    pillName: "island"
    frame: calendarPopup.bar.islandFrame
    panelName: "notifications"
    screenState: calendarPopup.bar.screenState
    // A password, a file or a screen to share is being asked for on the island.
    blocked: calendarPopup.bar.screenState.prompting()
    align: Qt.AlignHCenter
    cardHeight: animatedHeight
    carriesIslandContent: true
    cardWidth: animatedWidth
    implicitWidth: calendarWidth + notificationWidth
    // Sized for a six-week month so the card can animate without clipping. Not taken
    // from weekRows: the layout updates a frame late, and the popup would resize twice
    // (everything shakes).
    implicitHeight: calendarColumn.y + calendarBody.y + calendarMonthLabel.implicitHeight + calendarBody.spacing + calendarGrid.sixWeekHeight + inset
    // It takes the island: an island panel open there folds back. While it
    // holds it, new notifications land in it instead of popping out of the
    // island, and the AirPods card waits.
    onOpening: {
        monthOffset = 0;
        calendarPopup.bar.screenState.claim("notifications", 2);
    }
    onExpandedChanged: {
        if (!expanded)
            calendarPopup.bar.screenState.release("notifications");

    }

    // Something else takes the island (a panel, a prompt): the calendar folds
    // back.
    Connections {
        function onIslandOwnerChanged() {
            if (calendarPopup.expanded && calendarPopup.bar.screenState.islandOwner !== "notifications")
                calendarPopup.close();

        }

        target: calendarPopup.bar.screenState
    }

    Item {
        id: expandedClockHeader

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: calendarPopup.island.width
        height: calendarPopup.island.height
        // The island's own time, so it stays while the card folds back onto
        // the island showing the time. Another card taking the island's shape
        // over, or the island taking an OSD, has no time to meet: it fades
        // with the rest of the content.
        opacity: calendarPopup.bar.islandFrame.owner === calendarPopup || calendarPopup.bar.islandFrame.owner === null && !calendarPopup.bar.islandOsdShown ? 1 : 0

        Behavior on opacity {
            Anim {
                token: Motion.color.small
            }

        }

        // The island's time and chips, starting where they sit in it: the chips close
        // as the time slides to the card's middle, and open again as it slides back,
        // so the card lands on the island as it is.
        RowLayout {
            readonly property real islandX: calendarPopup.island.timeLabel.parent.x
            readonly property real centerX: (parent.width - width) / 2

            anchors.verticalCenter: parent.verticalCenter
            x: Math.round(islandX + (centerX - islandX) * calendarPopup.progress)
            spacing: 0

            Label {
                text: Session.clockText(calendarPopup.island.date)
            }

            IslandChips {
                bar: calendarPopup.bar
                shown: !calendarPopup.expanded
                interactive: false
            }

        }

    }

    Rectangle {
        id: calendarSeparator

        anchors.top: expandedClockHeader.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: calendarPopup.inset
        anchors.rightMargin: calendarPopup.inset
        height: Metrics.stroke
        color: Colors.surface1
        opacity: calendarPopup.expanded ? 1 : 0

        Behavior on opacity {
            Anim {
                token: Motion.color.small
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
            anchors.topMargin: Metrics.spacing.normal
            anchors.horizontalCenter: parent.horizontalCenter
            icon: "󰃭"
            text: Session.regionalFormats.toString(calendarPopup.island.date, Session.regionalFormats.dateFormat(Locale.LongFormat))
            color: Colors.secondary
            font.pixelSize: Metrics.text.emphasis
            opacity: calendarPopup.expanded ? 1 : 0

            Behavior on opacity {
                Anim {
                    token: Motion.color.small
                }

            }

        }

        Rectangle {
            id: dateSeparator

            anchors.top: calendarDate.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: Metrics.spacing.normal
            anchors.leftMargin: calendarPopup.inset
            anchors.rightMargin: calendarPopup.inset
            height: Metrics.stroke
            color: Colors.surface1
            opacity: calendarPopup.expanded ? 1 : 0

            Behavior on opacity {
                Anim {
                    token: Motion.color.small
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
            anchors.leftMargin: calendarPopup.inset
            anchors.rightMargin: calendarPopup.inset
            anchors.topMargin: Metrics.spacing.normal
            spacing: Metrics.spacing.normal
            opacity: (calendarPopup.expanded ? 1 : 0) * monthTransitionOpacity

            Label {
                id: calendarMonthLabel

                Layout.alignment: Qt.AlignHCenter
                text: calendarPopup.capitalized(Session.regionalFormats.standaloneMonthName(calendarPopup.displayedMonthNumber)) + " " + calendarPopup.displayedYear
                color: Colors.primary
                font.pixelSize: Metrics.text.title
                font.weight: Font.Bold
            }

            GridLayout {
                id: calendarGrid

                // The weekdays and six weeks, with their spacing.
                readonly property real sixWeekHeight: calendarPopup.weekdayHeight + 6 * (calendarPopup.dayHeight + rowSpacing)

                Layout.fillWidth: true
                columns: 7
                columnSpacing: Metrics.spacing.small
                rowSpacing: Metrics.spacing.small

                Repeater {
                    // From the locale's first day, "Lun" rather than "lun.".
                    model: [0, 1, 2, 3, 4, 5, 6].map((offset) => {
                        return calendarPopup.capitalized(Session.regionalFormats.dayName((Session.regionalFormats.firstDayOfWeek + offset) % 7, Locale.ShortFormat).replace(/\.$/, ""));
                    })

                    Label {
                        required property string modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: calendarPopup.weekdayHeight
                        text: modelData
                        color: Colors.primary
                        font.pixelSize: Metrics.text.body
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
                        Layout.preferredHeight: calendarPopup.dayHeight
                        // Round ends, like the pills.
                        radius: height / 2
                        color: isToday ? Colors.primary : "transparent"

                        Label {
                            anchors.centerIn: parent
                            text: parent.validDay ? parent.dayNumber : ""
                            color: parent.isToday ? Colors.base : Colors.primary
                            font.pixelSize: Metrics.text.emphasis
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
        anchors.topMargin: Metrics.spacing.large
        anchors.bottomMargin: calendarPopup.inset
        width: Metrics.stroke
        color: Colors.surface1
        opacity: calendarPopup.expanded ? 1 : 0

        Behavior on opacity {
            Anim {
                token: Motion.color.small
            }

        }

    }

    NotificationList {
        id: notificationList

        anchors.top: calendarSeparator.bottom
        anchors.bottom: parent.bottom
        anchors.right: calendarColumn.left
        anchors.topMargin: Metrics.spacing.large
        anchors.bottomMargin: calendarPopup.inset
        anchors.rightMargin: calendarPopup.inset
        width: calendarPopup.notificationWidth - 2 * calendarPopup.inset
        shown: calendarPopup.expanded
        opacity: calendarPopup.expanded ? 1 : 0

        Behavior on opacity {
            Anim {
                token: Motion.color.small
            }

        }

    }

    SequentialAnimation {
        id: monthTransition

        ParallelAnimation {
            Anim {
                target: calendarBody
                property: "monthSlideY"
                to: calendarPopup.pendingMonthDelta > 0 ? -calendarPopup.dayHeight : calendarPopup.dayHeight
                token: Motion.leave.small
            }

            Anim {
                target: calendarBody
                property: "monthTransitionOpacity"
                to: 0
                token: Motion.leave.small
            }

        }

        ScriptAction {
            script: {
                calendarPopup.monthOffset += calendarPopup.pendingMonthDelta;
                calendarBody.monthSlideY = calendarPopup.pendingMonthDelta > 0 ? calendarPopup.dayHeight : -calendarPopup.dayHeight;
            }
        }

        ParallelAnimation {
            Anim {
                target: calendarBody
                property: "monthSlideY"
                to: 0
                token: Motion.enter.small
            }

            Anim {
                target: calendarBody
                property: "monthTransitionOpacity"
                to: 1
                token: Motion.enter.small
            }

        }

    }

    Behavior on animatedHeight {
        Anim {
            token: Motion.resize.large
        }

    }

    Behavior on animatedWidth {
        Anim {
            token: Motion.resize.large
        }

    }


    // When the calendar covers the island, the privacy and recording dots move to its
    // right, following its edge as it grows: the edge it's drawn with, or the gap
    // between them would wobble as the card's left side snaps to whole pixels.
    PrivacyDot {
        parent: calendarPopup.cardLayer
        x: Math.round(calendarPopup.cardRect.x + calendarPopup.cardRect.width + Metrics.spacing.normal)
        y: Math.round(calendarPopup.bar.islandPill.top + calendarPopup.bar.islandPill.height / 2 - height / 2)
        camera: Privacy.cameraInUse
        microphone: Privacy.microphoneInUse
        recording: Screenshot.recording
        opacity: active ? calendarPopup.progress : 0
        visible: calendarPopup.mapped && opacity > 0
    }

}
