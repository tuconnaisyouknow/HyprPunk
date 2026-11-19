import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config
import qs.theme
import qs.state

// The settings' appearance page: the shell's glass, the windows that are see-through, and
// the wallpaper and theme pickers, whose wallpaper gives every color its palette.
SettingsPage {
    id: page

    title: "Appearance"
    description: "Every color comes from your wallpaper, for the shell and the apps alike."

    SettingRow {
        Layout.fillWidth: true
        icon: "󰂵"
        title: "Glass"
        description: "Classic, with a crisp rim, or liquid, see-through like the lock screen's clock."

        SegmentedControl {
            width: parent.width
            compact: true
            options: [{
                "value": "classic",
                "icon": "󰆧",
                "label": "Classic"
            }, {
                "value": "liquid",
                "icon": "󰖌",
                "label": "Liquid"
            }]
            value: Session.glassStyle
            onSelected: (value) => {
                return Quickshell.execDetached([Session.scripts + "/glassctl.sh", "set", value]);
            }
        }

    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰗌"
        title: "Transparency"
        description: "The windows the wallpaper shows through, blurred: all of them, your terminal alone, or none."

        SegmentedControl {
            width: parent.width
            compact: true
            options: [{
                "value": "all",
                "icon": "󰈈",
                "label": "All"
            }, {
                "value": "terminal",
                "icon": "󰆍",
                "label": "Terminal"
            }, {
                "value": "none",
                "icon": "󰈉",
                "label": "None"
            }]
            value: Session.transparency
            onSelected: (value) => {
                return Quickshell.execDetached([Session.scripts + "/transparencyctl.sh", "set", value]);
            }
        }

    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰸉"
        title: "Wallpaper and theme"
        description: "Picked in the island, which shows each one as it would look."

        ColumnLayout {
            width: parent.width
            spacing: Metrics.spacing.normal

            ActionRow {
                Layout.fillWidth: true
                icon: "󰸉"
                label: "Choose a wallpaper"
                onTriggered: ShellState.focused()?.open("wallpaper")
            }

            ActionRow {
                Layout.fillWidth: true
                icon: "󰏘"
                label: "Choose a theme"
                onTriggered: ShellState.focused()?.open("theme")
            }

        }

    }

}
