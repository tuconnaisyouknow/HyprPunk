import QtQuick

// Choice of one option among a few, side by side (the AirPods' listening modes, the
// sound page's tabs): the chosen one sits on a mauve glass highlight that slides over
// with a little overshoot. The highlight moves at once on a click, before the device
// has answered. Compact, an option's icon sits beside its label instead of above it.
Item {
    id: control

    // [{"value": ..., "icon": "...", "label": "..."}]
    required property var options
    property var value: null
    property bool compact: false
    // The option shown chosen: the one clicked, until value follows (or does not).
    property var shownValue: value
    readonly property int currentIndex: options.findIndex((option) => {
        return option.value === shownValue;
    })
    readonly property real segmentWidth: width / Math.max(1, options.length)

    signal selected(var value)

    implicitHeight: compact ? 38 : 62
    onValueChanged: {
        settle.stop();
        shownValue = value;
    }

    // The device did not take the option: back to its own.
    Timer {
        id: settle

        interval: 2500
        onTriggered: control.shownValue = control.value
    }

    // The track.
    GlassSurface {
        radius: 16
    }

    Rectangle {
        id: highlight

        x: control.currentIndex * control.segmentWidth + 3
        y: 3
        width: control.segmentWidth - 6
        height: control.height - 6
        radius: 13
        visible: control.currentIndex >= 0
        color: "transparent"

        GlassSurface {
            radius: highlight.radius
            hovered: true
            backgroundColor: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.85)
        }

        Behavior on x {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }

        }

    }

    Row {
        anchors.fill: parent

        Repeater {
            model: control.options

            Item {
                id: segment

                required property var modelData
                required property int index
                readonly property bool chosen: index === control.currentIndex

                width: control.segmentWidth
                height: control.height

                Grid {
                    id: content

                    anchors.centerIn: parent
                    columns: control.compact ? 2 : 1
                    columnSpacing: 6
                    rowSpacing: 3
                    horizontalItemAlignment: Grid.AlignHCenter
                    verticalItemAlignment: Grid.AlignVCenter

                    Text {
                        text: segment.modelData.icon
                        color: segment.chosen ? "#1e1e2e" : "#cba6f7"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: control.compact ? 16 : 20

                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }

                        }

                    }

                    Text {
                        text: segment.modelData.label
                        color: segment.chosen ? "#1e1e2e" : "#b4befe"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: control.compact ? 12 : 10
                        font.weight: segment.chosen ? Font.Bold : Font.Medium

                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }

                        }

                    }

                }

                HoverHandler {
                    id: segmentHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        segmentBounce.restart();
                        if (segment.chosen)
                            return ;

                        control.shownValue = segment.modelData.value;
                        settle.restart();
                        control.selected(segment.modelData.value);

                    }
                }

                BounceAnimation {
                    id: segmentBounce

                    target: content
                }

                // A soft glass halo under the pointer, on the options not chosen.
                GlassSurface {
                    anchors.margins: 3
                    radius: 13
                    opacity: segmentHover.hovered && !segment.chosen ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                        }

                    }

                }

            }

        }

    }

}
