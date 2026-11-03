import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// The music's loudness per pitch, for a music wave (VisualizerWave). The desktop's runs
// cava while a player plays and streams each frame over a socket; the lock's follows that
// stream, so both waves have the very same shape when one takes over from the other.
Scope {
    id: cavaLevels

    // Follows the desktop's levels instead of running cava.
    property bool shared: false
    // Off, a shared one stops following.
    property bool active: true
    // Any player, not only Spotify: whatever is playing moves the wave.
    readonly property bool playing: {
        for (const player of Mpris.players.values) {
            if (player.isPlaying)
                return true;

        }
        return false;
    }
    // From 0 to 1, low notes first. Empty while nothing plays.
    property var levels: []
    // The lock screens following the stream.
    property var followers: []
    readonly property string streamPath: Quickshell.env("XDG_RUNTIME_DIR") + "/hyprpunk-music.sock"

    // cava's frame: the levels out of 1000, separated by ';'.
    function read(line) {
        const levels = line.split(";").filter((value) => {
            return value.trim() !== "";
        }).map((value) => {
            return Number(value) / 1000;
        });
        if (levels.length > 0)
            cavaLevels.levels = levels;

    }

    // Forgets the last frame once the wave has faded out, so the next song doesn't start from it
    Timer {
        running: !cavaLevels.playing
        interval: 700
        onTriggered: cavaLevels.levels = []
    }

    Process {
        running: !cavaLevels.shared && cavaLevels.playing
        command: ["cava", "-p", Quickshell.shellPath("data/visualizer.cava")]

        stdout: SplitParser {
            onRead: (line) => {
                cavaLevels.read(line);
                for (const follower of cavaLevels.followers) {
                    follower.write(line + "\n");
                    follower.flush();
                }
            }
        }

    }

    SocketServer {
        active: !cavaLevels.shared
        path: cavaLevels.streamPath

        handler: Socket {
            id: follower

            Component.onCompleted: cavaLevels.followers = cavaLevels.followers.concat([follower])
            Component.onDestruction: cavaLevels.followers = cavaLevels.followers.filter((other) => {
                return other !== follower;
            })
        }

    }

    Socket {
        path: cavaLevels.streamPath
        connected: cavaLevels.shared && cavaLevels.active

        parser: SplitParser {
            onRead: (line) => {
                return cavaLevels.read(line);
            }
        }

    }

}
