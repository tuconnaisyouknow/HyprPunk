import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// A background app's menu, unfolded inside the control center's page rather than in a
// window of its own. A submenu unfolds the same way under its entry, one step in.
Column {
    id: menu

    // The menu to show: the app's, or the entry a submenu unfolds.
    property var handle: null
    property bool shown: false
    // The entry whose submenu is unfolded.
    property int openIndex: -1

    // An entry was chosen. Like any menu, it's done: apps only send their menu up to
    // date when it's opened again (a dismissed notification would stay listed).
    signal triggered()

    onShownChanged: openIndex = -1

    QsMenuOpener {
        id: opener

        // Only while shown, since apps refresh their menu every time it opens.
        menu: menu.shown ? menu.handle : null
    }

    Repeater {
        model: opener.children

        Column {
            id: entry

            required property var modelData
            required property int index
            readonly property bool selectable: !modelData.isSeparator && modelData.enabled
            readonly property bool open: menu.openIndex === index
            readonly property bool current: selectable && (entryMouse.containsMouse || open)

            width: menu.width

            Item {
                visible: entry.modelData.isSeparator
                width: parent.width
                height: visible ? 9 : 0

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 10
                    width: parent.width - 20
                    height: 1
                    color: Theme.alpha(Theme.secondary, 0.2)
                }

            }

            Item {
                // A submenu unfolds, any other entry does its job and the menu is done.
                function activate() {
                    if (entry.modelData.hasChildren) {
                        menu.openIndex = entry.open ? -1 : entry.index;
                        return ;
                    }
                    entry.modelData.triggered();
                    menu.triggered();
                }

                readonly property real radius: 10

                visible: !entry.modelData.isSeparator
                width: parent.width
                height: visible ? 34 : 0
                activeFocusOnTab: entry.selectable

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: entry.current ? Theme.alpha(Theme.primary, 0.16) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 100
                        }

                    }

                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 8
                    opacity: entry.modelData.enabled ? 1 : 0.5

                    // Check boxes and radio buttons, in the shell's colors.
                    Text {
                        visible: text !== ""
                        text: {
                            const item = entry.modelData;
                            if (item.buttonType === QsMenuButtonType.CheckBox)
                                return item.checkState === Qt.Checked ? "󰄵" : item.checkState === Qt.PartiallyChecked ? "󰡖" : "󰄱";

                            if (item.buttonType === QsMenuButtonType.RadioButton)
                                return item.checkState === Qt.Checked ? "󰐾" : "󰄰";

                            return "";
                        }
                        color: entry.modelData.checkState === Qt.Checked ? Theme.primary : Theme.secondary
                        font.family: Theme.font
                        font.pixelSize: 15
                    }

                    IconImage {
                        visible: entry.modelData.icon !== ""
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        implicitSize: 16
                        source: entry.modelData.icon
                    }

                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: entry.modelData.text
                        color: entry.current ? Theme.primary : Theme.secondary
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: entry.current ? Font.Medium : Font.Normal
                    }

                    // Turns down as its submenu unfolds.
                    Text {
                        visible: entry.modelData.hasChildren
                        text: "󰅂"
                        rotation: entry.open ? 90 : 0
                        color: entry.current ? Theme.primary : Theme.secondary
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

                MouseArea {
                    id: entryMouse

                    anchors.fill: parent
                    enabled: entry.selectable
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.activate()
                }

            }

            // Held at the submenu's height rather than left to the Loader, which keeps the
            // last one's once it's folded and leaves a hole in the menu.
            Loader {
                x: 16
                width: parent.width - 16
                height: active && item !== null ? item.implicitHeight : 0
                active: entry.open
                source: Qt.resolvedUrl("TrayMenu.qml")
                onLoaded: {
                    // Apart from its entry, so the two highlights don't run together.
                    item.topPadding = 4;
                    item.bottomPadding = 4;
                    item.handle = Qt.binding(() => {
                        return entry.modelData;
                    });
                    item.shown = true;
                    item.triggered.connect(menu.triggered);
                }
            }

        }

    }

}
