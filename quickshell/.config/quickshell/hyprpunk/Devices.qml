pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The hardware the island's OSDs report on: Caps Lock and Num Lock, the screen's
// brightness, the keyboard's backlight and the touchpad. Watched once for the whole
// shell, and each change you make comes out as a signal for every screen's island.
Singleton {
    id: devices

    property bool capsLock: false
    property bool numLock: false
    property bool touchpadEnabled: true
    // In %, and whether the screen has a backlight at all (desktops don't).
    property int brightness: 0
    property bool hasBacklight: false
    // -1 until known, and on keyboards without a backlight.
    property int keyboardBacklight: -1
    property int keyboardBacklightMax: 3
    // Until these times (ms since epoch), the next keyboard backlight or screen brightness
    // change shows no OSD. hypridle sets them through ipc before it dims things.
    property real keyboardOsdMutedUntil: 0
    property real screenOsdMutedUntil: 0
    // The keyboards' Caps Lock and Num Lock lights, as the kernel exposes them.
    property var capsLockLeds: []
    property var numLockLeds: []
    // Path of each light that's on.
    property var ledsOn: ({})
    property bool locksKnown: false
    property bool touchpadKnown: false
    property bool keyboardHwKnown: false
    property string keyboardBacklightPath: ""
    property int pendingBrightness: 0

    signal capsLockToggled(bool enabled)
    signal numLockToggled(bool enabled)
    signal touchpadToggled(bool enabled)
    signal brightnessShown(int percent)
    signal keyboardBacklightShown(int level, int max)

    // Follows the slider at once, and writes it a moment later so dragging doesn't
    // start a brightnessctl at every step.
    function setBrightness(percent) {
        brightness = percent;
        pendingBrightness = percent;
        brightnessWriteDelay.restart();
        brightnessShown(percent);
    }

    function updateLocks(caps, num) {
        if (locksKnown) {
            if (caps !== capsLock)
                capsLockToggled(caps);

            if (num !== numLock)
                numLockToggled(num);

        }
        capsLock = caps;
        numLock = num;
        locksKnown = true;
    }

    function ledChanged(path, on) {
        if (ledsOn[path] === on)
            return ;

        const leds = Object.assign({}, ledsOn);
        leds[path] = on;
        ledsOn = leds;
        updateLocks(capsLockLeds.some((led) => {
            return leds[led];
        }), numLockLeds.some((led) => {
            return leds[led];
        }));
    }

    // A change hypridle announced is not shown, only that one.
    function screenOsdMuted() {
        const muted = Date.now() < screenOsdMutedUntil;
        if (muted)
            screenOsdMutedUntil = 0;

        return muted;
    }

    function keyboardOsdMuted() {
        const muted = Date.now() < keyboardOsdMutedUntil;
        if (muted)
            keyboardOsdMutedUntil = 0;

        return muted;
    }

    // Lists the lights again when a keyboard comes or goes.
    Process {
        id: ledList

        command: ["sh", "-c", "for led in /sys/class/leds/*::capslock /sys/class/leds/*::numlock; do [ -e \"$led/brightness\" ] && echo \"$led\"; done"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const leds = text.split("\n").filter((line) => {
                    return line !== "";
                });
                devices.capsLockLeds = leds.filter((led) => {
                    return led.endsWith("::capslock");
                });
                devices.numLockLeds = leds.filter((led) => {
                    return led.endsWith("::numlock");
                });
            }
        }

    }

    Variants {
        id: ledFiles

        model: devices.capsLockLeds.concat(devices.numLockLeds)

        FileView {
            required property string modelData

            path: modelData + "/brightness"
            printErrors: false
            onLoaded: devices.ledChanged(modelData, parseInt(text()) > 0)
        }

    }

    // sysfs sends no event when a light changes, so they are read a few times a second.
    // Reading a file is cheap, unlike starting a command each time.
    Timer {
        interval: 120
        running: true
        repeat: true
        onTriggered: {
            if (devices.capsLockLeds.length > 0 || devices.numLockLeds.length > 0) {
                for (const file of ledFiles.instances)
                    file.reload();
            } else if (!ledList.running && !hyprlandLocks.running) {
                hyprlandLocks.running = true;
            }
        }
    }

    // For keyboards without lights, ask Hyprland instead.
    Process {
        id: hyprlandLocks

        command: ["sh", "-c", "hyprctl devices -j 2>/dev/null | jq -r '([.keyboards[]?.capsLock] | any), ([.keyboards[]?.numLock] | any)'"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines.length >= 2)
                    devices.updateLocks(lines[0] === "true", lines[1] === "true");

            }
        }

    }

    Process {
        id: brightnessRead

        // The screen's backlight only. A desktop has none, and brightnessctl would
        // read the first LED it finds instead.
        command: ["brightnessctl", "-c", "backlight", "-m"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split(",");
                const known = devices.hasBacklight;
                devices.hasBacklight = fields.length >= 4;
                if (!devices.hasBacklight)
                    return ;

                const percent = parseInt(fields[3]);
                const changed = known && percent !== devices.brightness;
                devices.brightness = percent;
                if (changed && !devices.screenOsdMuted())
                    devices.brightnessShown(percent);

            }
        }

    }

    Timer {
        id: brightnessWriteDelay

        interval: 35
        onTriggered: Quickshell.execDetached(["brightnessctl", "-c", "backlight", "set", devices.pendingBrightness + "%"])
    }

    // The backlight and the keyboards' lights only send events when they change.
    Process {
        command: ["udevadm", "monitor", "--kernel", "--subsystem-match=backlight", "--subsystem-match=leds"]
        running: true

        stdout: SplitParser {
            onRead: (line) => {
                if (line.includes("(backlight)")) {
                    // Still writing what the slider asked for: read it back once written.
                    if (!brightnessWriteDelay.running)
                        brightnessRead.running = true;

                } else if (/ (add|remove) /.test(line) && /::(capslock|numlock)/.test(line)) {
                    ledList.running = true;
                }
            }
        }

    }

    Process {
        // Found the same way as keyboard-backlight.sh does, since the name depends on the driver.
        command: ["sh", "-c", "device=$(\"$HOME/Scripts/keyboard-backlight.sh\" status) && echo \"/sys/class/leds/$device\""]
        running: true

        stdout: StdioCollector {
            onStreamFinished: devices.keyboardBacklightPath = text.trim()
        }

    }

    // Some laptops (ASUS, ThinkPad…) change the backlight themselves on Fn keys, with no
    // inotify event from sysfs, so the value is read four times a second.
    FileView {
        id: keyboardBacklightFile

        path: devices.keyboardBacklightPath !== "" ? devices.keyboardBacklightPath + "/brightness" : ""
        printErrors: false
        onLoaded: {
            const level = parseInt(text());
            if (isNaN(level) || level === devices.keyboardBacklight)
                return ;

            if (devices.keyboardBacklight >= 0 && !devices.keyboardOsdMuted())
                devices.keyboardBacklightShown(level, devices.keyboardBacklightMax);

            devices.keyboardBacklight = level;
        }
    }

    Timer {
        interval: 250
        running: devices.keyboardBacklightPath !== ""
        repeat: true
        onTriggered: keyboardBacklightFile.reload()
    }

    // Only the driver writes this, on Fn key presses, never brightnessctl (hypridle),
    // so these changes always get the OSD.
    FileView {
        path: devices.keyboardBacklightPath !== "" ? devices.keyboardBacklightPath + "/brightness_hw_changed" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const level = parseInt(text());
            if (devices.keyboardHwKnown && !isNaN(level))
                devices.keyboardBacklightShown(level, devices.keyboardBacklightMax);

            // The first load only reads the last value, it is not a key press.
            devices.keyboardHwKnown = true;
        }
        // Unreadable until the first Fn key press since boot.
        onLoadFailed: devices.keyboardHwKnown = true
    }

    FileView {
        path: devices.keyboardBacklightPath !== "" ? devices.keyboardBacklightPath + "/max_brightness" : ""
        printErrors: false
        onLoaded: devices.keyboardBacklightMax = parseInt(text()) || 3
    }

    FileView {
        id: touchpadFile

        function update() {
            const match = text().match(/(?:^|\n)enabled=(true|false)(?:\n|$)/);
            if (match === null)
                return ;

            const enabled = match[1] === "true";
            if (devices.touchpadKnown && enabled !== devices.touchpadEnabled)
                devices.touchpadToggled(enabled);

            devices.touchpadEnabled = enabled;
            devices.touchpadKnown = true;
        }

        path: Session.stateDir + "/touchpad-state.conf"
        watchChanges: true
        preload: true
        printErrors: false
        onLoaded: update()
        onTextChanged: update()
        onFileChanged: reload()
    }

}
