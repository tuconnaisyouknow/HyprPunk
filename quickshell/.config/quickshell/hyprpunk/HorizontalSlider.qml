import QtQuick

// The control center's sliders (volume, brightness, the mixer): a rounded track that
// fills up in the accent, an icon at the start, drag or click anywhere to set it. From
// the keyboard, left and right move it and Enter presses the icon's button.
Item {
    id: control

    required property real value
    required property string icon
    property color accent: Theme.primary
    property color trackColor: Theme.alpha(Theme.text, 0.12)
    property color iconColor: Theme.base
    // Makes the icon a round button inside the fill (mute, on the volume slider),
    // with a glass halo on hover like the player's controls.
    property bool iconButton: false
    // Text inside the track after the icon (an app's name in the mixer), dark over the
    // fill and in the secondary color past it, switching color exactly at the fill's edge.
    property string label: ""
    // The value the fill shows, easing after the real one. Animating it rather than the
    // fill's width lets the fill follow the layout at once, so a slider built with the
    // control center opening doesn't sweep in from zero.
    property real shownValue: value

    signal valueRequested(real value)
    signal iconClicked()

    readonly property real radius: height / 2

    function valueFromPointer(pointerX) {
        return Math.max(0, Math.min(1, pointerX / sliderTrack.width));
    }

    // A wheel notch or an arrow press.
    function nudge(delta) {
        valueRequested(Math.max(0, Math.min(1, value + delta)));
    }

    function activate() {
        if (!iconButton)
            return ;

        iconBounce.restart();
        iconClicked();
    }

    implicitWidth: 280
    implicitHeight: 30
    activeFocusOnTab: true
    Keys.onPressed: (event) => {
        const direction = Navigation.direction(event);
        if (direction !== null && direction[0] !== 0) {
            nudge(0.05 * direction[0]);
            event.accepted = true;
        }
    }

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
            width: Math.max(parent.height, parent.width * control.shownValue)
            radius: parent.radius
            color: "transparent"

            // Plain accent in the classic style. The two fills swap at once when the style
            // changes, as fading one into the other flashed darker on the way. Each eases
            // to the secondary color and back on its own when you mute.
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

        }

        Text {
            id: sliderLabel

            x: control.height + 4
            width: parent.width - x - 12
            anchors.verticalCenter: parent.verticalCenter
            visible: control.label !== ""
            text: control.label
            color: Theme.secondary
            elide: Text.ElideRight
            font.family: Theme.font
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
                control.nudge(wheel.angleDelta.y > 0 ? 0.05 : -0.05);
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
            font.family: Theme.font
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

            gesturePolicy: TapHandler.ReleaseWithinBounds
            enabled: control.iconButton
            onTapped: control.activate()
        }

        BounceAnimation {
            id: iconBounce

            target: iconArea
        }

    }

    Behavior on shownValue {
        NumberAnimation {
            duration: 90
            easing.type: Easing.OutCubic
        }

    }

}
