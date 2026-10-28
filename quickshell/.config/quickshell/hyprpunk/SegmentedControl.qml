import QtQuick

// A few options side by side, one chosen (the AirPods' listening modes, the sound
// page's tabs). A mauve glass highlight slides under the chosen one with a little
// overshoot, right away on click, without waiting for the device to answer.
// In compact mode, icons sit beside their labels instead of above.
Item {
    id: control

    // [{"value": ..., "icon": "...", "label": "..."}]
    required property var options
    property var value: null
    property bool compact: false
    // What looks chosen: the one just clicked, until value catches up (or doesn't).
    property var shownValue: value
    readonly property int currentIndex: options.findIndex((option) => {
        return option.value === shownValue;
    })
    readonly property real segmentWidth: width / Math.max(1, options.length)
    // Where the highlight sits, in segments. Sliding this rather than the highlight's x
    // lets it follow the layout at once, so it doesn't fly in when the control is built.
    property real highlightIndex: Math.max(0, currentIndex)

    signal selected(var value)

    implicitHeight: compact ? 38 : 62
    onValueChanged: {
        settle.stop();
        shownValue = value;
    }

    // The device said no: back to what it actually uses.
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

        x: control.highlightIndex * control.segmentWidth + 3
        y: 3
        width: control.segmentWidth - 6
        height: control.height - 6
        radius: 13
        visible: control.currentIndex >= 0
        color: "transparent"

        GlassSurface {
            radius: highlight.radius
            hovered: true
            backgroundColor: Theme.alpha(Theme.mauve, 0.85)
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
                        color: segment.chosen ? Theme.base : Theme.mauve
                        font.family: Theme.font
                        font.pixelSize: control.compact ? 16 : 20

                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }

                        }

                    }

                    Text {
                        text: segment.modelData.label
                        color: segment.chosen ? Theme.base : Theme.lavender
                        font.family: Theme.font
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

    Behavior on highlightIndex {
        NumberAnimation {
            duration: 320
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }

    }

}
