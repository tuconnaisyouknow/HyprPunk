import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

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
        color: Colors.secondary
        font.family: Metrics.font
        font.pixelSize: Metrics.text.body
        font.weight: Font.Bold
    }

    Rectangle {
        id: box

        Layout.fillWidth: true
        implicitHeight: 34
        function activate() {
            boxBounce.restart();
            select.expanded = !select.expanded;
        }

        radius: Metrics.radius.normal
        color: Colors.alpha(Colors.crust, boxHover.hovered ? 0.6 : 0.45)
        opacity: select.enabled ? 1 : 0.45
        activeFocusOnTab: true

        Text {
            anchors.left: parent.left
            anchors.right: chevron.left
            anchors.leftMargin: Metrics.spacing.large
            anchors.rightMargin: Metrics.spacing.normal
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: select.current ? select.current.label : ""
            color: Colors.primary
            font.family: Metrics.font
            font.pixelSize: Metrics.text.emphasis
        }

        Text {
            id: chevron

            anchors.right: parent.right
            anchors.rightMargin: Metrics.spacing.large
            anchors.verticalCenter: parent.verticalCenter
            text: "󰅀"
            color: Colors.secondary
            rotation: select.expanded ? 180 : 0
            font.family: Metrics.font
            font.pixelSize: Metrics.text.emphasis

            Behavior on rotation {
                Anim {
                    token: Motion.move.normal
                }

            }

        }

        HoverHandler {
            id: boxHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: box.activate()
        }

        BounceAnimation {
            id: boxBounce

            target: box
        }

        Behavior on color {
            ColorAnim {
                token: Motion.color.small
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
            topPadding: Metrics.spacing.hairline
            spacing: Metrics.spacing.hairline

            Repeater {
                model: select.options

                Rectangle {
                    id: option

                    required property var modelData
                    required property int index

                    function activate() {
                        select.currentIndex = index;
                        select.expanded = false;
                        select.activated(index);
                    }

                    width: optionColumn.width
                    height: 32
                    radius: Metrics.radius.normal
                    activeFocusOnTab: true
                    color: optionHover.hovered ? Colors.alpha(Colors.primary, 0.16) : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.right: check.left
                        anchors.leftMargin: Metrics.spacing.large
                        anchors.rightMargin: Metrics.spacing.normal
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: option.modelData.label
                        color: option.index === select.currentIndex ? Colors.primary : Colors.secondary
                        font.family: Metrics.font
                        font.pixelSize: Metrics.text.emphasis
                        font.weight: option.index === select.currentIndex ? Font.Bold : Font.Normal
                    }

                    Text {
                        id: check

                        anchors.right: parent.right
                        anchors.rightMargin: Metrics.spacing.large
                        anchors.verticalCenter: parent.verticalCenter
                        visible: option.index === select.currentIndex
                        text: ""
                        color: Colors.primary
                        font.family: Metrics.font
                        font.pixelSize: Metrics.text.body
                    }

                    HoverHandler {
                        id: optionHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: option.activate()
                    }

                    Behavior on color {
                        ColorAnim {
                            token: Motion.color.small
                        }

                    }

                }

            }

        }

        Behavior on implicitHeight {
            Anim {
                token: Motion.resize.normal
            }

        }

    }

}
