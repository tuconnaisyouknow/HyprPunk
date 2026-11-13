import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// The settings' updates page: the HyprPunk you have and updating it, whether you're told
// at login when there's a new one, and the bar's count of package updates.
ColumnLayout {
    id: page

    // The commit you're on and its day ("2026-11-12 d48bc5d"), read each time the window
    // opens.
    property string version: ""
    readonly property string versionText: {
        const [day, commit] = version.split(" ");
        if (!commit)
            return "";

        const [year, month, date] = day.split("-").map(Number);
        const locale = Qt.locale(Session.regionalLocale.split(".")[0]);
        return commit + ", from " + new Date(year, month - 1, date).toLocaleDateString(locale, Locale.ShortFormat);
    }

    spacing: 12

    Text {
        text: "Updates"
        color: Theme.primary
        font.family: Theme.font
        font.pixelSize: 20
        font.weight: Font.Bold
    }

    Text {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        text: "Updates always ask before they change anything, in your terminal."
        color: Theme.secondary
        wrapMode: Text.Wrap
        font.family: Theme.font
        font.pixelSize: 12
    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰣇"
        title: "HyprPunk"
        description: page.versionText ? "The version you have: " + page.versionText + "." : "The version you have."

        ActionRow {
            width: parent.width
            icon: "󰚰"
            label: "Update HyprPunk"
            onTriggered: UpdateSettings.updateHyprPunk()
        }

    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰂚"
        title: "Tell me at login"
        description: "A notification when a new HyprPunk is waiting, with a button to update."
        checkable: true
        checked: UpdateSettings.hyprpunk
        onToggled: UpdateSettings.set("hyprpunk", !UpdateSettings.hyprpunk)
    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰏗"
        title: "Package updates"
        description: "The bar shows how many packages can be updated, and updates them on a click."
        checkable: true
        checked: UpdateSettings.packages
        onToggled: UpdateSettings.set("packages", !UpdateSettings.packages)

        ActionRow {
            width: parent.width
            icon: "󰏔"
            label: Updates.count > 0 ? "Update " + Updates.count + (Updates.count > 1 ? " packages" : " package") : "Update the packages"
            onTriggered: Updates.upgrade()
        }

    }

    SettingRow {
        Layout.fillWidth: true
        enabled: UpdateSettings.packages
        opacity: enabled ? 1 : 0.5
        icon: "󰔛"
        title: "Look for them every"
        description: "And after anything pacman does."

        SettingChoices {
            width: parent.width
            values: [15, 60, 180, 360]
            value: UpdateSettings.interval
            label: (minutes) => {
                return minutes < 60 ? minutes + " min" : minutes === 60 ? "1 hour" : minutes / 60 + " hours";
            }
            onSelected: (value) => {
                return UpdateSettings.set("interval", value);
            }
        }

    }

    Process {
        command: [Session.scripts + "/updatesctl.sh", "version"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: page.version = text.trim()
        }

    }

}
