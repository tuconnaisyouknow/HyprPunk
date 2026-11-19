import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.components
import qs.config
import qs.theme

// The settings' keyboard and region page: the keyboard layout, any Latin one, where the
// Vim keys sit on it, and the regional formats. The interface itself is in English, so
// there's no language to pick. The scripts apply them (keyboard-layoutctl.sh,
// locale-profilectl.sh).
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
    // Every Latin layout and variant, as the selector's options, listed when the page
    // opens. Until then, the one you're on.
    property var layouts: [{
        "label": Session.keyboardLayoutName,
        "keywords": Session.keyboardLayout + " " + Session.keyboardVariant,
        "layout": Session.keyboardLayout,
        "variant": Session.keyboardVariant
    }]
    readonly property int currentLayout: Math.max(0, layouts.findIndex((entry) => {
        return entry.layout === Session.keyboardLayout && entry.variant === Session.keyboardVariant;
    }))

    function keysLabel(keys) {
        return keys.map((key) => {
            return key.toUpperCase();
        }).join(" ");
    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰌌"
        title: "Keyboard layout"
        description: "Any Latin layout, found by its name or its code. The login screen and the TTYs take it too."

        FormSelect {
            id: layoutSelect

            width: parent.width
            searchable: true
            placeholder: "Find a layout"
            options: page.layouts
            onActivated: (index) => {
                const entry = page.layouts[index];
                Quickshell.execDetached([Session.scripts + "/keyboard-layoutctl.sh", "set", entry.layout, entry.variant]);
            }

            // Choosing moves the selector at once: this brings it back to the layout
            // really in use, changed from here or from a terminal.
            Binding {
                target: layoutSelect
                property: "currentIndex"
                value: page.currentLayout
            }

        }

    }

    SettingRow {
        Layout.fillWidth: true
        icon: "󰌓"
        title: "Vim keys"
        description: "The arrows of every panel, window and terminal app. On the home row they start under your right index, whatever the layout writes there, and the keys they take move to the letters left free."

        SegmentedControl {
            width: parent.width
            compact: true
            options: [{
                "value": "vim",
                "icon": "󰌌",
                "label": "Vim's letters  " + page.keysLabel(["h", "j", "k", "l"])
            }, {
                "value": "home",
                "icon": "󰋜",
                "label": "Home row  " + page.keysLabel(Session.homeKeys)
            }]
            value: Session.vimKeysPlace
            onSelected: (value) => {
                return Quickshell.execDetached([Session.scripts + "/keyboard-layoutctl.sh", "keys", value]);
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

    Process {
        command: [Session.scripts + "/keyboard-layoutctl.sh", "list"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const layouts = text.split("\n").filter((line) => {
                    return line !== "";
                }).map((line) => {
                    const parts = line.split("\t");
                    return {
                        "label": parts[2],
                        "keywords": parts[0] + " " + parts[1],
                        "layout": parts[0],
                        "variant": parts[1]
                    };
                });
                if (layouts.length > 0)
                    page.layouts = layouts;

            }
        }

    }

}
