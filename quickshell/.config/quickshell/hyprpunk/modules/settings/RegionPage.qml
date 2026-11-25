import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.components
import qs.config
import qs.theme

// The settings' keyboard and region page: the keyboard layout, any Latin one, where the
// Vim keys sit on it, and the regional formats, any locale glibc has. The interface itself
// is in English, so there's no language to pick. The scripts apply them (keyboard-layoutctl.sh,
// locale-profilectl.sh).
SettingsPage {
    id: page

    title: "Keyboard and region"
    description: "New apps follow a change of formats right away. Log out and back in for the apps already open."

    // Every locale, listed when the page opens like the layouts. Until then, the one
    // you're on.
    property var regions: [{
        "label": Session.regionalName || Session.regionalLocale,
        "keywords": Session.regionalLocale,
        "locale": Session.regionalLocale
    }]
    readonly property int currentRegion: Math.max(0, regions.findIndex((entry) => {
        return entry.locale === Session.regionalLocale;
    }))
    // What the formats make of a date, a time and a number, shown as you pick them.
    readonly property date sample: new Date()
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
        icon: "keyboard"
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
        icon: "keyboard_alt"
        title: "Vim keys"
        description: "The arrows of every panel, window and terminal app. On the home row they start under your right index, whatever the layout writes there, and the keys they take move to the letters left free."

        SegmentedControl {
            width: parent.width
            compact: true
            options: [{
                "value": "vim",
                "icon": "keyboard",
                "label": "Vim's letters  " + page.keysLabel(["h", "j", "k", "l"])
            }, {
                "value": "home",
                "icon": "home",
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
        icon: "calendar_month"
        title: "Regional formats"
        description: "Dates, times, numbers and money, found by country, language or code. Here: " + page.sample.toLocaleDateString(Session.regionalFormats, Locale.ShortFormat) + ", " + Session.shortTime(page.sample) + ", " + (1234.56).toLocaleString(Session.regionalFormats, "f", 2) + "."

        FormSelect {
            id: regionSelect

            width: parent.width
            searchable: true
            placeholder: "Find a country or a language"
            options: page.regions
            onActivated: (index) => {
                return Quickshell.execDetached([Session.scripts + "/locale-profilectl.sh", "set", page.regions[index].locale]);
            }

            // As for the layout, brought back to the formats really in use.
            Binding {
                target: regionSelect
                property: "currentIndex"
                value: page.currentRegion
            }

        }

    }

    Process {
        command: [Session.scripts + "/locale-profilectl.sh", "list"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const regions = text.split("\n").filter((line) => {
                    return line !== "";
                }).map((line) => {
                    const parts = line.split("\t");
                    // Found by its whole code, or its language's or country's alone ("de", "ch").
                    const codes = parts[0].replace(".UTF-8", "").split(/[_@]/);
                    return {
                        "label": parts[1],
                        "keywords": [parts[0]].concat(codes).join(" ").toLowerCase(),
                        "locale": parts[0]
                    };
                });
                if (regions.length > 0)
                    page.regions = regions;

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
