import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    required property var item
    property bool popupAbove: false
    readonly property bool menuOpen: menuAnchor.visible

    implicitWidth: 28
    implicitHeight: 28

    // Glass halo on hover, like the player controls.
    GlassSurface {
        anchors.margins: -3
        radius: 17
        hovered: true
        opacity: trayMouse.containsMouse || root.menuOpen ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }

        }

    }

    IconImage {
        anchors.centerIn: parent
        width: 24
        height: 24
        implicitSize: 24
        source: root.item.icon
    }

    ToolTipArea {
        text: root.item.tooltipTitle || root.item.title
        above: root.popupAbove
    }

    QsMenuAnchor {
        id: menuAnchor

        menu: root.item.menu
        anchor.item: root
        anchor.edges: root.popupAbove ? Edges.Top | Edges.Right : Edges.Bottom | Edges.Left
        anchor.gravity: root.popupAbove ? Edges.Top | Edges.Left : Edges.Bottom | Edges.Right
        // Clears the tray panel border above the icons.
        anchor.margins.top: root.popupAbove ? -23 : 0
    }

    MouseArea {
        id: trayMouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton && root.item.hasMenu) {
                menuAnchor.open();
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
