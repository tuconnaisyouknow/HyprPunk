pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Lyrics for whatever is playing, fetched from lrclib.net by ~/Scripts/lyrics-lookup.py
// (which caches them). On by default; the media card has a button to switch them off,
// since every lookup tells lrclib what you're listening to.
Singleton {
    id: lyrics

    property bool enabled: true
    // The track request() was last given, "artist\ntitle\nalbum\nseconds".
    property string track: ""
    // The track the lines belong to, once lrclib answered for it.
    property string answeredTrack: ""
    // "idle" (off, or nothing playing), "loading", "found", "missing" or "network".
    property string status: "idle"
    property var lines: []
    property bool synced: false
    property bool instrumental: false
    // lrclib is often busy, so each failed lookup waits twice as long before trying again.
    property int failures: 0

    function setEnabled(on) {
        enabled = on;
        stateFile.setText(on ? "on\n" : "off\n");
    }

    function request(artist, title, album, seconds) {
        const key = [artist, title, album, Math.round(seconds)].join("\n");
        if (key === track)
            return ;

        // Same track, length a hair off (MPRIS and playerctl round differently): don't
        // look it up again, it would blank the lines and might bring different ones.
        const asked = track.split("\n");
        const sameTrack = asked.length === 4 && asked[0] === artist && asked[1] === title && asked[2] === album;
        if (sameTrack && Math.abs(asked[3] - seconds) <= 2)
            return ;

        // Same track, but its real length just arrived (MPRIS often sends the previous
        // track's length first): look it up again, keeping the current lines on screen
        // until the new ones land, so they don't blink out and back.
        if (sameTrack && answeredTrack === track) {
            track = key;
            answeredTrack = key;
            fetch(true);
            return ;
        }
        track = key;
        failures = 0;
        retry.stop();
        lines = [];
        synced = false;
        instrumental = false;
        status = title !== "" && enabled ? "loading" : "idle";
        fetch();
    }

    // again: looks up the track even though it has lines (its length changed).
    function fetch(again) {
        if (!enabled || track === "" || (answeredTrack === track && !again) || retry.running)
            return ;

        // A track asked for during a lookup waits for it to finish.
        if (lookup.running) {
            lookup.again = true;
            lookup.forced = lookup.forced || again === true;
            return ;
        }
        const [artist, title, album, seconds] = track.split("\n");
        if (title === "")
            return ;

        status = "loading";
        lookup.asked = track;
        lookup.command = ["python3", Quickshell.env("HOME") + "/Scripts/lyrics-lookup.py", artist, title, album, seconds];
        lookup.running = true;
    }

    function take(text) {
        let result;
        try {
            result = JSON.parse(text);
        } catch (error) {
            result = {
                "status": "network"
            };
        }
        if (lookup.asked !== track)
            return ;

        if (result.status === "network") {
            // Looked up again for its length: the lines found stay.
            if (answeredTrack === track) {
                status = lines.length > 0 ? "found" : "missing";
                return ;
            }
            status = "network";
            retry.interval = Math.min(120000, 10000 * Math.pow(2, failures));
            failures += 1;
            retry.restart();
            return ;
        }
        answeredTrack = track;
        lines = result.lines || [];
        synced = result.synced === true;
        instrumental = result.instrumental === true;
        status = result.status === "found" ? "found" : "missing";
    }

    onEnabledChanged: {
        if (enabled) {
            fetch();
        } else {
            retry.stop();
            if (answeredTrack !== track)
                status = "idle";

        }
    }

    Timer {
        id: retry

        onTriggered: lyrics.fetch()
    }

    Process {
        id: lookup

        property string asked: ""
        property bool again: false
        property bool forced: false

        onExited: {
            if (again) {
                const force = forced;
                again = false;
                forced = false;
                Qt.callLater(() => {
                    return lyrics.fetch(force);
                });
            }
        }

        stdout: StdioCollector {
            onStreamFinished: lyrics.take(text)
        }

    }

    FileView {
        id: stateFile

        path: Session.stateDir + "/lyrics-enabled"
        // Read before the first lookup, so a switched-off choice holds from the start.
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: lyrics.enabled = text().trim() !== "off"
    }

}
