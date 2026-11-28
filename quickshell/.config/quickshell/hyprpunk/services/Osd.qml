pragma Singleton

import QtQuick
import Quickshell
import qs.config
import qs.theme

// What the island briefly shows as things happen: a level (volume, brightness), the
// screenshot just taken, the battery and the AirPods take it over (OsdTimeline); a switch
// you turn (the microphone, Caps Lock, Num Lock, the touchpad) only opens its ends, around
// the time (IslandView.glance). Decided once for the whole shell and announced to every
// island, which shows it for as long as it says when it's meant for every screen or for
// its own. Always on: the changes come whether or not you look.
Singleton {
    id: osd

    // Every field an OSD has, empty: what the islands draw before the first one.
    // {kind, screen, icon, label, enabled, level, maxLevel, image, title, file, ringLevel,
    // ringCharging}. kind is "" for a level, "battery", "screenshot" or "airpods"; screen
    // is "" for every screen.
    readonly property var blank: ({
        "kind": "",
        "screen": "",
        "icon": "",
        "label": "",
        "enabled": false,
        "level": 0,
        "maxLevel": 0,
        "image": "",
        "title": "",
        "file": "",
        "ringLevel": null,
        "ringCharging": false
    })
    // Back in sight after something else had its place, an OSD stays at least this long.
    readonly property int backTime: 1500
    // What a surface already shows you while it's in sight (ServiceRef): the control
    // center's sliders. The change shows there, so its OSD doesn't.
    readonly property QtObject volumeInSight: QtObject {
        property int refCount: 0
    }
    readonly property QtObject brightnessInSight: QtObject {
        property int refCount: 0
    }
    readonly property QtObject microphoneInSight: QtObject {
        property int refCount: 0
    }

    // An OSD, whole, and how long it stays in ms (-1 until something replaces it).
    signal announced(var content, int duration)
    // A switch at the island's ends, and how long they stay out: {kind: "switch", screen,
    // icon, enabled}.
    signal glanced(var content, int duration)

    // How long an OSD stays, its usual time stretched as the settings ask (OsdSettings).
    function time(milliseconds) {
        return Math.round(milliseconds * OsdSettings.pace);
    }

    // The AirPods put in your ears: the island turns into their OSD as their card folds
    // away. pods: {screen, image (their picture, or ""), level (null when unknown),
    // charging}.
    function showAirPods(pods) {
        if (!OsdSettings.shows("airpods"))
            return ;

        osd.show({
            "kind": "airpods",
            "screen": pods.screen,
            "image": pods.image,
            "ringLevel": pods.level,
            "ringCharging": pods.charging,
            "label": "AirPods"
        }, osd.time(3000));
    }

    // m:ss, h:mm:ss past an hour.
    function formatDuration(seconds) {
        const pad = (value) => {
            return String(value).padStart(2, "0");
        };
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor(seconds / 60) % 60;
        return (hours > 0 ? hours + ":" + pad(minutes) : minutes) + ":" + pad(seconds % 60);
    }

    // A gauge of level / maxLevel: segments up to ten, a bar past that.
    function showLevel(icon, label, enabled, level, maxLevel) {
        show({
            "icon": icon,
            "label": label,
            "enabled": enabled,
            "level": level,
            "maxLevel": maxLevel
        }, time(1500));
    }

    function showSwitch(icon, enabled) {
        glanced({
            "kind": "switch",
            "screen": "",
            "icon": icon,
            "enabled": enabled
        }, time(1500));
    }

    function showBattery(title) {
        // The critical alert stays until the computer is plugged in.
        const duration = title === "On battery" && Battery.timeLeft <= 0 ? 8000 : title === "Charging" || title === "On battery" ? 2500 : 6000;
        show({
            "kind": "battery",
            "label": title
        }, Battery.critical ? -1 : time(duration));
    }

    function show(content, duration) {
        announced(Object.assign({}, blank, content), duration);
    }

    // Whether an OSD comes back once something else had its place (another OSD, a card
    // on the island): a screenshot, the battery or the AirPods do, for the rest of their
    // time. A level or a switch only said what you just did: shown later, it'd be stale.
    function comesBack(content) {
        return content.kind !== "";
    }

    // Unplugged, the battery's OSD waits for the time left, then gives a moment to read it.
    function estimating(content) {
        return content !== null && content.kind === "battery" && content.label === "On battery" && Battery.timeLeft <= 0;
    }

    Connections {
        function onAlerted(stage) {
            osd.showBattery(stage === 2 ? "Battery critical" : "Battery low");
        }

        // Plugging in or unplugging shows, unless unplugging brought up a warning
        // instead, or the settings leave it out.
        function onSourceSwitched() {
            if (!Battery.present || !OsdSettings.shows("power"))
                return ;

            if (!Battery.onBattery)
                osd.showBattery("Charging");
            else if (Battery.alertStage === 0)
                osd.showBattery("On battery");
        }

        target: Battery
    }

    Connections {
        function onVolumeAdjusted() {
            // Muted, the gauge keeps its level and turns to the secondary color.
            if (OsdSettings.shows("volume") && osd.volumeInSight.refCount === 0)
                osd.showLevel(Icons.volume(Audio.volume, Audio.muted), "Volume", !Audio.muted, Audio.volume, 100);

        }

        function onMicToggled() {
            if (OsdSettings.shows("microphone") && osd.microphoneInSight.refCount === 0)
                osd.showSwitch(Audio.micMuted ? "mic_off" : "mic", !Audio.micMuted);

        }

        target: Audio
    }

    Connections {
        function onCapsLockToggled(enabled) {
            if (OsdSettings.shows("keys"))
                osd.showSwitch("keyboard_capslock", enabled);

        }

        function onNumLockToggled(enabled) {
            if (OsdSettings.shows("keys"))
                osd.showSwitch("looks_one", enabled);

        }

        function onTouchpadToggled(enabled) {
            if (OsdSettings.shows("keys"))
                osd.showSwitch("trackpad_input", enabled);

        }

        function onBrightnessShown(percent) {
            if (OsdSettings.shows("brightness") && osd.brightnessInSight.refCount === 0)
                osd.showLevel(Icons.brightness(percent), "Brightness", percent > 0, percent, 100);

        }

        function onKeyboardBacklightShown(level, max) {
            if (OsdSettings.shows("brightness"))
                osd.showLevel("keyboard", "Keyboard light", level > 0, level, max);

        }

        target: Devices
    }

    // The screenshot or recording just taken, on its own screen.
    Connections {
        function onTakenChanged() {
            const taken = Screenshot.taken;
            if (taken === null || !OsdSettings.shows("screenshots"))
                return ;

            osd.show({
                "kind": "screenshot",
                "screen": taken.screen,
                "image": taken.file,
                "file": taken.video || taken.file,
                "title": taken.video ? "Recording" : "Screenshot",
                "label": taken.video ? osd.formatDuration(taken.duration) + " · Saved" : [taken.annotated ? "Annotated" : "", taken.copied ? "Copied" : "", taken.saved ? "Saved" : ""].filter((word) => {
                    return word !== "";
                }).join(" · ")
            }, osd.time(3500));
        }

        target: Screenshot
    }

}
