import QtQuick

// An on/off switch for the control center: accent glass when on, plain glass when off,
// the knob sliding across with a little bounce.
Rectangle {
    id: toggleSwitch

    property bool checked: false

    signal toggled()

    implicitWidth: 46
    implicitHeight: 24
    // Round like the bar's pills, the knob too.
    radius: height / 2
    color: "transparent"

    GlassSurface {
        radius: parent.radius
        hovered: switchHover.hovered
        backgroundColor: toggleSwitch.checked ? Theme.alpha(Theme.primary, switchHover.hovered ? 0.95 : 0.8) : "transparent"

        Behavior on backgroundColor {
            ColorAnimation {
                duration: 160
            }

        }

    }

    Rectangle {
        x: toggleSwitch.checked ? parent.width - width - 3 : 3
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        radius: height / 2
        // Dark on the accent, the faded secondary color on the plain glass, where dark would vanish.
        color: toggleSwitch.checked ? Theme.base : Theme.alpha(Theme.secondary, 0.5)

        Behavior on color {
            ColorAnimation {
                duration: 160
            }

        }

        Behavior on x {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }

        }

    }

    HoverHandler {
        id: switchHover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: {
            switchBounce.restart();
            toggleSwitch.toggled();
        }
    }

    BounceAnimation {
        id: switchBounce

        target: toggleSwitch
    }

}
