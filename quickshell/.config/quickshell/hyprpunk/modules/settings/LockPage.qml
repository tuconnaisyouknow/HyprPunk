import QtQuick
import QtQuick.Layouts
import qs.config
import qs.theme

// The settings' lock screen page: what it shows anyone at the screen, and whether it
// blurs in and out. When it locks is in Idle and sleep.
ColumnLayout {
    id: page

    spacing: 12

    Text {
        text: "Lock screen"
        color: Colors.primary
        font.family: Metrics.font
        font.pixelSize: 20
        font.weight: Font.Bold
    }

    Text {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        text: "Super+Ctrl+L locks it. When it locks on its own is in Idle and sleep."
        color: Colors.secondary
        wrapMode: Text.Wrap
        font.family: Metrics.font
        font.pixelSize: 12
    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰝚"
        title: "Show what's playing"
        description: "The player and its lyrics under the clock, which anyone at the screen can see and pause."
        checkable: true
        checked: LockSettings.player
        onToggled: LockSettings.set("player", !checked)
    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰗘"
        title: "Animation"
        description: "The lock blurs in out of your desktop and plays its way out. Off, it covers the screen and leaves it at once, and only the island plays its padlock."
        checkable: true
        checked: LockSettings.animation
        onToggled: LockSettings.set("animation", !checked)
    }

}
