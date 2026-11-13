import QtQuick
import QtQuick.Layouts

// The settings' clipboard and history page: whether what you copy is kept, how much of
// it, and wiping what the shell remembers.
ColumnLayout {
    id: page

    spacing: 12

    Text {
        text: "Clipboard and history"
        color: Theme.primary
        font.family: Theme.font
        font.pixelSize: 20
        font.weight: Font.Bold
    }

    Text {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        text: "What the shell remembers of what you do. It all stays on this computer."
        color: Theme.secondary
        wrapMode: Text.Wrap
        font.family: Theme.font
        font.pixelSize: 12
    }

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
            spacing: 6

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
