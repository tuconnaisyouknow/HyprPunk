pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What the player the shell follows plays (Players.qml): which track and which way it
// changed, where it is, and its lyrics.
// Some players' MPRIS position drifts (Spotify keeps counting from the previous track),
// so the position and the length come from playerctl, asked every second while a player
// card shows them (ServiceRef). The cards draw the position between two answers with
// positionAt(), on their own frames.
Singleton {
    id: music

    readonly property var player: Players.followed
    // Whether it plays, as the shell shows it. Some players (spotifast) pass through a
    // pause while they load the next track, right after announcing it: that one only
    // counts if it lasts, or the play button and the equalizers would flicker.
    property bool playing: false
    // The track the shell has taken in, by its address and its title (two tracks with the
    // same title stay apart, and so do a player's that gives no address). It lags behind
    // playerTrack() while a change is being taken in.
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
    // The last answer: where the track was, and when (ms, like Date.now()). One value, so
    // nothing ever reads a new place with the old time: the position would leap a second
    // ahead and back, and the player's times would roll twice.
    property var polled: ({
        "position": 0,
        "time": 0
    })
    property real polledLength: 0
    // How late an answer can be, in seconds: some players (spotifast) only move their
    // position every second or so, and give the last one until then.
    readonly property real answerAge: 1.5
    // An answer came since something started showing the position: before it, a card
    // waking up would show where the track was before the computer slept.
    property bool positionKnown: false
    // 0 for what has no end, like a stream.
    readonly property real length: polledLength > 0 ? polledLength : player !== null && player.lengthSupported ? player.length : 0

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
        return player !== null ? trackOf(player.metadata["xesam:url"], player.metadata["xesam:title"]) : "";
    }

    function trackOf(url, title) {
        return String(url ?? "") + "\n" + String(title ?? "");
    }

    // Where the track is at time (ms, like Date.now()). Between two answers it keeps
    // ticking, but only for a second or so: after a sleep it would race ahead by however
    // long the computer slept.
    function positionAt(time) {
        const position = polled.position + (playing ? Math.max(0, Math.min(1500, time - polled.time)) / 1000 : 0);
        return length > 0 ? Math.min(length, position) : position;
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
            // Not every player says it restarted the track instead (Spotify sends no
            // Seeked signal).
            restartProbe.restart();
            player.previous();
        } else {
            player.next();
        }
    }

    // Takes the player's state in, holding playing through a pause that comes with a
    // track change, until the player plays again or the pause lasts.
    function followPlaying() {
        const plays = player !== null && player.isPlaying;
        const now = Date.now();
        const changing = now - trackChangeTime < loadingPause.interval || now < skipUntil;
        if (playing && !plays && changing) {
            loadingPause.restart();
            return ;
        }
        loadingPause.stop();
        playing = plays;
    }

    function toggle() {
        if (player !== null && player.canTogglePlaying)
            player.togglePlaying();

    }

    function toggleShuffle() {
        if (player !== null && player.shuffleSupported)
            player.shuffle = !player.shuffle;

    }

    function place(position, time) {
        polled = {
            "position": position,
            "time": time
        };
    }

    function seek(seconds) {
        if (player === null || !player.canSeek)
            return ;

        player.position = seconds;
        place(seconds, Date.now());
        pollAfterSeek.restart();
    }

    function poll() {
        if (player === null)
            return ;

        const asked = player;
        prober.createObject(music, {
            "player": Players.nameOf(asked),
            "onDone": (state) => {
                // Another player's answer, asked just before you changed source.
                if (asked !== music.player)
                    return ;

                // A track starts from the beginning: just after a change, a position
                // further on than the time since is still the previous track's.
                const now = Date.now();
                const sinceChange = (now - music.trackChangeTime) / 1000;
                if (sinceChange < music.answerAge && state.position > sinceChange + music.answerAge)
                    return ;

                // Otherwise an answer is never ahead, but may be late: while playing, one a
                // little behind the drawn position says nothing new, and stepping back to it
                // would take the lyrics back a line. Further behind, the track was sought back.
                const first = !music.positionKnown;
                const drawn = music.positionAt(now);
                const late = music.playing && !first && state.position < drawn && drawn - state.position < music.answerAge;
                music.place(late ? drawn : state.position, now);
                music.polledLength = state.length;
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
        // The player still reports the old track's position at this point: the new one
        // starts from the beginning until it answers.
        remember(0);
        place(0, Date.now());
        trackChangeTime = Date.now();
        trackChanged(direction);
    }

    function reset() {
        currentTrack = playerTrack();
        history = currentTrack !== "" ? [currentTrack] : [];
        if (player !== null)
            remember();

    }

    // Another player: drawn from where MPRIS says it is until playerctl answers, so a
    // card on screen doesn't show the previous player's position meanwhile.
    onPlayerChanged: {
        loadingPause.stop();
        playing = player !== null && player.isPlaying;
        reset();
        place(player !== null ? player.position : 0, Date.now());
        polledLength = 0;
        if (running)
            poll();

        lyricsRequest.restart();
    }
    Component.onCompleted: playing = player !== null && player.isPlaying
    onRunningChanged: {
        if (running) {
            positionKnown = false;
            poll();
        }
    }
    // The drawn position stops and starts with the player, from where it stands: resuming
    // from an old answer would leap ahead, and later answers wouldn't take it back.
    onPlayingChanged: {
        const now = Date.now();
        place(polled.position + (playing ? 0 : Math.max(0, Math.min(1500, now - polled.time)) / 1000), now);
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
            music.followPlaying();
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

    // A pause through a track change that lasted: it's a real one.
    Timer {
        id: loadingPause

        interval: 500
        onTriggered: music.playing = music.player !== null && music.player.isPlaying
    }

    Timer {
        id: restartCheck

        interval: 150
        onTriggered: music.checkRestart()
    }

    Timer {
        id: restartProbe

        interval: 350
        onTriggered: {
            if (music.player !== null)
                prober.createObject(music, {
                "player": Players.nameOf(music.player),
                "onDone": (state) => {
                // Not yet the new track: a change that hasn't been announced isn't a restart.
                    if (state.track === music.currentTrack)
                        music.checkRestart(state.position);

                }
            });

        }
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

            // The player asked, as playerctl names it.
            required property string player
            // onDone({position, length (both in seconds, 0 when the player gives none), track}).
            property var onDone

            // In microseconds, with the track it belongs to, so a change that hasn't been
            // announced yet isn't taken for this track's. Between tabs: a player may leave
            // any of them empty.
            command: ["playerctl", "-p", player, "metadata", "--format", "{{position}}\t{{mpris:length}}\t{{xesam:url}}\t{{xesam:title}}"]
            running: true

            stdout: StdioCollector {
                onStreamFinished: {
                    // Nothing at all: the player has just quit.
                    const [position, length, url, title] = text.replace(/\n$/, "").split("\t");
                    if (length !== undefined)
                        process.onDone({
                        "position": (parseInt(position) || 0) / 1e6,
                        "length": (parseInt(length) || 0) / 1e6,
                        "track": music.trackOf(url, title)
                    });

                    process.destroy();
                }
            }

        }

    }

}
