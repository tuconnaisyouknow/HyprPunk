import QtQuick
import Quickshell
import qs.services

// The OSDs of one screen's island (Osd) and how long each stays. The island showing an
// OSD owns its time: it stops while a card has the island's place, so one waiting there
// leaves the other screens' alone. One per bar, which the lock's island reads too.
Scope {
    id: timeline

    required property string screenName
    // A card has the island's place: the OSD waits under it, or lands in the island under
    // one folding back, and its time waits too.
    property bool held: false
    // What shows, null when nothing does: an Osd content.
    property var current: null
    // The OSDs it interrupted that come back (Osd.comesBack), the latest last, each with
    // the time it had left: [{ content, remaining }].
    property var interrupted: []
    // The time of the one showing: running out at endsAt, or stopped with remaining left.
    // -1 stays until something replaces it (the critical battery alert).
    property real endsAt: 0
    property real remaining: -1
    readonly property bool estimating: Osd.estimating(current)

    function show(content, duration) {
        keepInterrupted(content.kind);
        current = content;
        restart(duration);
    }

    // Before another OSD takes the place of the one showing: one that comes back is kept
    // for afterwards with the time it had left, unless a newer one of its kind replaces it.
    function keepInterrupted(kind) {
        const kept = interrupted.filter((entry) => {
            return entry.content.kind !== kind;
        });
        if (current !== null && Osd.comesBack(current) && current.kind !== kind) {
            const left = timeLeft();
            if (left < 0 || left >= 800)
                kept.push({
                "content": current,
                "remaining": left < 0 ? -1 : Math.max(Osd.backTime, left)
            });

        }
        interrupted = kept;
    }

    function timeLeft() {
        return hideDelay.running ? endsAt - Date.now() : remaining;
    }

    function restart(duration) {
        hideDelay.stop();
        remaining = duration;
        run();
    }

    // Its time runs out from what's left, unless it's held or stays.
    function run() {
        if (current === null || hideDelay.running || held || remaining < 0)
            return ;

        hideDelay.interval = remaining;
        endsAt = Date.now() + remaining;
        hideDelay.restart();
    }

    // Held: what's left of its time waits, enough to be read once back.
    function hold() {
        if (!hideDelay.running)
            return ;

        hideDelay.stop();
        remaining = Math.max(Osd.backTime, endsAt - Date.now());
    }

    // Ends the OSD, as its time would: the last one it interrupted comes back.
    function end() {
        hideDelay.stop();
        const next = interrupted[interrupted.length - 1];
        interrupted = interrupted.slice(0, -1);
        current = next !== undefined ? next.content : null;
        if (next !== undefined)
            restart(next.remaining);

    }

    // Gone with what it interrupted (its screenshot opened, or the lock screen already
    // showed them), but for what stays until replaced.
    function dismiss() {
        interrupted = interrupted.filter((entry) => {
            return entry.remaining < 0;
        });
        if (timeLeft() >= 0)
            end();

    }

    onHeldChanged: {
        if (held)
            hold();
        else
            run();
    }
    // The time left as soon as it's known, then the usual moment to read it.
    onEstimatingChanged: {
        if (!estimating && current !== null && current.label === "On battery")
            restart(Osd.time(2500));

    }

    Connections {
        function onAnnounced(content, duration) {
            if (content.screen === "" || content.screen === timeline.screenName)
                timeline.show(content, duration);

        }

        target: Osd
    }

    ServiceRef {
        service: Battery
        active: timeline.estimating
    }

    Timer {
        id: hideDelay

        onTriggered: timeline.end()
    }

}
