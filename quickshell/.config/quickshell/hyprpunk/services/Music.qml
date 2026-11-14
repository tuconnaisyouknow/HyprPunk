pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Spotify, the one player the shell follows (browsers and other MPRIS players are
// ignored), which way its tracks were skipped, and what playerctl knows sooner than
// MPRIS says it: where the track is, and how long it is.
Singleton {
    id: music

    readonly property var player: {
        for (const player of Mpris.players.values) {
            if (player.dbusName === "org.mpris.MediaPlayer2.spotify")
                return player;

        }
        return null;
    }
    // Which way the last skip went (1 next, -1 previous), valid until skipUntil, so the
    // bar's discs roll the right way: MPRIS never says which way the track changed.
    property int skipDirection: 0
    property real skipUntil: 0

    // "Previous" was asked, which may only have restarted the track.
    signal previousRequested()

    function skip(direction) {
        skipDirection = direction;
        skipUntil = Date.now() + 2000;
        if (direction < 0)
            previousRequested();

        Quickshell.execDetached(["playerctl", "-p", "spotify", direction < 0 ? "previous" : "next"]);
    }

    // onDone({position, length (both in seconds, length 0 when unknown), track}).
    function probe(onDone) {
        prober.createObject(music, {
            "onDone": onDone
        });
    }

    // One per question, so the card and the bar can both ask at once.
    Component {
        id: prober

        Process {
            id: process

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
