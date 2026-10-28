import QtQuick
import Quickshell
import Quickshell.Widgets

// One app in the tray: left click opens it, middle click does its second action,
// right click shows its menu (apps that only have a menu open it on any click).
Item {
    id: root

    required property var item
    property bool popupAbove: false
    readonly property bool menuOpen: trayMenu.visible

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

    TrayMenu {
        id: trayMenu

        handle: root.item.menu
        anchorItem: root
        onDismissed: close()
    }

    MouseArea {
        id: trayMouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            // Some items only have a menu, opened by any click.
            if (root.item.hasMenu && (mouse.button === Qt.RightButton || root.item.onlyMenu)) {
                if (trayMenu.visible) {
                    trayMenu.close();
                } else {
                    // The tray's window ends at the screen's right edge.
                    const window = root.QsWindow.window;
                    trayMenu.anchorRight = window.screen.width - window.width + root.QsWindow.itemPosition(root).x + root.width;
                    trayMenu.visible = true;
                }
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
