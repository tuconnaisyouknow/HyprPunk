import QtQuick

// The control center's sliders (volume, brightness, the mixer): a rounded track that
// fills up in mauve, an icon at the start, drag or click anywhere to set it.
Item {
    id: control

    required property real value
    required property string icon
    property color accent: "#cba6f7"
    property color trackColor: Qt.rgba(205 / 255, 214 / 255, 244 / 255, 0.12)
    property color iconColor: "#1e1e2e"
    // Makes the icon a round button inside the fill (mute, on the volume slider),
    // with a glass halo on hover like the player's controls.
    property bool iconButton: false
    // Text inside the track after the icon (an app's name in the mixer), dark over the
    // fill and lavender past it, switching color exactly at the fill's edge.
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
        color: fillGlass.liquid ? "transparent" : control.trackColor

        // The empty track too, with the liquid glass's rim.
        GlassSurface {
            visible: liquid
            radius: sliderTrack.radius
        }

        Rectangle {
            id: sliderFill

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(parent.height, parent.width * control.value)
            radius: parent.radius
            color: "transparent"

            // Plain mauve in the classic style. The two fills swap at once when the style
            // changes, as fading one into the other flashed darker on the way. Each eases
            // to lavender and back on its own when you mute.
            Rectangle {
                anchors.fill: parent
                visible: !fillGlass.liquid
                radius: parent.radius
                color: control.accent

                Behavior on color {
                    ColorAnimation {
                        duration: 140
                    }

                }

            }

            // In the liquid style the fill turns to glass like the selections, so it
            // doesn't look stuck on top of them.
            GlassSurface {
                id: fillGlass

                visible: liquid
                radius: sliderFill.radius
                backgroundColor: control.accent

                Behavior on backgroundColor {
                    ColorAnimation {
                        duration: 140
                    }

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
