import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme
import qs.state
import qs.services

// What the island shows after the time: the privacy dot, the recording and the
// notifications waiting. The bar's island and the lock screen's both use it: the lock
// starts from the island as it was and keeps the privacy dot and the recording once the
// time has left with the notifications.
RowLayout {
    id: chips

    required property var bar
    // Each chip closes when this goes off, and opens again after. The notifications'
    // too when theirs does: the lock keeps them out of sight.
    property bool shown: true
    property bool notificationsShown: shown
    property bool animated: true
    // In the bar, a click on the recording stops it. The lock only shows it.
    property bool interactive: true
    readonly property bool stopHovered: recordingHover.hovered
    // How much is open before the chips, 0 to 1: the time, or on the lock screen the
    // padlock or the dots.
    property real lead: 1
    // How much of them is there, for what comes after.
    readonly property real presence: Math.min(1, privacyChip.presence + recordingChip.presence + notificationChip.presence)

    // Each chip brings its own gap before it, as much as something is open before it: a
    // gap only parts two things, so the island stays centred on whatever is left in it
    // (IslandPart).
    spacing: 0

    // Privacy: a dot while something is listening or watching, green for the camera,
    // orange for the microphone alone.
    IslandPart {
        id: privacyChip

        shown: chips.shown && (Privacy.cameraInUse || Privacy.microphoneInUse)
        animated: chips.animated
        openWidth: 8
        openHeight: 8
        gap: Metrics.spacing.normal * chips.lead

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: Privacy.cameraInUse ? Colors.green : Colors.peach

            ColorFade on color {
                token: Motion.color.normal
            }

        }

    }

    // Recording: a pulsing red dot and how long it's been going.
    IslandPart {
        id: recordingChip

        shown: chips.shown && Screenshot.recording
        animated: chips.animated
        gap: Metrics.spacing.normal * Math.min(1, chips.lead + privacyChip.presence)
        openWidth: recordingRow.implicitWidth + 16
        openHeight: 24

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: recordingHover.hovered ? Colors.alpha(Colors.red, 0.28) : Colors.alpha(Colors.red, 0.16)

            ColorFade on color {
                token: Motion.color.small
            }

        }

        Row {
            id: recordingRow

            anchors.verticalCenter: parent.verticalCenter
            x: 8
            spacing: Metrics.spacing.normal

            // The stop square on hover, the dot otherwise.
            Rectangle {
                id: recordingDot

                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: recordingHover.hovered ? 2 : 4
                color: Colors.red

                SequentialAnimation on opacity {
                    running: recordingChip.shown && !recordingHover.hovered
                    loops: Animation.Infinite
                    onRunningChanged: {
                        if (!running)
                            recordingDot.opacity = 1;

                    }

                    NumberAnimation {
                        to: 0.3
                        duration: Motion.pulse.duration
                        easing.type: Motion.pulse.easing
                    }

                    NumberAnimation {
                        to: 1
                        duration: Motion.pulse.duration
                        easing.type: Motion.pulse.easing
                    }

                }

                Behavior on radius {
                    Anim {
                        token: Motion.resize.small
                    }

                }

            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Osd.formatDuration(chips.bar.recordingElapsed)
                color: Colors.red
                font.family: Metrics.font
                font.pixelSize: Metrics.text.body
                font.weight: Font.Bold
                font.features: {
                    "tnum": 1
                }
            }

        }

        HoverHandler {
            id: recordingHover

            enabled: chips.interactive
            cursorShape: Qt.PointingHandCursor
        }

        // Taken on press, so the island under it doesn't open the calendar too.
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            enabled: chips.interactive
            onTapped: Screenshot.request("stop", "", 0)
        }

    }

    // Notifications waiting: a bell and how many. The secondary color at half opacity while Focus
    // keeps them quiet.
    IslandPart {
        id: notificationChip

        shown: chips.notificationsShown && chips.bar.notificationCount > 0
        animated: chips.animated
        gap: Metrics.spacing.normal * Math.min(1, chips.lead + privacyChip.presence + recordingChip.presence)
        openWidth: notificationBadgeRow.implicitWidth + 14
        openHeight: 24

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Colors.alpha(ShellState.doNotDisturb ? Colors.secondary : Colors.primary, 0.16)

            ColorFade on color {
                token: Motion.color.small
            }

        }

        Row {
            id: notificationBadgeRow

            anchors.verticalCenter: parent.verticalCenter
            x: 7
            spacing: Metrics.spacing.small
            opacity: ShellState.doNotDisturb ? 0.5 : 1

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                text: ShellState.doNotDisturb ? "notifications_off" : "notifications"
                color: ShellState.doNotDisturb ? Colors.secondary : Colors.primary
                size: Metrics.text.emphasis
            }

            // Centred on its digits' ink rather than its line, which sits them half a
            // pixel high next to the bell.
            Text {
                id: notificationCount

                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: implicitHeight / 2 - baselineOffset - digits.tightBoundingRect.y - digits.tightBoundingRect.height / 2
                text: chips.bar.notificationCount
                color: ShellState.doNotDisturb ? Colors.secondary : Colors.primary
                font.family: Metrics.font
                font.pixelSize: Metrics.text.body
                font.weight: Font.Bold
                font.features: {
                    "tnum": 1
                }

                TextMetrics {
                    id: digits

                    font: notificationCount.font
                    text: "0123456789"
                }

            }

        }

    }

}
