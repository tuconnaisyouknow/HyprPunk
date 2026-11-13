import QtQuick
import QtQuick.Layouts

// The settings' night light page: when the screens turn warm, and how warm.
ColumnLayout {
    id: page

    readonly property bool scheduled: NightLightSettings.mode === "schedule"

    // "9:00 PM" or "21:00", as the regional formats have it.
    function hourText(hour) {
        return Session.shortTime(new Date(2000, 0, 1, hour));
    }

    spacing: 12

    Text {
        text: "Night light"
        color: Theme.primary
        font.family: Theme.font
        font.pixelSize: 20
        font.weight: Font.Bold
    }

    Text {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        text: "Warms the screens' colors, easier on the eyes in the evening."
        color: Theme.secondary
        wrapMode: Text.Wrap
        font.family: Theme.font
        font.pixelSize: 12
    }

    SegmentedControl {
        Layout.fillWidth: true
        compact: true
        options: [{
            "value": "off",
            "icon": "󰌶",
            "label": "Off"
        }, {
            "value": "on",
            "icon": "󰛨",
            "label": "Always on"
        }, {
            "value": "schedule",
            "icon": "󰔛",
            "label": "Scheduled"
        }]
        value: NightLightSettings.mode
        onSelected: (value) => {
            return NightLightSettings.set("mode", value);
        }
    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰈸"
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
        icon: "󰖔"
        title: "From"
        description: "When it turns on, in the scheduled mode."

        SettingChoices {
            width: parent.width
            values: [18, 19, 20, 21, 22, 23]
            value: NightLightSettings.from
            label: page.hourText
            onSelected: (value) => {
                return NightLightSettings.set("from", value);
            }
        }

    }

    SettingRow {
        Layout.fillWidth: true
        enabled: page.scheduled
        opacity: enabled ? 1 : 0.5
        icon: "󰖨"
        title: "To"
        description: "When it turns off again, the next morning."

        SettingChoices {
            width: parent.width
            values: [5, 6, 7, 8, 9]
            value: NightLightSettings.to
            label: page.hourText
            onSelected: (value) => {
                return NightLightSettings.set("to", value);
            }
        }

    }

}
