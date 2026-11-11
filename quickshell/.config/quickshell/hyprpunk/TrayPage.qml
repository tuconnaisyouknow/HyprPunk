import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// The control center's background apps page: each app by its name, its menu unfolding
// under it, and a button to bring it back.
ColumnLayout {
    id: page

    required property var center

    // The panel's height: past it, the apps scroll under the header.
    property real maxHeight: Infinity

    signal backRequested()

    // Scrolls the list so an app whose menu just unfolded starts at the top.
    function reveal(app) {
        flickable.contentY = Math.max(0, Math.min(app.y, flickable.contentHeight - flickable.height));
    }

    spacing: 6
    onVisibleChanged: {
        if (!visible)
            flickable.contentY = 0;

    }

    PageHeader {
        id: header

        Layout.fillWidth: true
        title: "Background apps"
        toggleVisible: false
        onBackRequested: page.backRequested()
    }

    Text {
        id: description

        Layout.fillWidth: true
        Layout.bottomMargin: 6
        text: "What keeps running once its window is closed."
        color: Theme.secondary
        wrapMode: Text.Wrap
        font.family: Theme.font
        font.pixelSize: 12
    }

    // As tall as the apps and their menus, up to the panel's height. It spills a few
    // pixels over the sides so a hovered row's zoom isn't clipped, but not over the
    // top, where the list would scroll under the description.
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(appList.implicitHeight, page.maxHeight - header.implicitHeight - description.implicitHeight - description.Layout.bottomMargin - 2 * page.spacing)

        Flickable {
            id: flickable

            anchors.fill: parent
            anchors.leftMargin: -6
            anchors.rightMargin: -6
            contentHeight: appList.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: appList

                x: 6
                width: page.width
                spacing: 6

                Repeater {
                    model: Tray.items

                    ColumnLayout {
                        id: app

                        required property var modelData
                        readonly property bool expanded: page.center.trayExpanded === modelData

                        Layout.fillWidth: true
                        spacing: 4
                        // After the menu has had a frame to unfold.
                        onExpandedChanged: {
                            if (expanded)
                                Qt.callLater(page.reveal, app);

                        }

                        ControlBlock {
                            id: row

                            Layout.fillWidth: true
                            implicitHeight: 48
                            radius: 14

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                spacing: 12

                                IconImage {
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 22
                                    implicitSize: 22
                                    source: app.modelData.icon
                                }

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        width: parent.width
                                        text: Tray.name(app.modelData)
                                        color: Theme.primary
                                        elide: Text.ElideRight
                                        font.family: Theme.font
                                        font.pixelSize: 14
                                        font.weight: app.expanded ? Font.Bold : Font.Medium
                                    }

                                    Text {
                                        width: parent.width
                                        visible: text !== ""
                                        text: Tray.detail(app.modelData)
                                        color: Theme.secondary
                                        elide: Text.ElideRight
                                        font.family: Theme.font
                                        font.pixelSize: 12
                                    }

                                }

                                // Waiting for you.
                                Rectangle {
                                    visible: app.modelData.status === Status.NeedsAttention
                                    Layout.preferredWidth: 8
                                    Layout.preferredHeight: 8
                                    radius: 4
                                    color: Theme.primary
                                }

                                // Brings the app back, for apps that do more than show a menu.
                                Item {
                                    id: openButton

                                    visible: !app.modelData.onlyMenu
                                    Layout.preferredWidth: 30
                                    Layout.preferredHeight: 30

                                    GlassSurface {
                                        radius: width / 2
                                        hovered: openArea.pressed
                                        opacity: openArea.containsMouse ? 1 : 0

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: 120
                                            }

                                        }

                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰏌"
                                        color: openArea.containsMouse ? Theme.primary : Theme.secondary
                                        font.family: Theme.font
                                        font.pixelSize: 16
                                    }

                                    // A MouseArea takes the click from the row.
                                    MouseArea {
                                        id: openArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: app.modelData.activate()
                                    }

                                }

                                // Turns down as the menu unfolds.
                                Text {
                                    visible: app.modelData.hasMenu
                                    text: "󰅂"
                                    rotation: app.expanded ? 90 : 0
                                    color: row.hovered || app.expanded ? Theme.primary : Theme.secondary
                                    font.family: Theme.font
                                    font.pixelSize: 14

                                    Behavior on rotation {
                                        NumberAnimation {
                                            duration: 160
                                            easing.type: Easing.OutCubic
                                        }

                                    }

                                }

                            }

                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }

                            // The row unfolds the menu, or brings back an app that has none.
                            TapHandler {
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: {
                                    row.bounce();
                                    if (app.modelData.hasMenu) {
                                        page.center.trayExpanded = app.expanded ? null : app.modelData;
                                    } else {
                                        app.modelData.activate();
                                    }
                                }
                            }

                        }

                        TrayMenu {
                            Layout.fillWidth: true
                            Layout.leftMargin: 8
                            Layout.bottomMargin: 4
                            visible: app.expanded
                            shown: app.expanded
                            handle: app.modelData.menu
                            onTriggered: page.center.close()
                        }

                    }

                }

            }

        }

    }

}
