import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config
import qs.theme

// The settings' keyboard and region page: the keyboard layout and the regional formats.
// The interface itself is in English, so there's no language to pick. The scripts apply
// them (keyboard-layoutctl.sh, locale-profilectl.sh).
SettingsPage {
    id: page

    title: "Keyboard and region"
    description: "New apps follow a change of formats right away. Log out and back in for the apps already open."

    readonly property var regions: [{
        "value": "us",
        "icon": "󰃭",
        "label": "United States"
    }, {
        "value": "fr",
        "icon": "󰃭",
        "label": "France"
    }]

    SettingRow {
        Layout.fillWidth: true
        icon: "󰌌"
        title: "Keyboard layout"
        description: "The Vim keys move with it, to j k l m on AZERTY, so they stay under your right hand."

        SegmentedControl {
            width: parent.width
            compact: true
            options: [{
                "value": "us",
                "icon": "󰌌",
                "label": "US QWERTY"
            }, {
                "value": "fr",
                "icon": "󰌌",
                "label": "FR AZERTY"
            }]
            value: Session.keyboardLayout
            onSelected: (value) => {
                return Quickshell.execDetached([Session.scripts + "/keyboard-layoutctl.sh", "set", value]);
            }
        }

    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰃭"
        title: "Regional formats"
        description: "Dates, times, numbers and money: 12 or 24 hours, the decimal point or comma."

        SegmentedControl {
            width: parent.width
            compact: true
            options: page.regions
            value: Session.regionalProfile
            onSelected: (value) => {
                return Quickshell.execDetached([Session.scripts + "/locale-profilectl.sh", "set", value]);
            }
        }

    }

}
