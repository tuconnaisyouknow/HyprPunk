pragma Singleton

import QtQuick
import Quickshell
import qs.config
import qs.theme

// What the island briefly shows as things happen: a level (volume, brightness), an on/off
// switch, the screenshot just taken, the battery and the AirPods. Decided once for the
// whole shell; each island shows it when it's meant for every screen or for its own
// (Bar, LockSurface). Always on: the changes come whether or not you look.
Singleton {
    id: osd

    // What shows, null when nothing does: {kind, screen, icon, label, enabled, level,
    // maxLevel, image, title, file, ringLevel, ringCharging}. kind is "" for a level or a
    // switch, "battery", "screenshot" or "airpods"; screen is "" for every screen.
    property var current: null
    // Every field an OSD has, empty: what the islands draw before the first one.
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
    // The OSD it interrupted, shown again for the rest of its time afterwards (a volume
    // change over a screenshot's thumbnail): {content, remaining in ms}, or null.
    property var resume: null
    property real endsAt: 0
    // Unplugged, the battery's OSD waits for the time left, then gives a moment to read it.
    readonly property bool estimating: current !== null && current.kind === "battery" && current.label === "On battery" && Battery.timeLeft <= 0
    // Islands where the OSD is landing under a card folding back onto it (ServiceRef):
    // its time running out waits for them, so it gets all the way in before it goes.
    readonly property QtObject landing: QtObject {
        property int refCount: 0
    }
    property bool endHeld: false

    // What tells one OSD from another: its switch or level, its screenshot, or its kind.
    // The same one changing state stays in place, another one fades in (IslandView).
    function identity(content) {
        return content.kind === "" ? content.label : content.kind + content.file;
    }

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

    // With maxLevel > 0, a gauge of level / maxLevel replaces the On/Off badge.
    function showLevel(icon, label, enabled, level, maxLevel) {
        show({
            "icon": icon,
            "label": label,
            "enabled": enabled,
            "level": level || 0,
            "maxLevel": maxLevel || 0
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
        keepInterrupted(content.kind || "");
        current = Object.assign({}, blank, content);
        restart(duration);
    }

    // Before another OSD replaces the one showing: a screenshot, battery or AirPods OSD
    // with time left comes back afterwards. A level or a switch just goes, and so does an
    // OSD replaced by a newer one of its kind.
    function keepInterrupted(kind) {
        if (current === null || current.kind === "" || kind === current.kind || Battery.critical)
            return ;

        const remaining = endsAt - Date.now();
        if (remaining >= 800)
            resume = {
            "content": current,
            "remaining": Math.max(1500, remaining)
        };

    }

    // A negative duration stays until something replaces it.
    function restart(duration) {
        endHeld = false;
        if (duration < 0) {
            hideDelay.stop();
            return ;
        }
        hideDelay.interval = duration;
        endsAt = Date.now() + duration;
        hideDelay.restart();
    }

    // Ends the OSD now, as its delay would. Another OSD over the critical battery alert
    // goes back to the alert, and one over a screenshot, battery or AirPods OSD goes back
    // to it for the rest of its time.
    function end() {
        hideDelay.stop();
        endHeld = false;
        if (Battery.critical) {
            showBattery("Battery critical");
        } else if (resume !== null) {
            const interrupted = resume;
            resume = null;
            current = interrupted.content;
            restart(interrupted.remaining);
        } else {
            current = null;
        }
    }

    // Gone without coming back to what it interrupted (its screenshot opened, or the lock
    // screen already showed it), except the critical battery alert, which stays.
    function dismiss() {
        resume = null;
        if (Battery.critical) {
            showBattery("Battery critical");
            return ;
        }
        hideDelay.stop();
        current = null;
    }

    onCurrentChanged: {
        if (current === null)
            resume = null;

    }
    // The time left as soon as it's known, then the usual moment to read it.
    onEstimatingChanged: {
        if (!estimating && current !== null && current.label === "On battery")
            restart(time(2500));

    }

    ServiceRef {
        service: Battery
        active: osd.estimating
    }

    Timer {
        id: hideDelay

        onTriggered: {
            if (osd.landing.refCount > 0)
                osd.endHeld = true;
            else
                osd.end();
        }
    }

    Connections {
        function onRefCountChanged() {
            if (osd.landing.refCount === 0 && osd.endHeld)
                osd.end();

        }

        target: osd.landing
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
            if (OsdSettings.shows("volume"))
                osd.showLevel(Icons.volume(Audio.volume, Audio.muted), "Volume", !Audio.muted, Audio.volume, 100);

        }

        function onMicToggled() {
            if (OsdSettings.shows("microphone"))
                osd.showLevel(Audio.micMuted ? "󰍭" : "󰍬", "Microphone", !Audio.micMuted);

        }

        target: Audio
    }

    Connections {
        function onCapsLockToggled(enabled) {
            if (OsdSettings.shows("keys"))
                osd.showLevel("󰪛", "Caps Lock", enabled);

        }

        function onNumLockToggled(enabled) {
            if (OsdSettings.shows("keys"))
                osd.showLevel("󰎤", "Num Lock", enabled);

        }

        function onTouchpadToggled(enabled) {
            if (OsdSettings.shows("keys"))
                osd.showLevel("󰟸", "Touchpad", enabled);

        }

        function onBrightnessShown(percent) {
            if (OsdSettings.shows("brightness"))
                osd.showLevel(Icons.brightness(percent), "Brightness", percent > 0, percent, 100);

        }

        function onKeyboardBacklightShown(level, max) {
            if (OsdSettings.shows("brightness"))
                osd.showLevel("󰌌", "Keyboard light", level > 0, level, max);

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
