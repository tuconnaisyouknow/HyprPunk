import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.modules.island
import qs.modules.notifications
import qs.services
import qs.state
import qs.theme

// The island's card: the calendar, with the notifications beside it. It grows
// out of the island, in the shape all the island's cards share (IslandFrame), holding
// the island like a panel (ScreenState). Every month is drawn as six full weeks, the
// days of the months around it filling the ends, so the card keeps one shape. The
// chevrons beside its name and the wheel go through the months.
PillPopup {
    id: calendarPopup

    required property var bar
    // The island it grows out of (IslandPill), whose clock tells today.
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
    // How far the content and the line's ends keep from the card's edges.
    readonly property int inset: Metrics.spacing.huge
    // A day's circle, and the gap between two, the same both ways. A month change slides
    // the days by one circle.
    readonly property int daySize: 34
    readonly property int dayGap: Metrics.spacing.normal
    readonly property int weekdayHeight: 24
    // Seven circles across, which the card is sized around.
    readonly property int calendarWidth: 2 * inset + 7 * daySize + 6 * dayGap
    readonly property int notificationWidth: 400
    property int pendingMonthDelta: 0
    // The month on its way out or in: its name and days slide and fade, the chevrons stay.
    property real monthSlideY: 0
    property real monthOpacity: 1

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
    implicitWidth: calendarWidth + notificationWidth
    implicitHeight: calendarBody.y + calendarBody.implicitHeight + inset
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

    // The calendar on the right, the notifications on its left.
    Item {
        id: calendarColumn

        anchors.top: parent.top
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

        ColumnLayout {
            id: calendarBody

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: calendarPopup.inset
            anchors.rightMargin: calendarPopup.inset
            anchors.topMargin: calendarPopup.inset
            spacing: Metrics.spacing.large
            opacity: calendarPopup.expanded ? 1 : 0

            // As tall as a button, like the notifications' header, so the two read as one
            // line. The chevrons stand over the first and last columns, each a day wide.
            RowLayout {
                Layout.fillWidth: true
                spacing: calendarPopup.dayGap

                GlassButton {
                    icon: "󰅃"
                    onClicked: calendarPopup.changeMonth(-1)
                }

                Heading {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: Session.regionalFormats.standaloneMonthName(calendarPopup.displayedMonthNumber) + " " + calendarPopup.displayedYear
                    font.pixelSize: Metrics.text.emphasis
                    opacity: calendarPopup.monthOpacity

                    transform: Translate {
                        y: calendarPopup.monthSlideY
                    }

                }

                GlassButton {
                    icon: "󰅀"
                    onClicked: calendarPopup.changeMonth(1)
                }

            }

            Grid {
                columns: 7
                spacing: calendarPopup.dayGap
                opacity: calendarPopup.monthOpacity

                transform: Translate {
                    y: calendarPopup.monthSlideY
                }

                Repeater {
                    // From the locale's first day, "Lun" rather than "lun.".
                    model: [0, 1, 2, 3, 4, 5, 6].map((offset) => {
                        return calendarPopup.capitalized(Session.regionalFormats.dayName((Session.regionalFormats.firstDayOfWeek + offset) % 7, Locale.ShortFormat).replace(/\.$/, ""));
                    })

                    Label {
                        required property string modelData

                        width: calendarPopup.daySize
                        height: calendarPopup.weekdayHeight
                        text: modelData
                        color: Colors.primary
                        font.pixelSize: Metrics.text.body
                        horizontalAlignment: Text.AlignHCenter
                    }

                }

                // Six weeks from the one the month starts in: the days before the 1st
                // and after the last belong to the months around, and read as off.
                Repeater {
                    model: 42

                    Rectangle {
                        required property int index
                        readonly property date day: new Date(calendarPopup.displayedYear, calendarPopup.displayedMonthNumber, index - calendarPopup.firstWeekday + 1)
                        readonly property bool inMonth: day.getMonth() === calendarPopup.displayedMonthNumber
                        readonly property bool isToday: inMonth && day.getDate() === calendarPopup.currentDay && calendarPopup.displayedMonthNumber === calendarPopup.currentMonth && calendarPopup.displayedYear === calendarPopup.currentYear

                        width: calendarPopup.daySize
                        height: calendarPopup.daySize
                        color: "transparent"

                        Light {
                            anchors.fill: parent
                            visible: parent.isToday
                        }

                        Label {
                            anchors.centerIn: parent
                            text: parent.day.getDate()
                            color: parent.isToday ? Colors.over(Colors.primary) : parent.inMonth ? Colors.primary : Colors.alpha(Colors.secondary, 0.5)
                            font.pixelSize: Metrics.text.emphasis
                            font.weight: parent.isToday ? Font.Bold : Font.Medium
                        }

                    }

                }

            }
        }

    }

    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: calendarColumn.left
        anchors.topMargin: calendarPopup.inset
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

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: calendarColumn.left
        anchors.topMargin: calendarPopup.inset
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
                target: calendarPopup
                property: "monthSlideY"
                to: calendarPopup.pendingMonthDelta > 0 ? -calendarPopup.daySize : calendarPopup.daySize
                token: Motion.leave.small
            }

            Anim {
                target: calendarPopup
                property: "monthOpacity"
                to: 0
                token: Motion.leave.small
            }

        }

        ScriptAction {
            script: {
                calendarPopup.monthOffset += calendarPopup.pendingMonthDelta;
                calendarPopup.monthSlideY = calendarPopup.pendingMonthDelta > 0 ? calendarPopup.daySize : -calendarPopup.daySize;
            }
        }

        ParallelAnimation {
            Anim {
                target: calendarPopup
                property: "monthSlideY"
                to: 0
                token: Motion.enter.small
            }

            Anim {
                target: calendarPopup
                property: "monthOpacity"
                to: 1
                token: Motion.enter.small
            }

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
