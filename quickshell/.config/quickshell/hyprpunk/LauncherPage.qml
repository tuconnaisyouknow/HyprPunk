import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// The settings' launcher page: the apps pinned first in the launcher, and the ones it
// never shows. Every app is listed, narrowed down by what you type.
ColumnLayout {
    id: page

    // Your apps by name, then the ones matching what's typed. The list stays the same
    // while you pin or hide, so the row you're on keeps the keyboard.
    readonly property var apps: DesktopEntries.applications.values.filter((entry) => {
        return !entry.noDisplay;
    }).sort((a, b) => {
        return a.name.localeCompare(b.name);
    })
    readonly property string needle: filter.text.trim().toLowerCase()
    readonly property var shown: needle === "" ? apps : apps.filter((entry) => {
        return entry.name.toLowerCase().includes(needle) || entry.id.toLowerCase().includes(needle);
    })

    spacing: 12

    Text {
        text: "Launcher"
        color: Theme.primary
        font.family: Theme.font
        font.pixelSize: 20
        font.weight: Font.Bold
    }

    Text {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        text: "Super+Space opens it. Pinned apps come first, in the order you pinned them, then the ones you use most. Hidden ones never show, even when you search."
        color: Theme.secondary
        wrapMode: Text.Wrap
        font.family: Theme.font
        font.pixelSize: 12
    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰀻"
        title: "Apps"
        description: LauncherSettings.pinned.length + " pinned, " + LauncherSettings.hidden.length + " hidden."

        ColumnLayout {
            width: parent.width
            spacing: 4

            FormField {
                id: filter

                Layout.fillWidth: true
                Layout.bottomMargin: 6
                placeholder: "Find an app"
            }

            Repeater {
                model: page.shown

                RowLayout {
                    id: app

                    required property var modelData
                    readonly property bool pinned: LauncherSettings.pinned.includes(modelData.id)
                    readonly property bool hidden: LauncherSettings.hidden.includes(modelData.id)
                    readonly property string iconPath: Quickshell.iconPath(modelData.icon, true)

                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    spacing: 12

                    Item {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24

                        IconImage {
                            anchors.fill: parent
                            visible: app.iconPath !== ""
                            source: app.iconPath
                            asynchronous: true
                            opacity: app.hidden ? 0.5 : 1
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: app.iconPath === ""
                            text: "󰀻"
                            color: Theme.secondary
                            font.family: Theme.font
                            font.pixelSize: 18
                        }

                    }

                    Text {
                        Layout.fillWidth: true
                        text: app.modelData.name
                        color: app.pinned ? Theme.primary : Theme.alpha(Theme.secondary, app.hidden ? 0.5 : 1)
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: app.pinned ? Font.Bold : Font.Normal
                    }

                    SettingChip {
                        icon: "󰐃"
                        label: "Pin"
                        chosen: app.pinned
                        onClicked: LauncherSettings.setPinned(app.modelData.id, !app.pinned)
                    }

                    SettingChip {
                        icon: "󰈉"
                        label: "Hide"
                        chosen: app.hidden
                        onClicked: LauncherSettings.setHidden(app.modelData.id, !app.hidden)
                    }

                }

            }

            Text {
                visible: page.shown.length === 0
                text: "No app matches."
                color: Theme.secondary
                font.family: Theme.font
                font.pixelSize: 12
            }

        }

    }

}
