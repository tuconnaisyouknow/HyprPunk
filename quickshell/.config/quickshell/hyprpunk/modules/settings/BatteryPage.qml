import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services
import qs.theme

// The settings' battery and power page: how hard the computer works, where the battery
// stops charging, when the island warns you it runs out, and what the computer does
// once it's critical.
SettingsPage {
    id: page

    // The profiles this computer has, from saver to performance.
    readonly property var profiles: PowerProfile.profiles.map((profile) => {
        return {
            "value": profile,
            "icon": Icons.powerProfile(profile),
            "label": profile === "power-saver" ? "Saver" : profile === "performance" ? "Performance" : "Balanced"
        };
    })

    title: "Battery and power"
    description: Battery.present ? "How hard the computer works, where the battery stops charging, and when you're warned it runs out." : "This computer has no battery: the warnings only count on one that does."

    SettingRow {
        Layout.fillWidth: true
        visible: PowerProfile.available
        icon: Icons.powerProfile(PowerProfile.current)
        title: "Power profile"
        description: "How hard the computer works: the saver makes the battery last, performance gives it all it has."

        SegmentedControl {
            width: parent.width
            compact: true
            options: page.profiles
            value: PowerProfile.current
            onSelected: (value) => {
                return PowerProfile.set(value);
            }
        }

    }

    // Read only until battery-limit is installed.
    SettingRow {
        Layout.fillWidth: true
        visible: ChargeLimit.current > 0
        icon: Icons.chargeLimit(ChargeLimit.current)
        title: "Charge limit"
        description: "Where the battery stops charging: easier on it over the years, 80 % being the usual choice. Kept after a restart."

        Column {
            width: parent.width
            spacing: Metrics.spacing.normal

            SettingChoices {
                width: parent.width
                enabled: ChargeLimit.writable
                values: ChargeLimit.choices
                // None chosen until the limit is read.
                value: ChargeLimit.current > 0 ? ChargeLimit.current : null
                label: (percent) => {
                    return percent === 100 ? "Off" : percent + " %";
                }
                onSelected: (value) => {
                    return ChargeLimit.set(value);
                }
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: !ChargeLimit.writable ? "Read only: install battery-limit (battery/ in the dotfiles) to change it." : ChargeLimit.error
                color: Colors.peach
                wrapMode: Text.Wrap
                font.family: Metrics.font
                font.pixelSize: Metrics.text.body
            }

        }

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

    // Read again each time the page opens: another app or the firmware may have changed them.
    ServiceRef {
        service: PowerProfile
    }

    ServiceRef {
        service: ChargeLimit
    }

}
