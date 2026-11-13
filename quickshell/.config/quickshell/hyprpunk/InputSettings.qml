pragma Singleton

import QtQuick
import Quickshell

// How the mouse and the touchpad behave, saved by inputctl.sh, which Hyprland follows
// (input_state.lua). The settings window's page reads and changes it here.
Singleton {
    // Every setting as the script saves it, "touchpad.tap" → "true".
    readonly property var values: file.values

    // A number setting, null until the file is read.
    function number(key) {
        return values[key] !== undefined ? Number(values[key]) : null;
    }

    function on(key) {
        return values[key] === "true";
    }

    function set(key, value) {
        file.run(["set", key, String(value)]);
    }

    SettingsFile {
        id: file

        fileName: "input.conf"
        script: "inputctl.sh"
    }

}
