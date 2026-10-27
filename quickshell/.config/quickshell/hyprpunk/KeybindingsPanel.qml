import QtQuick
import Quickshell
import Quickshell.Io

// Keybindings in the dynamic island: the active Hyprland binds that have a
// description, searched by description and keys. Enter or a click runs the bind
// (run_keybinding in keybindings.lua).
SearchPanel {
    id: keybindings

    readonly property int rowHeight: 40
    readonly property int rowSpacing: 4
    readonly property int visibleRows: 10
    // [{ "keys": [string], "description" }]
    property var binds: []
    readonly property var results: {
        const words = query.toLowerCase().split(/\s+/).filter((word) => {
            return word !== "";
        });
        return binds.filter((bind) => {
            const text = (bind.description + " " + bind.keys.join(" ")).toLowerCase();
            return words.every((word) => {
                return text.includes(word);
            });
        });
    }

    // Modifiers first, then the key.
    function bindKeys(bind) {
        const modifiers = [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"], [16, "Mod2"], [32, "Mod3"], [128, "Mod5"]].filter((modifier) => {
            return bind.modmask & modifier[0];
        }).map((modifier) => {
            return modifier[1];
        });
        return modifiers.concat([keyName(bind)]);
    }

    function keyName(bind) {
        const names = {
            "mouse_down": "Wheel down",
            "mouse_up": "Wheel up",
            "mouse:272": "Left click",
            "mouse:273": "Right click",
            "semicolon": ";",
            "SPACE": "Space",
            "XF86AudioRaiseVolume": "Volume up",
            "XF86AudioLowerVolume": "Volume down",
            "XF86AudioMute": "Volume mute",
            "XF86AudioMicMute": "Mic mute",
            "XF86TouchpadToggle": "Touchpad",
            "XF86MonBrightnessUp": "Brightness up",
            "XF86MonBrightnessDown": "Brightness down",
            "XF86AudioNext": "Next",
            "XF86AudioPause": "Pause",
            "XF86AudioPlay": "Play",
            "XF86AudioPrev": "Previous"
        };
        // The clipboard's key, bound by its place (Hyprland gives no keycode back):
        // ù in AZERTY, ' in QWERTY.
        if (bind.key === "" && bind.description === "Open the clipboard history")
            return keyboardLayout === "fr" ? "ù" : "'";

        if (bind.key === "") {
            // Workspace binds are set by keycode, the number is in the description.
            const match = bind.description.match(/workspace (\d+)$/);
            return match ? (match[1] === "10" ? "0" : match[1]) : "?";
        }
        if (names[bind.key])
            return names[bind.key];

        return /^[a-z]$/i.test(bind.key) ? bind.key.toUpperCase() : bind.key;
    }

    function run(bind) {
        close();
        Quickshell.execDetached(["hyprctl", "eval", "run_keybinding(" + JSON.stringify(bind.description) + ")"]);
    }

    panelName: "keybindings"
    searchIcon: "󰌌"
    placeholder: "Search keybindings"
    hint: binds.length > 0 ? results.length + " / " + binds.length : ""
    count: results.length
    view: list
    cardWidth: 760
    bodyHeight: results.length > 0 ? Math.min(results.length, visibleRows) * (rowHeight + rowSpacing) - rowSpacing : rowHeight
    onOpening: bindsProcess.running = true
    onActivated: (index) => {
        return run(results[index]);
    }

    Process {
        id: bindsProcess

        command: ["hyprctl", "binds", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    // hyprctl can list the same bind twice.
                    const seen = {};
                    keybindings.binds = JSON.parse(text).filter((bind) => {
                        return bind.has_description && bind.description !== "";
                    }).map((bind) => {
                        return {
                            "keys": keybindings.bindKeys(bind),
                            "description": bind.description
                        };
                    }).filter((bind) => {
                        const id = bind.keys.join("+") + "\t" + bind.description;
                        if (seen[id])
                            return false;

                        seen[id] = true;
                        return true;
                    });
                } catch (error) {
                    keybindings.binds = [];
                }
            }
        }

    }

    Text {
        anchors.centerIn: parent
        visible: keybindings.results.length === 0
        text: bindsProcess.running && keybindings.binds.length === 0 ? "Loading…" : "No keybinding"
        color: "#7f849c"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
    }

    ListView {
        id: list

        anchors.fill: parent
        clip: true
        spacing: keybindings.rowSpacing
        boundsBehavior: Flickable.StopAtBounds
        model: keybindings.results

        delegate: Rectangle {
            id: row

            required property var modelData
            required property int index
            readonly property bool selected: keybindings.selectedIndex === index

            width: ListView.view.width
            height: keybindings.rowHeight
            radius: 14
            color: "transparent"

            GlassSurface {
                radius: parent.radius
                visible: row.selected
                hovered: true
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.right: keys.left
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: row.modelData.description
                color: row.selected ? "#cba6f7" : "#cdd6f4"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
            }

            // One glass keycap per key.
            Row {
                id: keys

                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: row.modelData.keys

                    Rectangle {
                        required property string modelData

                        width: Math.max(26, keyLabel.implicitWidth + 16)
                        height: 26
                        radius: 8
                        color: "transparent"

                        GlassSurface {
                            radius: parent.radius
                        }

                        Text {
                            id: keyLabel

                            anchors.centerIn: parent
                            text: parent.modelData
                            color: "#cba6f7"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.weight: Font.Bold
                        }

                    }

                }

            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: {
                    if (hovered)
                        keybindings.selectedIndex = row.index;

                }
            }

            TapHandler {
                onTapped: keybindings.run(row.modelData)
            }

        }

    }

}
