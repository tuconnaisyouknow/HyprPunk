import QtQuick
import QtQuick.Layouts

// The settings' island page: which changes the island shows as they happen, and how
// long they stay. Notifications have their own page.
ColumnLayout {
    id: page

    // Each change the island can show, as osdctl.sh names it.
    readonly property var changes: [{
        "name": "volume",
        "icon": "󰕾",
        "title": "Volume",
        "description": "The volume keys, and any app changing the volume."
    }, {
        "name": "microphone",
        "icon": "󰍬",
        "title": "Microphone",
        "description": "Muted or back on."
    }, {
        "name": "brightness",
        "icon": "󰃠",
        "title": "Brightness",
        "description": "The screen's and the keyboard's light."
    }, {
        "name": "keys",
        "icon": "󰪛",
        "title": "Caps Lock, Num Lock and the touchpad key",
        "description": "On or off."
    }, {
        "name": "power",
        "icon": "󰚥",
        "title": "Plugged in or on battery",
        "description": "With the time left. The battery's warnings always show."
    }, {
        "name": "airpods",
        "icon": "󱡏",
        "title": "AirPods",
        "description": "Their battery, as they connect."
    }, {
        "name": "screenshots",
        "icon": "󰹑",
        "title": "Screenshots and recordings",
        "description": "A preview of what you just took, to open it."
    }]

    spacing: 12

    Text {
        text: "Island"
        color: Theme.primary
        font.family: Theme.font
        font.pixelSize: 20
        font.weight: Font.Bold
    }

    Text {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        text: "What the island shows you as it happens. Notifications have their own page."
        color: Theme.secondary
        wrapMode: Text.Wrap
        font.family: Theme.font
        font.pixelSize: 12
    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰔛"
        title: "How long they stay"

        SegmentedControl {
            width: parent.width
            compact: true
            options: [{
                "value": "short",
                "icon": "󰾆",
                "label": "Short"
            }, {
                "value": "normal",
                "icon": "󰾅",
                "label": "Normal"
            }, {
                "value": "long",
                "icon": "󰓅",
                "label": "Long"
            }]
            value: OsdSettings.duration
            onSelected: (value) => {
                return OsdSettings.set("duration", value);
            }
        }

    }

    Repeater {
        model: page.changes

        SettingRow {
            required property var modelData

            Layout.fillWidth: true
            icon: modelData.icon
            title: modelData.title
            description: modelData.description
            checkable: true
            checked: OsdSettings.shows(modelData.name)
            onToggled: OsdSettings.set(modelData.name, !checked)
        }

    }

}
