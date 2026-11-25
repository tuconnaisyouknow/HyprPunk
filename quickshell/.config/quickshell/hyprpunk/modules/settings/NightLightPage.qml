import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.theme

// The settings' night light page: when the screens turn warm, and how warm.
SettingsPage {
    id: page

    title: "Night light"
    description: "Warms the screens' colors, easier on the eyes in the evening."

    readonly property bool scheduled: NightLightSettings.mode === "schedule"

    SegmentedControl {
        Layout.fillWidth: true
        compact: true
        options: [{
            "value": "off",
            "icon": "light_off",
            "label": "Off"
        }, {
            "value": "on",
            "icon": "lightbulb",
            "label": "Always on"
        }, {
            "value": "schedule",
            "icon": "timer",
            "label": "Scheduled"
        }]
        value: NightLightSettings.mode
        onSelected: (value) => {
            return NightLightSettings.set("mode", value);
        }
    }

    SettingRow {
        Layout.fillWidth: true
        icon: "local_fire_department"
        title: "Warmth"
        description: "In kelvin: the lower, the warmer."

        SettingChoices {
            width: parent.width
            values: [2500, 3500, 4500, 5500]
            value: NightLightSettings.temperature
            label: (kelvin) => {
                return kelvin + " K";
            }
            onSelected: (value) => {
                return NightLightSettings.set("temperature", value);
            }
        }

    }

    SettingRow {
        Layout.fillWidth: true
        enabled: page.scheduled
        opacity: enabled ? 1 : 0.5
        icon: "nightlight"
        title: "From"
        description: "When it turns on, in the scheduled mode."

        SettingChoices {
            width: parent.width
            values: [18, 19, 20, 21, 22]
            value: NightLightSettings.from
            label: NightLightSettings.hourText
            onSelected: (value) => {
                return NightLightSettings.set("from", value);
            }
        }

    }

    SettingRow {
        Layout.fillWidth: true
        enabled: page.scheduled
        opacity: enabled ? 1 : 0.5
        icon: "light_mode"
        title: "To"
        description: "When it turns off again, the next morning."

        SettingChoices {
            width: parent.width
            values: [5, 6, 7, 8, 9]
            value: NightLightSettings.to
            label: NightLightSettings.hourText
            onSelected: (value) => {
                return NightLightSettings.set("to", value);
            }
        }

    }

}
