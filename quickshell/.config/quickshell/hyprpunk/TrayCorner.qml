import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: trayCorner

    property bool opened: false
    property bool cornerHovered: false
    property bool panelHovered: false
    property int openMenus: 0
    property real progress: opened ? 1 : 0
    readonly property real fullWidth: trayRow.implicitWidth + 53
    readonly property real fullHeight: trayRow.implicitHeight + 53

    implicitWidth: fullWidth
    implicitHeight: fullHeight
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: SystemTray.items.values.length > 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hyprpunk-tray"

    anchors {
        bottom: true
        right: true
    }

    Item {
        id: hotCorner

        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: 6
        height: 6

        HoverHandler {
            onHoveredChanged: {
                trayCorner.cornerHovered = hovered;
                if (hovered) {
                    closeDelay.stop();
                    openDelay.restart();
                } else {
                    openDelay.stop();
                    closeDelay.restart();
                }
            }
        }

    }

    Item {
        id: panel

        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: trayCorner.fullWidth * trayCorner.progress
        height: trayCorner.fullHeight * trayCorner.progress
        clip: true

        // Same shape as the control center, flipped to fit the bottom-right corner.
        CornerPanelShape {
            anchors.fill: parent
            // Same as the control center, blurred by a layer rule.
            fillColor: Qt.rgba(30 / 255, 30 / 255, 46 / 255, 0.9)
            lightFromBottom: true
            visible: width >= 64 && height >= 64

            transform: Scale {
                origin.y: panel.height / 2
                yScale: -1
            }

        }

        ClippingRectangle {
            anchors.fill: parent
            anchors.leftMargin: 25
            anchors.topMargin: 25
            color: "transparent"
            radius: 0
            topLeftRadius: 23

            Row {
                id: trayRow

                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 14
                anchors.bottomMargin: 14
                spacing: 10
                opacity: Math.max(0, trayCorner.progress * 1.6 - 0.6)

                Repeater {
                    model: SystemTray.items

                    TrayItem {
                        required property var modelData

                        item: modelData
                        popupAbove: true
                        onMenuOpenChanged: {
                            trayCorner.openMenus += menuOpen ? 1 : -1;
                            if (!menuOpen)
                                closeDelay.restart();

                        }
                        Component.onDestruction: {
                            if (menuOpen)
                                trayCorner.openMenus -= 1;

                        }
                    }

                }

            }

        }

        HoverHandler {
            onHoveredChanged: {
                trayCorner.panelHovered = hovered;
                if (hovered)
                    closeDelay.stop();
                else
                    closeDelay.restart();
            }
        }

    }

    Timer {
        id: openDelay

        interval: 120
        onTriggered: trayCorner.opened = true
    }

    Timer {
        id: closeDelay

        interval: 420
        onTriggered: {
            if (!trayCorner.cornerHovered && !trayCorner.panelHovered && trayCorner.openMenus === 0)
                trayCorner.opened = false;

        }
    }

    Behavior on progress {
        NumberAnimation {
            duration: 340
            easing.type: Easing.OutQuart
        }

    }

    mask: Region {
        Region {
            item: hotCorner
        }

        Region {
            item: panel
        }

    }

}
