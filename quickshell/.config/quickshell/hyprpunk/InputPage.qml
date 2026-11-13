import QtQuick
import QtQuick.Layouts
import Quickshell

// The settings' mouse and touchpad page: the pointer's speed and how it scrolls, and the
// touchpad's taps. Hyprland takes each change at once (inputctl.sh).
ColumnLayout {
    id: page

    spacing: 12

    Text {
        text: "Mouse and touchpad"
        color: Theme.primary
        font.family: Theme.font
        font.pixelSize: 20
        font.weight: Font.Bold
    }

    Text {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        text: "Your personal/input.lua still wins over these."
        color: Theme.secondary
        wrapMode: Text.Wrap
        font.family: Theme.font
        font.pixelSize: 12
    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰇀"
        title: "Pointer speed"
        description: "For the mouse and the touchpad alike."

        SettingChoices {
            width: parent.width
            values: [-0.6, -0.3, 0, 0.3, 0.6]
            value: InputSettings.number("sensitivity")
            label: (speed) => {
                return ({
                    "-0.6": "Slowest",
                    "-0.3": "Slower",
                    "0": "Usual",
                    "0.3": "Faster",
                    "0.6": "Fastest"
                })[String(speed)] || String(speed);
            }
            onSelected: (value) => {
                return InputSettings.set("sensitivity", value);
            }
        }

    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰳽"
        title: "Acceleration"
        description: "Faster moves go further, or the pointer goes as far as your hand, whatever the speed: a steadier aim for games and drawing."

        SegmentedControl {
            width: parent.width
            compact: true
            options: [{
                "value": "adaptive",
                "icon": "󰓅",
                "label": "Adaptive"
            }, {
                "value": "flat",
                "icon": "󰘖",
                "label": "Flat"
            }]
            value: InputSettings.values.acceleration || null
            onSelected: (value) => {
                return InputSettings.set("acceleration", value);
            }
        }

    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰳾"
        title: "Focus follows the pointer"
        description: "The window under the pointer takes the keyboard. Off, a click gives it."
        checkable: true
        checked: InputSettings.on("focus")
        onToggled: InputSettings.set("focus", !checked)
    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰍽"
        title: "Natural scrolling with the mouse"
        description: "The page follows the wheel, like a phone's follows your finger."
        checkable: true
        checked: InputSettings.on("mouse.natural")
        onToggled: InputSettings.set("mouse.natural", !checked)
    }

    // The touchpad's own, once touchpadctl.sh has found one.
    Text {
        Layout.topMargin: 8
        visible: Devices.hasTouchpad
        text: "Touchpad"
        color: Theme.primary
        font.family: Theme.font
        font.pixelSize: 16
        font.weight: Font.Bold
    }

    SettingRow {
        Layout.fillWidth: true
        visible: Devices.hasTouchpad
        icon: "󰟸"
        title: "Touchpad"
        description: "Off, only a mouse moves the pointer. The touchpad key does the same."
        checkable: true
        checked: Devices.touchpadEnabled
        onToggled: Quickshell.execDetached([Session.scripts + "/touchpadctl.sh", "toggle"])
    }

    SettingRow {
        Layout.fillWidth: true
        visible: Devices.hasTouchpad
        icon: "󰳽"
        title: "Tap to click"
        description: "A tap clicks, two fingers right-click, three middle-click."
        checkable: true
        checked: InputSettings.on("touchpad.tap")
        onToggled: InputSettings.set("touchpad.tap", !checked)
    }

    SettingRow {
        Layout.fillWidth: true
        visible: Devices.hasTouchpad
        icon: "󰌌"
        title: "Off while you type"
        description: "Your palm can't move the pointer while you type."
        checkable: true
        checked: InputSettings.on("touchpad.typing")
        onToggled: InputSettings.set("touchpad.typing", !checked)
    }

    SettingRow {
        Layout.fillWidth: true
        visible: Devices.hasTouchpad
        icon: "󰍽"
        title: "Natural scrolling with the touchpad"
        description: "The page follows your fingers."
        checkable: true
        checked: InputSettings.on("touchpad.natural")
        onToggled: InputSettings.set("touchpad.natural", !checked)
    }

    SettingRow {
        Layout.fillWidth: true
        visible: Devices.hasTouchpad
        icon: "󰡏"
        title: "Scrolling speed"
        description: "How far two fingers scroll."

        SettingChoices {
            width: parent.width
            values: [0.5, 1, 1.5, 2]
            value: InputSettings.number("touchpad.scroll")
            label: (factor) => {
                return factor + "×";
            }
            onSelected: (value) => {
                return InputSettings.set("touchpad.scroll", value);
            }
        }

    }

}
