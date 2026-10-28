import QtQuick
import QtQuick.Layouts

// A row in the control center's lists (networks, devices, outputs): icon, title,
// an optional subtitle and something on the right.
ControlBlock {
    id: row

    required property string icon
    required property string title
    property string subtitle: ""
    property string trailing: ""
    property bool highlighted: false
    // A round info button at the end, for a saved network or a paired device.
    property bool detailsAvailable: false

    signal clicked()
    signal detailsRequested()

    implicitHeight: 48
    radius: 14

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: row.detailsAvailable ? 8 : 14
        spacing: 12

        Text {
            text: row.icon
            color: row.highlighted ? Theme.mauve : Theme.lavender
            font.family: Theme.font
            font.pixelSize: 18
        }

        Column {
            Layout.fillWidth: true
            spacing: 1

            Text {
                width: parent.width
                text: row.title
                color: Theme.mauve
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: row.highlighted ? Font.Bold : Font.Medium
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: row.subtitle
                color: Theme.lavender
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 12
            }

        }

        Text {
            visible: text !== ""
            text: row.trailing
            color: Theme.lavender
            font.family: Theme.font
            font.pixelSize: 14
        }

        // Plain glyph with a glass halo on hover, like the player's controls.
        Item {
            id: detailsButton

            visible: row.detailsAvailable
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30

            GlassSurface {
                radius: width / 2
                hovered: detailsArea.pressed
                opacity: detailsArea.containsMouse ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                    }

                }

            }

            Text {
                anchors.centerIn: parent
                text: "󰋽"
                color: detailsArea.containsMouse ? Theme.mauve : Theme.lavender
                font.family: Theme.font
                font.pixelSize: 17
            }

            // A MouseArea takes the click from the row.
            MouseArea {
                id: detailsArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    detailsBounce.restart();
                    row.detailsRequested();
                }
            }

            BounceAnimation {
                id: detailsBounce

                target: detailsButton
            }

        }

    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: {
            row.bounce();
            row.clicked();
        }
    }

}
