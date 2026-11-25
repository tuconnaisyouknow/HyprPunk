import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

// The settings' bar page: the bar with the pills you keep, or the island alone, which
// opens under the pointer. The updates stay as a chip in the island alone, the other pills
// have no place there.
SettingsPage {
    id: page

    // Each pill you can hide, as barctl.sh names it.
    readonly property var pills: [{
        "name": "workspaces",
        "icon": "workspaces",
        "title": "Workspaces",
        "description": "Your workspaces as dots. Hidden, Super+W still previews them.",
        "island": false
    }, {
        "name": "monitor",
        "icon": "memory",
        "title": "Resources",
        "description": "Memory and processor, on a screen wide enough for them.",
        "island": false
    }, {
        "name": "updates",
        "icon": "package_2",
        "title": "Updates",
        "description": "The packages waiting, as they come. In the island alone, a chip beside the time.",
        "island": true
    }, {
        "name": "control",
        "icon": "tune",
        "title": "Control center",
        "description": "Network, sound and battery. Hidden, Super+C still opens the control center.",
        "island": false
    }]

    title: "Bar"
    description: "The pills along the top of the screen, or the island alone."

    SettingRow {
        Layout.fillWidth: true
        icon: "toolbar"
        title: "Layout"
        description: "The bar with its pills, or the island alone: under the pointer it opens onto the wallpaper over your workspaces and the machine's load over the control center's icons, and the control center, the system monitor and the workspace preview grow out of it."

        SegmentedControl {
            width: parent.width
            compact: true
            options: [{
                "value": "bar",
                "icon": "horizontal_distribute",
                "label": "Bar"
            }, {
                "value": "island",
                "icon": "align_horizontal_center",
                "label": "Island"
            }]
            value: BarSettings.island ? "island" : "bar"
            onSelected: (value) => {
                return BarSettings.set("layout", value);
            }
        }

    }

    Repeater {
        model: page.pills

        SettingRow {
            required property var modelData

            Layout.fillWidth: true
            // Only the pills the layout has.
            visible: !BarSettings.island || modelData.island
            icon: modelData.icon
            title: modelData.title
            description: modelData.description
            checkable: true
            checked: BarSettings.shows(modelData.name)
            onToggled: BarSettings.set(modelData.name, !checked)
        }

    }

}
