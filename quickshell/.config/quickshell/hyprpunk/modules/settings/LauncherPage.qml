import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.config
import qs.theme

// The settings' launcher page: the apps pinned first in the launcher, and the ones it
// never shows. Every app is listed, narrowed down by what you type.
SettingsPage {
    id: page

    title: "Launcher"
    description: "Super+Space opens it. Pinned apps come first, in the order you pinned them, then the ones you use most. Hidden ones never show, even when you search."

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

    SettingRow {
        Layout.fillWidth: true
        icon: "󰀻"
        title: "Apps"
        description: LauncherSettings.pinned.length + " pinned, " + LauncherSettings.hidden.length + " hidden."

        ColumnLayout {
            width: parent.width
            spacing: Metrics.spacing.small

            FormField {
                id: filter

                Layout.fillWidth: true
                Layout.bottomMargin: Metrics.spacing.normal
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
                    spacing: Metrics.spacing.large

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
                            color: Colors.secondary
                            font.family: Metrics.font
                            font.pixelSize: Metrics.text.title
                        }

                    }

                    Text {
                        Layout.fillWidth: true
                        text: app.modelData.name
                        color: app.pinned ? Colors.primary : Colors.alpha(Colors.secondary, app.hidden ? 0.5 : 1)
                        elide: Text.ElideRight
                        font.family: Metrics.font
                        font.pixelSize: Metrics.text.emphasis
                        font.weight: app.pinned ? Font.Bold : Font.Normal
                    }

                    GlassButton {
                        icon: "󰐃"
                        label: "Pin"
                        accent: app.pinned
                        activeFocusOnTab: true
                        onClicked: LauncherSettings.setPinned(app.modelData.id, !app.pinned)
                    }

                    GlassButton {
                        icon: "󰈉"
                        label: "Hide"
                        accent: app.hidden
                        activeFocusOnTab: true
                        onClicked: LauncherSettings.setHidden(app.modelData.id, !app.hidden)
                    }

                }

            }

            Text {
                visible: page.shown.length === 0
                text: "No app matches."
                color: Colors.secondary
                font.family: Metrics.font
                font.pixelSize: Metrics.text.body
            }

        }

    }

}
