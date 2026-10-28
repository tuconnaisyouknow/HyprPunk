import QtQuick

// A check box for the control center's forms: a small glass square that turns mauve
// when checked, and bounces when clicked.
Item {
    id: check

    required property string label
    property bool checked: false

    signal toggled()

    implicitWidth: row.implicitWidth
    implicitHeight: 24
    opacity: enabled ? 1 : 0.45

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Rectangle {
            id: box

            width: 20
            height: 20
            radius: 7
            color: "transparent"

            GlassSurface {
                radius: parent.radius
                hovered: checkHover.hovered
                backgroundColor: check.checked ? Qt.rgba(203 / 255, 166 / 255, 247 / 255, checkHover.hovered ? 0.95 : 0.8) : "transparent"

                Behavior on backgroundColor {
                    ColorAnimation {
                        duration: 140
                    }

                }

            }

            Text {
                anchors.centerIn: parent
                visible: check.checked
                text: ""
                color: "#1e1e2e"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                font.weight: Font.Bold
            }

            BounceAnimation {
                id: checkBounce

                target: box
            }

        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: check.label
            color: "#b4befe"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
        }

    }

    HoverHandler {
        id: checkHover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: {
            checkBounce.restart();
            check.checked = !check.checked;
            check.toggled();
        }
    }

}
