import QtQuick

Item {
    id: control

    required property real value
    required property string icon
    property color accent: "#cba6f7"
    property color trackColor: Qt.rgba(205 / 255, 214 / 255, 244 / 255, 0.12)
    property color iconColor: "#1e1e2e"
    // The icon as a round button in the fill (the volume's mute): plain glyph with a
    // glass halo on hover, like the player's controls.
    property bool iconButton: false
    // Written in the track after the icon (the mixer's apps): dark over the fill,
    // lavender past it, the colour changing right at the fill's edge.
    property string label: ""

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
            id: sliderFill

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(parent.height, parent.width * control.value)
            radius: parent.radius
            color: control.accent

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }

            }

            Behavior on width {
                NumberAnimation {
                    duration: 90
                    easing.type: Easing.OutCubic
                }

            }

        }

        Text {
            id: sliderLabel

            x: control.height + 4
            width: parent.width - x - 12
            anchors.verticalCenter: parent.verticalCenter
            visible: control.label !== ""
            text: control.label
            color: "#b4befe"
            elide: Text.ElideRight
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            font.weight: Font.Bold
        }

        // The same label again, cut to the fill.
        Item {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: sliderFill.width
            visible: control.label !== ""
            clip: true

            Text {
                x: sliderLabel.x
                width: sliderLabel.width
                anchors.verticalCenter: parent.verticalCenter
                text: sliderLabel.text
                color: control.iconColor
                elide: Text.ElideRight
                font: sliderLabel.font
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

    Item {
        id: iconArea

        anchors.left: parent.left
        anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        width: control.height - 4
        height: width

        GlassSurface {
            radius: width / 2
            hovered: iconTap.pressed
            opacity: control.iconButton && iconHover.hovered ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                }

            }

        }

        Text {
            anchors.centerIn: parent
            text: control.icon
            color: control.iconColor
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            font.weight: Font.Bold
        }

        HoverHandler {
            id: iconHover

            enabled: control.iconButton
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: iconTap

            enabled: control.iconButton
            onTapped: {
                iconBounce.restart();
                control.iconClicked();
            }
        }

        BounceAnimation {
            id: iconBounce

            target: iconArea
        }

    }

}
