import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme
import qs.state
import qs.services

// What the island shows after the time: the privacy dot, the recording and the
// notifications waiting. The bar's island and the lock screen's both use it, so the lock
// starts from the island as it was and closes them while it grows into the padlock.
RowLayout {
    id: chips

    required property var bar
    // Each chip closes its width when this goes off, and opens again after.
    property bool shown: true
    property bool animated: true
    // In the bar, a click on the recording stops it. The lock only shows it.
    property bool interactive: true
    readonly property bool stopHovered: recordingHover.hovered

    // Each chip brings its own gap before it, the first one's after the time, so a closed
    // one leaves none and the time stays centred once the last one closes.
    spacing: 0

    // Privacy: a dot while something is listening or watching, green for the camera,
    // orange for the microphone alone.
    Item {
        readonly property bool shown: chips.shown && (Privacy.cameraInUse || Privacy.microphoneInUse)

        visible: Layout.preferredWidth > 0
        Layout.preferredWidth: shown ? 8 : 0
        Layout.leftMargin: shown ? 6 : 0
        implicitHeight: 8

        Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 8
            radius: 4
            scale: parent.shown ? 1 : 0
            color: Privacy.cameraInUse ? Colors.green : Colors.peach

            Behavior on scale {
                Anim {
                    token: Motion.pop
                }

            }

            Behavior on color {
                ColorAnim {
                    token: Motion.color.normal
                }

            }

        }

        Behavior on Layout.preferredWidth {
            enabled: chips.animated

            Anim {
                token: Motion.resize.normal
            }

        }

        Behavior on Layout.leftMargin {
            enabled: chips.animated

            Anim {
                token: Motion.resize.normal
            }

        }

    }

    // Recording: a pulsing red dot and how long it's been going.
    Item {
        id: recordingChip

        readonly property bool shown: chips.shown && Screenshot.recording

        visible: Layout.preferredWidth > 0
        Layout.preferredWidth: shown ? recordingRow.implicitWidth + 16 : 0
        Layout.leftMargin: shown ? 8 : 0
        implicitHeight: 24
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: recordingHover.hovered ? Colors.alpha(Colors.red, 0.28) : Colors.alpha(Colors.red, 0.16)

            Behavior on color {
                ColorAnim {
                    token: Motion.color.small
                }

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

        Behavior on Layout.preferredWidth {
            enabled: chips.animated

            Anim {
                token: Motion.resize.normal
            }

        }

        Behavior on Layout.leftMargin {
            enabled: chips.animated

            Anim {
                token: Motion.resize.normal
            }

        }

    }

    // Notifications waiting: a bell and how many. The secondary color at half opacity while Focus
    // keeps them quiet.
    Item {
        readonly property bool shown: chips.shown && chips.bar.notificationCount > 0

        visible: Layout.preferredWidth > 0
        Layout.preferredWidth: shown ? notificationBadgeRow.implicitWidth + 14 : 0
        Layout.leftMargin: shown ? 8 : 0
        implicitHeight: 24
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Colors.alpha(ShellState.doNotDisturb ? Colors.secondary : Colors.primary, 0.16)

            Behavior on color {
                ColorAnim {
                    token: Motion.color.small
                }

            }

        }

        Row {
            id: notificationBadgeRow

            anchors.verticalCenter: parent.verticalCenter
            x: 7
            spacing: Metrics.spacing.small
            opacity: ShellState.doNotDisturb ? 0.5 : 1

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ShellState.doNotDisturb ? "󰂛" : "󰂚"
                color: ShellState.doNotDisturb ? Colors.secondary : Colors.primary
                font.family: Metrics.font
                font.pixelSize: Metrics.text.emphasis
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chips.bar.notificationCount
                color: ShellState.doNotDisturb ? Colors.secondary : Colors.primary
                font.family: Metrics.font
                font.pixelSize: Metrics.text.body
                font.weight: Font.Bold
                font.features: {
                    "tnum": 1
                }
            }

        }

        Behavior on Layout.preferredWidth {
            enabled: chips.animated

            Anim {
                token: Motion.resize.normal
            }

        }

        Behavior on Layout.leftMargin {
            enabled: chips.animated

            Anim {
                token: Motion.resize.normal
            }

        }

    }

}
