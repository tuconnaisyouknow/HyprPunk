import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.components
import qs.services
import qs.theme

// The control center's background apps page: each app by its name, its menu unfolding
// under it, and a button to bring it back. One menu at a time: opening another folds the
// last one back as it unfolds.
ControlPage {
    id: page

    // The app whose menu is unfolded.
    property var expandedApp: null

    // Opens with this app's menu already unfolded (or none).
    function show(app) {
        expandedApp = app;
        stack.push(pageName);
    }

    pageName: "tray"
    spacing: Metrics.spacing.normal

    // The last app quit from its own menu: nothing left here.
    Connections {
        function onItemsChanged() {
            if (page.current && Tray.items.length === 0)
                page.back();

        }

        target: Tray
    }

    // Left with its menu folded, so the next time it opens the app sends it up to date.
    onVisibleChanged: {
        if (!visible) {
            flickable.contentY = 0;
            expandedApp = null;
        }
    }

    PageHeader {
        id: header

        Layout.fillWidth: true
        title: "Background apps"
        toggleVisible: false
        onBackRequested: page.back()
    }

    Text {
        id: description

        Layout.fillWidth: true
        Layout.bottomMargin: Metrics.spacing.normal
        text: "What keeps running once its window is closed."
        color: Colors.secondary
        wrapMode: Text.Wrap
        font.family: Metrics.font
        font.pixelSize: Metrics.text.body
    }

    // As tall as the apps and their menus, up to the panel's height. It spills a few
    // pixels over the sides so a hovered row's zoom isn't clipped, but not over the
    // top, where the list would scroll under the description.
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(appList.implicitHeight, page.stack.maxHeight - header.implicitHeight - description.implicitHeight - description.Layout.bottomMargin - 2 * page.spacing)

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
                spacing: Metrics.spacing.normal

                Repeater {
                    // The icons stay as apps come and go.
                    model: ScriptModel {
                        values: Tray.items
                    }

                    ColumnLayout {
                        id: app

                        required property var modelData
                        readonly property bool expanded: page.expandedApp === modelData

                        Layout.fillWidth: true
                        spacing: 0

                        // The list follows the menu as it unfolds, so the app ends at the
                        // top when there's room below it.
                        Binding {
                            target: flickable
                            property: "contentY"
                            value: Math.max(0, Math.min(app.y, flickable.contentHeight - flickable.height))
                            when: app.expanded && menuFold.moving
                            restoreMode: Binding.RestoreNone
                        }

                        // The row unfolds the menu, or brings back an app that has none;
                        // its button (or Shift+Enter) brings the app back.
                        ControlBlock {
                            id: row

                            function activate() {
                                bounce();
                                if (app.modelData.hasMenu)
                                    page.expandedApp = app.expanded ? null : app.modelData;
                                else
                                    app.modelData.activate();
                            }

                            function activateAlt() {
                                if (!app.modelData.onlyMenu)
                                    app.modelData.activate();

                            }

                            Layout.fillWidth: true
                            implicitHeight: 48
                            radius: Metrics.radius.normal
                            activeFocusOnTab: true

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Metrics.spacing.large
                                anchors.rightMargin: Metrics.spacing.normal
                                spacing: Metrics.spacing.large

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
                                        color: Colors.primary
                                        elide: Text.ElideRight
                                        font.family: Metrics.font
                                        font.pixelSize: Metrics.text.emphasis
                                        font.weight: app.expanded ? Font.Bold : Font.Medium
                                    }

                                    Text {
                                        width: parent.width
                                        visible: text !== ""
                                        text: Tray.detail(app.modelData)
                                        color: Colors.secondary
                                        elide: Text.ElideRight
                                        font.family: Metrics.font
                                        font.pixelSize: Metrics.text.body
                                    }

                                }

                                // Waiting for you.
                                Rectangle {
                                    visible: app.modelData.status === Status.NeedsAttention
                                    Layout.preferredWidth: 8
                                    Layout.preferredHeight: 8
                                    radius: 4
                                    color: Colors.primary
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
                                            Anim {
                                                token: Motion.color.small
                                            }

                                        }

                                    }

                                    Icon {
                                        anchors.centerIn: parent
                                        text: "open_in_new"
                                        color: openArea.containsMouse ? Colors.primary : Colors.secondary
                                        size: Metrics.text.title
                                    }

                                    // A MouseArea takes the click from the row.
                                    MouseArea {
                                        id: openArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: row.activateAlt()
                                    }

                                }

                                // Turns down as the menu unfolds.
                                Icon {
                                    visible: app.modelData.hasMenu
                                    text: "keyboard_arrow_right"
                                    rotation: app.expanded ? 90 : 0
                                    color: row.hovered || app.expanded ? Colors.primary : Colors.secondary
                                    size: Metrics.text.emphasis

                                    Behavior on rotation {
                                        Anim {
                                            token: Motion.move.small
                                        }

                                    }

                                }

                            }

                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: row.activate()
                            }

                        }

                        // Its gaps inside the fold, so they come and go with it.
                        Fold {
                            id: menuFold

                            Layout.fillWidth: true
                            open: app.expanded

                            TrayMenu {
                                x: Metrics.spacing.normal
                                width: parent.width - Metrics.spacing.normal
                                topPadding: Metrics.spacing.small
                                bottomPadding: Metrics.spacing.small
                                shown: menuFold.out
                                handle: app.modelData.menu
                                onTriggered: page.stack.closeRequested()
                            }

                        }

                    }

                }

            }

        }

    }

}
