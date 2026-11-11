import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// One background app in the control center: left click brings it back, middle click
// does its second action, right click opens its menu (apps that only have a menu open
// it on any click). An accent dot says it's waiting for you.
Item {
    id: root

    required property var item
    readonly property alias hovered: trayMouse.containsMouse

    signal menuRequested()

    implicitWidth: 34
    implicitHeight: 34

    // Glass halo on hover, like the player controls.
    GlassSurface {
        radius: width / 2
        hovered: trayMouse.pressed
        opacity: trayMouse.containsMouse ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }

        }

    }

    IconImage {
        anchors.centerIn: parent
        width: 22
        height: 22
        implicitSize: 22
        source: root.item.icon
    }

    Rectangle {
        visible: root.item.status === Status.NeedsAttention
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 3
        width: 8
        height: 8
        radius: 4
        color: Theme.primary
    }

    BounceAnimation {
        id: bounce

        target: root
    }

    MouseArea {
        id: trayMouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            bounce.restart();
            if (root.item.hasMenu && (mouse.button === Qt.RightButton || root.item.onlyMenu)) {
                root.menuRequested();
            } else if (mouse.button === Qt.MiddleButton) {
                root.item.secondaryActivate();
            } else {
                root.item.activate();
            }
        }
        onWheel: (wheel) => {
            return root.item.scroll(wheel.angleDelta.y, false);
        }
    }

}
