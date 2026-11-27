import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.theme

// The settings' island page: which changes the island shows as they happen, and how
// long they stay. Notifications have their own page.
SettingsPage {
    id: page

    title: "Island"
    description: "What the island shows you as it happens. Notifications have their own page."

    // Each change the island can show, as osdctl.sh names it. The workspaces only while
    // the island is alone in the bar: otherwise their pill shows them.
    readonly property var changes: [{
        "name": "volume",
        "icon": "volume_up",
        "title": "Volume",
        "description": "The volume keys, and any app changing the volume."
    }, {
        "name": "microphone",
        "icon": "mic",
        "title": "Microphone",
        "description": "Muted or back on."
    }, {
        "name": "brightness",
        "icon": "brightness_high",
        "title": "Brightness",
        "description": "The screen's and the keyboard's light."
    }, {
        "name": "keys",
        "icon": "keyboard_capslock",
        "title": "Caps Lock, Num Lock and the touchpad key",
        "description": "On or off."
    }, {
        "name": "power",
        "icon": "power",
        "title": "Plugged in or on battery",
        "description": "With the time left. The battery's warnings always show."
    }, {
        "name": "airpods",
        "icon": "earbuds",
        "title": "AirPods",
        "description": "Their battery, as they connect."
    }, {
        "name": "screenshots",
        "icon": "screenshot_monitor",
        "title": "Screenshots and recordings",
        "description": "A preview of what you just took, to open it."
    }, {
        "name": "workspaces",
        "icon": "view_week",
        "title": "Workspaces",
        "description": "The app and number of the one you go to.",
        "islandOnly": true
    }]

    SettingRow {
        Layout.fillWidth: true
        icon: "timer"
        title: "How long they stay"

        SegmentedControl {
            width: parent.width
            compact: true
            options: [{
                "value": "short",
                "icon": "clock_loader_20",
                "label": "Short"
            }, {
                "value": "normal",
                "icon": "clock_loader_60",
                "label": "Normal"
            }, {
                "value": "long",
                "icon": "speed",
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

            visible: !modelData.islandOnly || BarSettings.island
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
