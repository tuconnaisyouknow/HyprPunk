import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.theme

// The settings' clipboard and history page: whether what you copy is kept, how much of
// it, and wiping what the shell remembers. Each clear shows what its history holds, so
// an emptied one says so itself and has nothing left to press.
SettingsPage {
    id: page

    // What a history holds, in its own unit: "56 copies", "empty", nothing until counted.
    function held(history, one, many) {
        const count = HistorySettings.counts[history];
        if (count === undefined)
            return "";

        return count === 0 ? "empty" : count + " " + (count === 1 ? one : many);
    }

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
                detail: page.held("clipboard", "copy", "copies")
                enabled: HistorySettings.counts.clipboard !== 0
                onTriggered: HistorySettings.clear("clipboard")
            }

            ActionRow {
                Layout.fillWidth: true
                icon: "󰀻"
                label: "Clear the launcher's recent apps"
                destructive: true
                detail: page.held("launcher", "app", "apps")
                enabled: HistorySettings.counts.launcher !== 0
                onTriggered: HistorySettings.clear("launcher")
            }

            ActionRow {
                Layout.fillWidth: true
                icon: "󰞅"
                label: "Clear the recent emojis"
                destructive: true
                detail: page.held("emoji", "emoji", "emojis")
                enabled: HistorySettings.counts.emoji !== 0
                onTriggered: HistorySettings.clear("emoji")
            }

        }

    }

    Component.onCompleted: HistorySettings.count()
}
