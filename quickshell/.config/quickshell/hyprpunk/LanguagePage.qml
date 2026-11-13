import QtQuick
import QtQuick.Layouts
import Quickshell

// The settings' keyboard and language page: the keyboard layout, the interface's
// language and, apart, the regional formats, so you can have an English desktop with
// French dates. The scripts apply them (keyboard-layoutctl.sh, locale-profilectl.sh).
ColumnLayout {
    id: page

    readonly property var languages: [{
        "value": "us",
        "icon": "󰗊",
        "label": "English"
    }, {
        "value": "fr",
        "icon": "󰗊",
        "label": "French"
    }]
    readonly property var regions: [{
        "value": "us",
        "icon": "󰃭",
        "label": "United States"
    }, {
        "value": "fr",
        "icon": "󰃭",
        "label": "France"
    }]

    function setLocale(category, profile) {
        Quickshell.execDetached([Session.scripts + "/locale-profilectl.sh", "set-" + category, profile]);
    }

    spacing: 12

    Text {
        text: "Keyboard and language"
        color: Theme.primary
        font.family: Theme.font
        font.pixelSize: 20
        font.weight: Font.Bold
    }

    Text {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        text: "New apps follow a language change right away. Log out and back in for the apps already open."
        color: Theme.secondary
        wrapMode: Text.Wrap
        font.family: Theme.font
        font.pixelSize: 12
    }

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
        icon: "󰗊"
        title: "Interface language"
        description: "The language apps speak to you in."

        SegmentedControl {
            width: parent.width
            compact: true
            options: page.languages
            value: Session.languageProfile
            onSelected: (value) => {
                return page.setLocale("language", value);
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
                return page.setLocale("regional", value);
            }
        }

    }

}
