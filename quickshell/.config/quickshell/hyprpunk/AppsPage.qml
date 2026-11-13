import QtQuick
import QtQuick.Layouts

// The settings' default apps page: the terminal, browser, file manager and music app
// HyprPunk opens, each picked among the installed apps that can take its role.
ColumnLayout {
    id: page

    spacing: 12

    Text {
        text: "Default apps"
        color: Theme.primary
        font.family: Theme.font
        font.pixelSize: 20
        font.weight: Font.Bold
    }

    Text {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        text: "What the shortcuts open. The browser and the file manager also open the links and folders other apps hand on. Your personal/keybindings.lua still wins over these."
        color: Theme.secondary
        wrapMode: Text.Wrap
        font.family: Theme.font
        font.pixelSize: 12
    }

    Repeater {
        model: AppSettings.roles

        SettingRow {
            id: role

            required property var modelData
            // The installed apps that can take it, as the commands they start.
            readonly property var entries: AppSettings.candidates(modelData.categories)

            Layout.fillWidth: true
            icon: modelData.icon
            title: modelData.title
            description: modelData.description

            Column {
                width: parent.width
                spacing: 6

                SettingChoices {
                    width: parent.width
                    values: role.entries.map((entry) => {
                        return AppSettings.command(entry);
                    })
                    value: AppSettings.values[role.modelData.name] ?? null
                    label: (command) => {
                        const entry = role.entries.find((candidate) => {
                            return AppSettings.command(candidate) === command;
                        });
                        return entry ? entry.name : command;
                    }
                    onSelected: (command) => {
                        return AppSettings.set(role.modelData.name, role.entries.find((candidate) => {
                            return AppSettings.command(candidate) === command;
                        }));
                    }
                }

                // Set by hand to an app that isn't among them, it stays as it is.
                Text {
                    width: parent.width
                    visible: role.entries.every((entry) => {
                        return AppSettings.command(entry) !== AppSettings.values[role.modelData.name];
                    })
                    text: "Now: " + (AppSettings.values[role.modelData.name] || "nothing yet")
                    color: Theme.secondary
                    wrapMode: Text.Wrap
                    font.family: Theme.font
                    font.pixelSize: 12
                }

            }

        }

    }

}
