import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config
import qs.theme
import qs.state

// The settings' appearance page: the shell's glass, the music's cover and wave, and the
// wallpaper and theme pickers, whose wallpaper gives every color its palette.
ColumnLayout {
    id: page

    spacing: 12

    Text {
        text: "Appearance"
        color: Colors.primary
        font.family: Metrics.font
        font.pixelSize: 20
        font.weight: Font.Bold
    }

    Text {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        text: "Every color comes from your wallpaper, for the shell and the apps alike."
        color: Colors.secondary
        wrapMode: Text.Wrap
        font.family: Metrics.font
        font.pixelSize: 12
    }

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
        icon: "󰀥"
        title: "Music cover"
        description: "The cover in the bar, spinning like a record while the music plays, still, or left out for a plain record. Spinning, it keeps the screen redrawing, which costs a laptop's battery and smoothness."

        SegmentedControl {
            width: parent.width
            compact: true
            options: [{
                "value": "spinning",
                "icon": "󰑓",
                "label": "Spinning"
            }, {
                "value": "still",
                "icon": "󰏤",
                "label": "Still"
            }, {
                "value": "off",
                "icon": "󰝛",
                "label": "Off"
            }]
            value: MusicSettings.cover
            onSelected: (value) => {
                return MusicSettings.set("cover", value);
            }
        }

    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰺢"
        title: "Music wave"
        description: "The wave at the bottom of the desktop and the lock screen, moving with the music. Like a spinning cover, it keeps the screen redrawing."
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
            spacing: 6

            ActionRow {
                Layout.fillWidth: true
                icon: "󰸉"
                label: "Choose a wallpaper"
                onTriggered: ShellState.requestPanel("wallpaper", "open")
            }

            ActionRow {
                Layout.fillWidth: true
                icon: "󰏘"
                label: "Choose a theme"
                onTriggered: ShellState.requestPanel("theme", "open")
            }

        }

    }

}
