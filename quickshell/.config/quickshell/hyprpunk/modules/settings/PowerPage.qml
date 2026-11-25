import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services
import qs.theme

// The settings' idle and sleep page: how long after you leave the computer each step
// comes, plugged in and on battery, and whether media playing keeps it awake.
SettingsPage {
    id: page

    title: "Idle and sleep"
    description: "How long after you leave the computer each step comes. Caffeine holds them all back."

    // Whose delays you're changing: where the power comes from now, until you pick.
    property string source: Power.source
    readonly property var steps: [{
        "step": "keyboard",
        "icon": "keyboard",
        "title": "Keyboard light",
        "description": "Turns off when you stop typing.",
        "values": [0, 10, 30, 60, 120, 300],
        "needs": "keyboard"
    }, {
        "step": "dim",
        "icon": "brightness_low",
        "title": "Dim the screen",
        "description": "Lowers the brightness, a warning before it locks.",
        "values": [0, 60, 120, 300, 600, 900, 1800],
        "needs": "screen"
    }, {
        "step": "lock",
        "icon": "lock",
        "title": "Lock the screen",
        "description": "And turns the screens off.",
        "values": [0, 60, 120, 300, 600, 900, 1800, 3600],
        "needs": ""
    }, {
        "step": "suspend",
        "icon": "bedtime",
        "title": "Sleep",
        "description": "Suspends the computer.",
        "values": [0, 300, 600, 900, 1800, 3600, 7200],
        "needs": ""
    }]

    // A step's light is there: the keyboard's, or the screen's backlight (desktops have
    // neither). Read by each row rather than in the steps, or every change of the
    // keyboard light's level would rebuild the rows and lose the keyboard focus.
    function available(needs) {
        if (needs === "keyboard")
            return Devices.keyboardBacklight >= 0;

        return needs !== "screen" || Devices.hasBacklight;
    }

    // "Never", "30 s", "5 min", "5 min 30 s", "1 h", "1 h 30 min".
    function durationText(seconds) {
        if (seconds === 0)
            return "Never";

        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor(seconds % 3600 / 60);
        const rest = seconds % 60;
        if (hours > 0)
            return hours + " h" + (minutes > 0 ? " " + minutes + " min" : "");

        if (minutes > 0)
            return minutes + " min" + (rest > 0 ? " " + rest + " s" : "");

        return rest + " s";
    }

    // Desktops have one set of delays.
    SegmentedControl {
        Layout.fillWidth: true
        visible: Battery.present
        compact: true
        options: [{
            "value": "plugged",
            "icon": "power",
            "label": "Plugged in"
        }, {
            "value": "battery",
            "icon": "battery_full",
            "label": "On battery"
        }]
        value: page.source
        onSelected: (value) => {
            return page.source = value;
        }
    }

    Repeater {
        model: page.steps

        SettingRow {
            required property var modelData

            Layout.fillWidth: true
            visible: page.available(modelData.needs)
            icon: modelData.icon
            title: modelData.title
            description: modelData.description

            SettingChoices {
                width: parent.width
                values: modelData.values
                value: Power.delay(modelData.step, page.source)
                label: page.durationText
                onSelected: (value) => {
                    return Power.set(page.source + "." + modelData.step, value);
                }
            }

        }

    }

    SettingRow {
        Layout.fillWidth: true
        icon: "music_note"
        title: "Stay awake while media plays"
        description: "Music or a video playing holds off dimming, locking and sleep."
        checkable: true
        checked: Power.mediaKeepsAwake
        onToggled: Power.set("media", !Power.mediaKeepsAwake)
    }

}
