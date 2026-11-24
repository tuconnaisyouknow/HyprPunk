import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.theme

// The settings' sound page: how much a volume key changes the volume, and how high the
// shell lets it go.
SettingsPage {
    id: page

    title: "Sound"
    description: "How the volume moves. The outputs and each app's volume are in the control center."

    SettingRow {
        Layout.fillWidth: true
        icon: "󰕾"
        title: "Volume keys"
        description: "How much a press changes the volume."

        SettingChoices {
            width: parent.width
            values: [2, 5, 10]
            value: SoundSettings.step
            label: (percent) => {
                return percent + " %";
            }
            onSelected: (value) => {
                return SoundSettings.set("step", value);
            }
        }

    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰋋"
        title: "Volume limit"
        description: "A louder volume comes down to it, and the volume keys and the control center's slider stop there, to spare your ears. An app can still raise its own volume past it."

        SettingChoices {
            width: parent.width
            values: [50, 60, 70, 80, 90, 100]
            value: SoundSettings.limit
            label: (percent) => {
                return percent + " %";
            }
            onSelected: (value) => {
                return SoundSettings.set("limit", value);
            }
        }

    }

}
