import QtQuick
import QtQuick.Layouts

// A labelled drop-down for the control center's forms. Shows the current option,
// and a click unfolds the others underneath.
ColumnLayout {
    id: select

    required property string label
    // [{"label": "...", ...}]: the entries' other keys are the caller's.
    required property var options
    property int currentIndex: 0
    property bool expanded: false
    readonly property var current: options[currentIndex] || null

    signal activated(int index)

    spacing: 5

    Text {
        text: select.label
        color: Theme.lavender
        font.family: Theme.font
        font.pixelSize: 12
        font.weight: Font.Bold
    }

    Rectangle {
        id: box

        Layout.fillWidth: true
        implicitHeight: 34
        radius: 12
        color: Theme.alpha(Theme.crust, boxHover.hovered ? 0.6 : 0.45)
        opacity: select.enabled ? 1 : 0.45

        Text {
            anchors.left: parent.left
            anchors.right: chevron.left
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: select.current ? select.current.label : ""
            color: Theme.mauve
            font.family: Theme.font
            font.pixelSize: 14
        }

        Text {
            id: chevron

            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "󰅀"
            color: Theme.lavender
            rotation: select.expanded ? 180 : 0
            font.family: Theme.font
            font.pixelSize: 14

            Behavior on rotation {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }

            }

        }

        HoverHandler {
            id: boxHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: {
                boxBounce.restart();
                select.expanded = !select.expanded;
            }
        }

        BounceAnimation {
            id: boxBounce

            target: box
        }

        Behavior on color {
            ColorAnimation {
                duration: 120
            }

        }

    }

    // The options, unfolded under the field.
    Item {
        Layout.fillWidth: true
        implicitHeight: select.expanded ? optionColumn.implicitHeight : 0
        clip: true
        visible: implicitHeight > 0

        Column {
            id: optionColumn

            width: parent.width
            topPadding: 2
            spacing: 2

            Repeater {
                model: select.options

                Rectangle {
                    id: option

                    required property var modelData
                    required property int index

                    width: optionColumn.width
                    height: 32
                    radius: 10
                    color: optionHover.hovered ? Theme.alpha(Theme.mauve, 0.16) : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.right: check.left
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: option.modelData.label
                        color: option.index === select.currentIndex ? Theme.mauve : Theme.lavender
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: option.index === select.currentIndex ? Font.Bold : Font.Normal
                    }

                    Text {
                        id: check

                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        visible: option.index === select.currentIndex
                        text: ""
                        color: Theme.mauve
                        font.family: Theme.font
                        font.pixelSize: 12
                    }

                    HoverHandler {
                        id: optionHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: {
                            select.currentIndex = option.index;
                            select.expanded = false;
                            select.activated(option.index);
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 100
                        }

                    }

                }

            }

        }

        Behavior on implicitHeight {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }

        }

    }

}
