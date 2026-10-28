import QtQuick

// An on/off switch for the control center: mauve glass when on, plain glass when off,
// the knob sliding across with a little bounce.
Rectangle {
    id: toggleSwitch

    property bool checked: false

    signal toggled()

    implicitWidth: 46
    implicitHeight: 24
    radius: 8
    color: "transparent"

    GlassSurface {
        radius: parent.radius
        hovered: switchHover.hovered
        backgroundColor: toggleSwitch.checked ? Theme.alpha(Theme.mauve, switchHover.hovered ? 0.95 : 0.8) : "transparent"

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
        radius: 6
        color: Theme.base

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
