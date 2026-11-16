import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config
import qs.theme
import qs.state

// The settings' appearance page: the shell's glass, the music's equalizer and wave, and the
// wallpaper and theme pickers, whose wallpaper gives every color its palette.
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
        icon: "󰝚"
        title: "Music equalizer"
        description: "The bars at the island's end, dancing while the music plays. Moving, they keep the screen redrawing, which costs a laptop's battery and smoothness. Off, they stand still."
        checkable: true
        checked: MusicSettings.equalizer
        onToggled: MusicSettings.set("equalizer", !checked)
    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰺢"
        title: "Music wave"
        description: "The wave at the bottom of the desktop and the lock screen, moving with the music. Like the equalizer, it keeps the screen redrawing."
        checkable: true
        checked: MusicSettings.wave
        onToggled: MusicSettings.set("wave", !checked)
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
