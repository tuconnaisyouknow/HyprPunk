import QtQuick
import QtQuick.Layouts
import qs.config
import qs.theme

// The settings' lock screen page: what it shows anyone at the screen, and whether it
// blurs in and out. When it locks is in Idle and sleep.
SettingsPage {
    id: page

    title: "Lock screen"
    description: "Super+Ctrl+L locks it. When it locks on its own is in Idle and sleep."

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
        description: "The lock blurs in out of your desktop and plays its way out. Off, it covers the screen and leaves it at once, and only the island moves."
        checkable: true
        checked: LockSettings.animation
        onToggled: LockSettings.set("animation", !checked)
    }

}
