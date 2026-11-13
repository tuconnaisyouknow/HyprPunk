import QtQuick
import QtQuick.Layouts

// The settings' battery page: when the island warns you the battery runs out, and what
// the computer does once it's critical. The charge limit stays in the control center.
ColumnLayout {
    id: page

    spacing: 12

    Text {
        text: "Battery"
        color: Theme.primary
        font.family: Theme.font
        font.pixelSize: 20
        font.weight: Font.Bold
    }

    Text {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        text: Power.hasBattery ? "When you're warned it runs out. The charge limit is in the control center." : "This computer has no battery: these only count on one that does."
        color: Theme.secondary
        wrapMode: Text.Wrap
        font.family: Theme.font
        font.pixelSize: 12
    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰁻"
        title: "Low battery"
        description: "The island warns you, and the battery turns red in the bar."

        SettingChoices {
            width: parent.width
            values: [10, 15, 20, 25, 30]
            value: BatterySettings.low
            label: (percent) => {
                return percent + " %";
            }
            onSelected: (value) => {
                return BatterySettings.set("low", value);
            }
        }

    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰂃"
        title: "Critical battery"
        description: "The warning stays in the island until you plug it in."

        SettingChoices {
            width: parent.width
            values: [2, 3, 5, 7]
            value: BatterySettings.critical
            label: (percent) => {
                return percent + " %";
            }
            onSelected: (value) => {
                return BatterySettings.set("critical", value);
            }
        }

    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰐥"
        title: "When it's critical"
        description: "A minute after the warning, if it's still not plugged in, rather than dying on you. Sleep keeps your work open but slowly drains the battery; shutting down closes what isn't saved."

        SegmentedControl {
            width: parent.width
            compact: true
            options: [{
                "value": "none",
                "icon": "󰂚",
                "label": "Only warn"
            }, {
                "value": "suspend",
                "icon": "󰒲",
                "label": "Sleep"
            }, {
                "value": "poweroff",
                "icon": "󰐥",
                "label": "Shut down"
            }]
            value: BatterySettings.action
            onSelected: (value) => {
                return BatterySettings.set("action", value);
            }
        }

    }

}
