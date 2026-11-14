import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.theme

// The settings' clipboard and history page: whether what you copy is kept, how much of
// it, and wiping what the shell remembers.
SettingsPage {
    id: page

    title: "Clipboard and history"
    description: "What the shell remembers of what you do. It all stays on this computer."

    SettingRow {
        Layout.fillWidth: true
        icon: "󰅌"
        title: "Clipboard history"
        description: "Keeps what you copy, to paste it again from Super+V. Passwords from a password manager are never kept."
        checkable: true
        checked: HistorySettings.clipboard
        onToggled: HistorySettings.set("clipboard", !HistorySettings.clipboard)
    }

    SettingRow {
        Layout.fillWidth: true
        enabled: HistorySettings.clipboard
        opacity: enabled ? 1 : 0.5
        icon: "󰋚"
        title: "Remember up to"
        description: "The oldest copies go once there are more."

        SettingChoices {
            width: parent.width
            values: [50, 100, 250, 500, 750, 1000]
            value: HistorySettings.size
            label: (items) => {
                return items + " copies";
            }
            onSelected: (value) => {
                return HistorySettings.set("size", value);
            }
        }

    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰃢"
        title: "Clear"
        description: "Asks you to confirm, and can't be undone."

        ColumnLayout {
            width: parent.width
            spacing: Metrics.spacing.normal

            ActionRow {
                Layout.fillWidth: true
                icon: "󰅌"
                label: "Clear the clipboard history"
                destructive: true
                onTriggered: HistorySettings.clear("clipboard")
            }

            ActionRow {
                Layout.fillWidth: true
                icon: "󰀻"
                label: "Clear the launcher's recent apps"
                destructive: true
                onTriggered: HistorySettings.clear("launcher")
            }

            ActionRow {
                Layout.fillWidth: true
                icon: "󰞅"
                label: "Clear the recent emojis"
                destructive: true
                onTriggered: HistorySettings.clear("emoji")
            }

        }

    }

}
