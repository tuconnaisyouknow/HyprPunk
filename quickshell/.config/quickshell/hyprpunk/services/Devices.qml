pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// The hardware the island's OSDs report on: Caps Lock and Num Lock, the screen's
// brightness, the keyboard's backlight and the touchpad. Watched once for the whole
// shell, and each change you make comes out as a signal for every screen's island.
Singleton {
    id: devices

    property bool capsLock: false
    property bool numLock: false
    property bool touchpadEnabled: true
    // touchpadctl.sh found one, for the settings' touchpad part.
    property bool hasTouchpad: false
    // In %, and whether the screen has a backlight at all (desktops don't).
    property int brightness: 0
    property bool hasBacklight: false
    // -1 until known, and on keyboards without a backlight.
    property int keyboardBacklight: -1
    property int keyboardBacklightMax: 3
    // Until these times (ms since epoch), the next keyboard backlight or screen brightness
    // change shows no OSD. Idle sets them before it dims things.
    property real keyboardOsdMutedUntil: 0
    property real screenOsdMutedUntil: 0
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

    // A change Idle announced is not shown, only that one.
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

    // The keyboard you type on: Hyprland keeps each one's locks apart. Read at startup,
    // then each time Hyprland says a lock key was handled (input.lua).
    Process {
        id: locksRead

        // A lock key pressed while the last answer was on its way: ask again after it.
        property bool asked: false

        function ask() {
            if (running)
                asked = true;
            else
                running = true;
        }

        command: ["sh", "-c", "hyprctl devices -j 2>/dev/null | jq -r '.keyboards[] | select(.main) | .capsLock, .numLock'"]
        running: true
        onExited: {
            if (asked) {
                asked = false;
                running = true;
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines.length >= 2)
                    devices.updateLocks(lines[0] === "true", lines[1] === "true");

            }
        }

    }

    Connections {
        function onRawEvent(event) {
            if (event.name === "custom" && event.data === "hyprpunk-locks")
                locksRead.ask();

        }

        target: Hyprland
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

    // The backlight only sends events when it changes.
    TiedProcess {
        program: ["udevadm", "monitor", "--kernel", "--subsystem-match=backlight"]
        running: true

        stdout: SplitParser {
            onRead: (line) => {
                // Still writing what the slider asked for: read it back once written.
                if (line.includes("(backlight)") && !brightnessWriteDelay.running)
                    brightnessRead.running = true;

            }
        }

    }

    Process {
        // Found the way idle-lights.sh does, since the name depends on the driver.
        command: ["sh", "-c", "device=$(\"$1\" keyboard) && echo \"/sys/class/leds/$device\"", "sh", Session.scripts + "/idle-lights.sh"]
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

    // Only the driver writes this, on Fn key presses, never brightnessctl (Idle),
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
            devices.hasTouchpad = /(?:^|\n)device=/.test(text());
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
