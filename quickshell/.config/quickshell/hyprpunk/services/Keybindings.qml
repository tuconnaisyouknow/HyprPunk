pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Every Hyprland shortcut that has a description, with its keys as you'd write them, and
// running one for you (through run_keybinding in lib/bind.lua). Read each time someone
// looks (ServiceRef), since a config reload may change them.
Singleton {
    id: shortcuts

    property int refCount: 0
    // [{ "keys": [string], "description" }]
    property var binds: []
    readonly property bool loading: reader.running

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
            "period": ".",
            "left": "←",
            "right": "→",
            "up": "↑",
            "down": "↓",
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
        Quickshell.execDetached(["hyprctl", "eval", "run_keybinding(" + JSON.stringify(bind.description) + ")"]);
    }

    onRefCountChanged: {
        if (refCount === 1)
            reader.running = true;

    }

    Process {
        id: reader

        command: ["hyprctl", "binds", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    // hyprctl can list the same bind twice.
                    const seen = {};
                    shortcuts.binds = JSON.parse(text).filter((bind) => {
                        return bind.has_description && bind.description !== "";
                    }).map((bind) => {
                        return {
                            "keys": shortcuts.bindKeys(bind),
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
                    shortcuts.binds = [];
                }
            }
        }

    }

}
