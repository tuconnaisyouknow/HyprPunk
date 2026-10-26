import QtQuick

Item {
    id: control

    required property real value
    required property string icon
    property color accent: "#cba6f7"
    property color trackColor: Qt.rgba(205 / 255, 214 / 255, 244 / 255, 0.12)
    property color iconColor: "#1e1e2e"

    signal valueRequested(real value)
    signal iconClicked()

    function valueFromPointer(pointerX) {
        return Math.max(0, Math.min(1, pointerX / sliderTrack.width));
    }

    implicitWidth: 280
    implicitHeight: 30

    Rectangle {
        id: sliderTrack

        anchors.fill: parent
        radius: height / 2
        color: control.trackColor

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(parent.height, parent.width * control.value)
            radius: parent.radius
            color: control.accent

            Behavior on width {
                NumberAnimation {
                    duration: 90
                    easing.type: Easing.OutCubic
                }

            }

        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: (mouse) => {
                return control.valueRequested(control.valueFromPointer(mouse.x));
            }
            onPositionChanged: (mouse) => {
                if (pressed)
                    control.valueRequested(control.valueFromPointer(mouse.x));

            }
            onWheel: (wheel) => {
                control.valueRequested(Math.max(0, Math.min(1, control.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))));
                wheel.accepted = true;
            }
        }

    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 9
        anchors.verticalCenter: parent.verticalCenter
        text: control.icon
        color: control.iconColor
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 16
        font.weight: Font.Bold

        TapHandler {
            onTapped: control.iconClicked()
        }

    }

}
