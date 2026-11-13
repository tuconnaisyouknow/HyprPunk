import QtQuick
import QtQuick.Layouts
import Quickshell

// The settings' screenshots and recordings page: where a screenshot goes, the folders
// they're saved to, and what a recording hears and how smoothly it records.
ColumnLayout {
    id: page

    // The shell's file picker, to choose the folders.
    required property var fileChooser

    // "~/Pictures/Screenshots" rather than the full path.
    function shortPath(path) {
        const home = Quickshell.env("HOME");
        return path.startsWith(home + "/") ? "~" + path.slice(home.length) : path;
    }

    // Opens in the folder holding the current one, which may not exist yet. Picking the
    // usual folder again is how you go back to it.
    function chooseFolder(key, title, current) {
        fileChooser.ask({
            "title": title,
            "directory": true,
            "folder": current.slice(0, current.lastIndexOf("/")) || "/"
        }, (paths) => {
            return CaptureSettings.set(key, paths[0]);
        });
    }

    spacing: 12

    Text {
        text: "Screenshots and recordings"
        color: Theme.primary
        font.family: Theme.font
        font.pixelSize: 20
        font.weight: Font.Bold
    }

    Text {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        text: "Screenshots are saved to Screenshots in your pictures folder, recordings to Recordings in your videos folder, unless you choose others."
        color: Theme.secondary
        wrapMode: Text.Wrap
        font.family: Theme.font
        font.pixelSize: 12
    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰹑"
        title: "After a screenshot"
        description: "Copied, it's ready to paste. Only copied, it's gone once you copy something else."

        SegmentedControl {
            width: parent.width
            compact: true
            options: [{
                "value": "both",
                "icon": "󰆏",
                "label": "Copy and save"
            }, {
                "value": "copy",
                "icon": "󰅍",
                "label": "Copy only"
            }, {
                "value": "save",
                "icon": "󰆓",
                "label": "Save only"
            }]
            value: CaptureSettings.screenshots
            onSelected: (value) => {
                return CaptureSettings.set("screenshots", value);
            }
        }

    }

    SettingRow {
        Layout.fillWidth: true
        enabled: CaptureSettings.saves
        opacity: enabled ? 1 : 0.5
        icon: "󰉏"
        title: "Screenshots folder"
        description: page.shortPath(CaptureSettings.screenshotsFolder)

        ActionRow {
            width: parent.width
            icon: "󰉋"
            label: "Choose a folder"
            onTriggered: page.chooseFolder("screenshots.folder", "Screenshots folder", CaptureSettings.screenshotsFolder)
        }

    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰕾"
        title: "Sound in recordings"
        description: "What plays on the computer, or your voice through the microphone."

        SegmentedControl {
            width: parent.width
            compact: true
            options: [{
                "value": "system",
                "icon": "󰓃",
                "label": "Computer"
            }, {
                "value": "microphone",
                "icon": "󰍬",
                "label": "Microphone"
            }, {
                "value": "none",
                "icon": "󰖁",
                "label": "No sound"
            }]
            value: CaptureSettings.audio
            onSelected: (value) => {
                return CaptureSettings.set("audio", value);
            }
        }

    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰕧"
        title: "Frame rate"
        description: "Recording only what changes keeps files small. A steady rate plays smoother and suits video editors better."

        SegmentedControl {
            width: parent.width
            compact: true
            options: [{
                "value": 0,
                "icon": "󰔛",
                "label": "As it changes"
            }, {
                "value": 30,
                "icon": "󰕧",
                "label": "30 fps"
            }, {
                "value": 60,
                "icon": "󰕧",
                "label": "60 fps"
            }]
            value: CaptureSettings.framerate
            onSelected: (value) => {
                return CaptureSettings.set("framerate", value);
            }
        }

    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰉏"
        title: "Recordings folder"
        description: page.shortPath(CaptureSettings.recordingsFolder)

        ActionRow {
            width: parent.width
            icon: "󰉋"
            label: "Choose a folder"
            onTriggered: page.chooseFolder("recordings.folder", "Recordings folder", CaptureSettings.recordingsFolder)
        }

    }

}
