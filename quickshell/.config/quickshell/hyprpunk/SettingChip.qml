import QtQuick

// A small on/off button of the settings, in a list's rows (pin an app, hide it): its icon
// and word on glass, in the accent while it's on. The keys reach it like any control.
Item {
    id: chip

    property string icon: ""
    required property string label
    property bool chosen: false
    readonly property real radius: height / 2

    signal clicked()

    function activate() {
        chipBounce.restart();
        clicked();
    }

    implicitWidth: row.implicitWidth + 24
    implicitHeight: 30
    activeFocusOnTab: true

    GlassSurface {
        radius: chip.radius
        hovered: chipHover.hovered
        backgroundColor: chip.chosen ? Theme.alpha(Theme.primary, 0.85) : "transparent"

        Behavior on backgroundColor {
            ColorAnimation {
                duration: 160
            }

        }

    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 6

        Text {
            visible: chip.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: chip.icon
            color: chip.chosen ? Theme.base : Theme.secondary
            font.family: Theme.font
            font.pixelSize: 13
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: chip.label
            color: chip.chosen ? Theme.base : Theme.secondary
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: chip.chosen ? Font.Bold : Font.Medium
        }

    }

    HoverHandler {
        id: chipHover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: chip.activate()
    }

    BounceAnimation {
        id: chipBounce

        target: chip
    }

}
