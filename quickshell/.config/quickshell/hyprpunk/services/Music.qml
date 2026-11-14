pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Spotify, the one player the shell follows (browsers and other MPRIS players are
// ignored): which track plays and which way it changed, where it is, and its lyrics.
// Spotify's MPRIS position drifts (it keeps counting from the previous track), so the
// position and the length come from playerctl, asked every second while a player card
// shows them (ServiceRef). The cards draw the position between two answers with
// positionAt(), on their own frames.
Singleton {
    id: music

    readonly property var player: {
        for (const player of Mpris.players.values) {
            if (player.dbusName === "org.mpris.MediaPlayer2.spotify")
                return player;

        }
        return null;
    }
    readonly property bool playing: player !== null && player.isPlaying
    // The track the shell has taken in, by Spotify's id (two tracks with the same title
    // stay apart). It lags behind playerTrack() while a change is being taken in.
    property string currentTrack: ""
    // The tracks played, to tell going back from going on when nobody said which.
    property var history: []
    // Which way the next change goes, while a skip asked for it is under way: MPRIS never
    // says which way the track changed.
    property int skipHint: 0
    property real skipUntil: 0
    // The last position the player gave, when, and whether it was playing then, to tell
    // a restart from a seek.
    property real knownPosition: 0
    property real knownTime: 0
    property bool knownPlaying: false
    property real trackChangeTime: 0

    // Something shows the position: it's asked for every second.
    property int refCount: 0
    readonly property bool running: refCount > 0 && player !== null
    property real polledPosition: 0
    property real polledLength: 0
    property real polledTime: 0
    // An answer came since something started showing the position: before it, a card
    // waking up would show where the track was before the computer slept.
    property bool positionKnown: false
    readonly property real length: polledLength > 0 ? polledLength : player !== null ? player.length : 0

    readonly property bool lyricsShown: Lyrics.enabled && player !== null
    // The lyrics asked for are this track's: right after a skip they're still the
    // previous one's, and would scroll back up to its start.
    readonly property bool lyricsCurrent: {
        if (player === null)
            return false;

        const asked = Lyrics.track.split("\n");
        return asked[0] === player.trackArtist && asked[1] === player.trackTitle;
    }
    // A card only grows for the lyrics once there are lines to show.
    readonly property bool lyricsFound: lyricsShown && lyricsCurrent && Lyrics.answeredTrack === Lyrics.track && Lyrics.lines.length > 0
    // The next track's lyrics are being looked for.
    readonly property bool lyricsLoading: lyricsShown && (!lyricsCurrent || Lyrics.status === "loading")

    // The track changed: 1 to the next one, -1 back to the previous one.
    signal trackChanged(int direction)
    // "Previous" brought the same track back to its start.
    signal restarted()

    // Read when asked, not bound: Spotify sends the new cover before it announces the
    // track, and a binding would still hold the old id when the cover comes in.
    function playerTrack() {
        return player !== null ? (player.metadata["mpris:trackid"] ?? (player.trackTitle + player.trackArtist)) : "";
    }

    // Where the track is at time (ms, like Date.now()). Between two answers it keeps
    // ticking, but only for a second or so: after a sleep it would race ahead by however
    // long the computer slept.
    function positionAt(time) {
        return Math.min(length, polledPosition + (playing ? Math.max(0, Math.min(1500, time - polledTime)) / 1000 : 0));
    }

    // The line being sung at position, a hair early so it doesn't feel late. -1 before
    // the first one, or without timed lines.
    function lyricsLine(position) {
        if (!Lyrics.synced || Lyrics.answeredTrack !== Lyrics.track)
            return -1;

        const now = position + 0.2;
        let index = -1;
        for (let i = 0; i < Lyrics.lines.length && Lyrics.lines[i].t <= now; i++)
            index = i;
        return index;
    }

    // 1 next, -1 previous: the way the bar's discs roll.
    function skip(direction) {
        if (player === null)
            return ;

        skipHint = direction;
        skipUntil = Date.now() + 2000;
        if (direction < 0) {
            // Spotify doesn't always say it restarted the track instead (no Seeked signal).
            restartProbe.restart();
            player.previous();
        } else {
            player.next();
        }
    }

    function seek(seconds) {
        if (player === null || !player.canSeek)
            return ;

        player.position = seconds;
        polledPosition = seconds;
        polledTime = Date.now();
        pollAfterSeek.restart();
    }

    function poll() {
        if (player === null)
            return ;

        prober.createObject(music, {
            "onDone": (state) => {
                const first = !music.positionKnown;
                music.polledPosition = state.position;
                music.polledLength = state.length;
                music.polledTime = Date.now();
                music.positionKnown = true;
                if (first)
                    lyricsRequest.restart();

            }
        });
    }

    function remember(position) {
        knownPosition = position ?? player.position;
        knownTime = Date.now();
        knownPlaying = player.isPlaying;
    }

    // "Previous" a few seconds in restarts the track instead of changing it: the
    // position jumps back to 0 on the same track.
    function checkRestart(position) {
        if (player === null)
            return ;

        const current = position ?? player.position;
        const expected = knownPosition + (knownPlaying ? (Date.now() - knownTime) / 1000 : 0);
        // A jump right after a track change isn't a restart, and "previous" that early
        // changes track anyway.
        const settled = Date.now() - trackChangeTime > 2000;
        const restart = settled && playerTrack() === currentTrack && current < 1.5 && expected > 2;
        remember(current);
        if (restart)
            restarted();

    }

    function changeTrack() {
        const id = playerTrack();
        if (id === currentTrack)
            return ;

        // Not asked for (media keys, the phone…): back to the previous track in the
        // history means backwards.
        const played = history.slice();
        const back = played.length >= 2 && played[played.length - 2] === id;
        const direction = Date.now() < skipUntil ? skipHint : back ? -1 : 1;
        if (direction < 0 && back)
            played.pop();
        else
            played.push(id);
        history = played.slice(-50);
        skipUntil = 0;
        currentTrack = id;
        // The player still reports the old track's position at this point.
        remember(0);
        trackChangeTime = Date.now();
        trackChanged(direction);
    }

    function reset() {
        currentTrack = playerTrack();
        history = currentTrack !== "" ? [currentTrack] : [];
        if (player !== null)
            remember();

    }

    onPlayerChanged: {
        reset();
        lyricsRequest.restart();
    }
    onRunningChanged: {
        if (running) {
            positionKnown = false;
            poll();
        }
    }
    onLengthChanged: lyricsRequest.restart()

    Connections {
        function onPostTrackChanged() {
            music.changeTrack();
            music.poll();
        }

        function onTrackTitleChanged() {
            lyricsRequest.restart();
        }

        function onTrackArtistChanged() {
            lyricsRequest.restart();
        }

        // Leaves time for a real track change (which also resets the position) to be
        // announced first.
        function onPositionChanged() {
            restartCheck.restart();
        }

        function onIsPlayingChanged() {
            music.remember();
            music.poll();
        }

        target: music.player
    }

    Timer {
        interval: 1000
        running: music.running
        repeat: true
        onTriggered: music.poll()
    }

    Timer {
        id: pollAfterSeek

        interval: 300
        onTriggered: music.poll()
    }

    Timer {
        id: restartCheck

        interval: 150
        onTriggered: music.checkRestart()
    }

    Timer {
        id: restartProbe

        interval: 350
        onTriggered: prober.createObject(music, {
            "onDone": (state) => {
                // Not yet the new track: a change that hasn't been announced isn't a restart.
                if (state.track === music.currentTrack)
                    music.checkRestart(state.position);

            }
        })
    }

    // Asked once the track settles: the title, the artist and the length don't change
    // together.
    Timer {
        id: lyricsRequest

        interval: 500
        onTriggered: {
            if (music.player === null)
                return ;

            // The length may still be the previous track's, in MPRIS and in playerctl's
            // first answer too, so that first answer asks once more.
            if (!music.positionKnown) {
                music.poll();
                return ;
            }
            if (music.length > 0)
                Lyrics.request(music.player.trackArtist, music.player.trackTitle, music.player.trackAlbum, music.length);

        }
    }

    // One per question, so a poll and a restart probe can run at once.
    Component {
        id: prober

        Process {
            id: process

            // onDone({position, length (both in seconds, length 0 when unknown), track}).
            property var onDone

            // In microseconds, with the track it belongs to, so a change that hasn't been
            // announced yet isn't taken for this track's.
            command: ["playerctl", "-p", "spotify", "metadata", "--format", "{{position}} {{mpris:length}} {{mpris:trackid}}"]
            running: true

            stdout: StdioCollector {
                onStreamFinished: {
                    const [position, length, track] = text.trim().split(" ");
                    if (!isNaN(parseInt(position)))
                        process.onDone({
                        "position": parseInt(position) / 1e6,
                        "length": isNaN(parseInt(length)) ? 0 : parseInt(length) / 1e6,
                        "track": track || ""
                    });

                    process.destroy();
                }
            }

        }

    }

}
