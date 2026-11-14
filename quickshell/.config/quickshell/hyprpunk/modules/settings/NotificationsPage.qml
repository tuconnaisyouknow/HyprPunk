import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.config
import qs.theme

// The settings' notifications page: how long they stay out of the island, and which
// apps get to pop up at all.
SettingsPage {
    id: page

    title: "Notifications"
    description: "How they pop up out of the island. Focus, in the control center, keeps all but the urgent ones away."

    SettingRow {
        Layout.fillWidth: true
        icon: "󰔛"
        title: "How long they stay"
        description: "For the apps that don't say. One stays while the pointer is on it, and urgent ones until you close them."

        SettingChoices {
            width: parent.width
            values: [0, 3, 5, 8, 10, 15]
            value: NotificationSettings.duration
            label: (seconds) => {
                return seconds === 0 ? "Until closed" : seconds + " s";
            }
            onSelected: (value) => {
                return NotificationSettings.setDuration(value);
            }
        }

    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰀻"
        title: "Apps"
        description: "Every app that has sent you a notification. Turn one off and its notifications wait in the center without popping up."

        Column {
            width: parent.width
            spacing: Metrics.spacing.small

            Text {
                visible: NotificationSettings.apps.length === 0
                text: "No app has sent a notification yet."
                color: Colors.secondary
                font.family: Metrics.font
                font.pixelSize: Metrics.text.body
            }

            Repeater {
                model: NotificationSettings.apps

                RowLayout {
                    id: app

                    // Its desktop entry, or the name it sends (NotificationSettings).
                    required property string modelData
                    readonly property bool muted: NotificationSettings.muted(modelData)
                    // Its icon and proper name.
                    readonly property var entry: DesktopEntries.byId(modelData) ?? DesktopEntries.heuristicLookup(modelData)
                    readonly property string iconPath: entry !== null ? Quickshell.iconPath(entry.icon, true) : ""

                    width: parent.width
                    height: 36
                    spacing: Metrics.spacing.large

                    Item {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24

                        IconImage {
                            anchors.fill: parent
                            visible: app.iconPath !== ""
                            source: app.iconPath
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: app.iconPath === ""
                            text: "󰂚"
                            color: Colors.secondary
                            font.family: Metrics.font
                            font.pixelSize: Metrics.text.title
                        }

                    }

                    Text {
                        Layout.fillWidth: true
                        text: app.entry !== null ? app.entry.name : app.modelData
                        color: Colors.alpha(Colors.secondary, app.muted ? 0.5 : 1)
                        elide: Text.ElideRight
                        font.family: Metrics.font
                        font.pixelSize: Metrics.text.emphasis
                    }

                    ToggleSwitch {
                        checked: !app.muted
                        onToggled: NotificationSettings.setMuted(app.modelData, !app.muted)
                    }

                }

            }

        }

    }

}
