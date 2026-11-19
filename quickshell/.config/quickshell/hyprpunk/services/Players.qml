pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.config

// The player the shell follows, among the ones the settings let through (any, unless
// MusicSettings names some): the one you picked in a player card while it runs, or else
// the one that played last. What it plays is Music's, and the wave only moves for it
// (CavaLevels).
Singleton {
    id: players

    readonly property string busPrefix: "org.mpris.MediaPlayer2."
    // The running players the settings let through.
    readonly property var sources: Mpris.players.values.filter((player) => {
        return MusicSettings.sources.length === 0 || MusicSettings.sources.includes(sourceOf(player));
    })
    // The player picked by hand, by its bus name, "" to follow whatever plays. It holds
    // whenever that player runs, until you pick again.
    property string picked: ""
    // The players' bus names, from the last one that started or stopped playing: of
    // two that play, the last to start, and of none, the last to stop.
    property var recent: []
    // Both are read from where they're saved: a shell starting before that would save
    // its own order over the one the other shell follows.
    property bool restored: false
    readonly property var followed: {
        const chosen = sources.find((player) => {
            return player.dbusName === picked;
        });
        if (chosen)
            return chosen;

        // One that plays, or else the one that just did.
        for (const playing of [true, false]) {
            for (const name of recent) {
                const found = sources.find((player) => {
                    return player.dbusName === name && (!playing || player.isPlaying);
                });
                if (found)
                    return found;

            }
        }
        return sources[0] ?? null;
    }
    // What a player card's selector shows as chosen: the pick only counts while it runs.
    readonly property string pickedSource: followed !== null && followed.dbusName === picked ? picked : ""

    // A player's name in the settings, the same for each of its instances: "firefox" for
    // "org.mpris.MediaPlayer2.firefox.instance_1_42".
    function sourceOf(player) {
        return nameOf(player).split(".")[0];
    }

    // As playerctl names it: "firefox.instance_1_42".
    function nameOf(player) {
        return player.dbusName.slice(busPrefix.length);
    }

    // The source you follow from now on, by its bus name, or "" for whatever plays.
    function pick(name) {
        follow(name, recent);
    }

    // A player started or stopped playing: it's the one followed unless another plays,
    // or you picked one.
    function played(player) {
        const name = player.dbusName;
        if (recent[0] !== name)
            follow(picked, [name].concat(recent.filter((other) => {
            return other !== name;
        })).slice(0, 20));

    }

    // Saved for the lock screen's shell, which follows the same player.
    function follow(nextPicked, nextRecent) {
        picked = nextPicked;
        recent = nextRecent;
        saved.setText([picked].concat(recent).join("\n") + "\n");
    }

    // Every player, not only the ones let through: the order holds when the settings change.
    Instantiator {
        model: players.restored ? Mpris.players : []

        Connections {
            required property var modelData

            function onIsPlayingChanged() {
                players.played(modelData);
            }

            target: modelData
            // One that's new and already plays. One that's just there, paused, takes
            // nobody's place, and one already known keeps its own.
            Component.onCompleted: {
                if (modelData.isPlaying && !players.recent.includes(modelData.dbusName))
                    players.played(modelData);

            }
        }

    }

    // The pick on its first line, then the players from the one that played last.
    // Gone with the session, like the bus names in it.
    FileView {
        id: saved

        path: Quickshell.env("XDG_RUNTIME_DIR") + "/hyprpunk-music-source"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const lines = text().split("\n");
            const names = lines.slice(1).filter((name) => {
                return name !== "";
            });
            players.picked = lines[0];
            if (names.join("\n") !== players.recent.join("\n"))
                players.recent = names;

            players.restored = true;
        }
        onLoadFailed: players.restored = true
    }

}
