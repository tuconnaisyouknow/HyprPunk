pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Lyrics of the playing track, looked up on lrclib.net by ~/Scripts/lyrics-lookup.py
// (which caches them). On unless switched off with the media card's button, a choice
// kept in the state directory: every lookup tells lrclib what is playing.
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
    // lrclib is often busy: each failed lookup waits twice as long before the next.
    property int failures: 0

    function setEnabled(on) {
        enabled = on;
        stateFile.setText(on ? "on\n" : "off\n");
    }

    function request(artist, title, album, seconds) {
        const key = [artist, title, album, Math.round(seconds)].join("\n");
        if (key === track)
            return ;

        track = key;
        failures = 0;
        retry.stop();
        lines = [];
        synced = false;
        instrumental = false;
        status = title !== "" && enabled ? "loading" : "idle";
        fetch();
    }

    function fetch() {
        if (!enabled || track === "" || answeredTrack === track || retry.running)
            return ;

        // A track asked for during a lookup waits for it to finish.
        if (lookup.running) {
            lookup.again = true;
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

        onExited: {
            if (again) {
                again = false;
                Qt.callLater(lyrics.fetch);
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
