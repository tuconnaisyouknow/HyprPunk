pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import qs.config
import qs.theme

// Locking the session: the way in (the islands coming to rest and the desktop's wave
// lying flat, the screens' snapshots, then the lock) and out (the password checked by PAM
// like any login, the lock screens playing their way out and the bars' islands back to
// the time). The lock screens themselves are LockScreens's.
// The bars aren't shown under the lock: once it goes, each shows the one frame it drew as
// the lock came up (secured()) until it draws again, a few frames later. So the lock
// starts from the islands as they were, and leaves each screen's island as it ends, the
// time back in its place, to a window of its own that a fresh frame lets through
// (LockRelay): it stands in for the bar's until the bar draws again (home()).
// `qs -c hyprpunk ipc call lock lock` locks (the shortcut, the session menu and
// hypridle, for logind, do that), `lock lockInstantly` skips the animation before sleep.
// Without the animation in the settings (LockSettings), the lock covers the screen and
// leaves it at once, and only its island moves.
Singleton {
    id: locker

    // Typed on any screen, shown on all of them.
    property string password: ""
    property bool authenticating: false
    // The right password: the lock screens play their way out, then unlock.
    property bool unlocking: false
    // Told in the island after a failed try, "" otherwise.
    property string error: ""
    // Locking for sleep (lid closed): no animation, it would freeze and only play on waking.
    property bool instant: false
    // The animation turned off in the settings, as it was when locking: no blur, no pills
    // moving, so no snapshot or wave to wait for either.
    property bool still: false
    // The session lock is up (WlSessionLock): the bars keep still under it.
    property bool locked: false
    // Snapshots of the screens just before locking, so the lock can blur out of them
    // and back. Uncompressed, since a PNG takes grim most of a second.
    readonly property string snapshotDir: Quickshell.env("XDG_RUNTIME_DIR")
    // For the lock screen's music wave.
    readonly property var music: cava
    // On its way or up.
    property bool covering: false
    // The bars' islands hidden while the lock is up: what they draw under it shows as it
    // goes, under the relays, which then stand in for them.
    property bool islandAway: false
    // Each screen's island as the lock left it, by screen name: the lock's frame
    // (`shot`, null without an island), where the island is in it, and whether its relay
    // has drawn it. Kept until that screen's bar draws again.
    property var relays: ({})
    // Waiting for the desktop's wave to lie flat, so the snapshot doesn't keep it.
    property bool waitingForWave: false

    // Each failed try, for the island to shake.
    signal failed()
    // Sleep arrives mid-animation: finish it at once.
    signal settled()

    function engage(instant) {
        if (locked) {
            if (instant) {
                locker.instant = true;
                settled();
            }
            return ;
        }
        // On its way: before sleep, the lock comes as soon as it can, already shown.
        if (covering) {
            if (instant && !snapshot.running) {
                locker.instant = true;
                resting.stop();
                waitingForWave = false;
                freeze();
            }
            return ;
        }
        covering = true;
        locker.instant = instant;
        still = !LockSettings.animation;
        password = "";
        error = "";
        unlocking = false;
        relays = {};
        deadline.restart();
        // Sleep can't wait for the islands or the wave, only for the snapshot the lock
        // clears back to when you're back.
        if (instant) {
            freeze();
            return ;
        }
        waitingForWave = !still && music.playing && MusicSettings.wave;
        resting.restart();
    }

    // Once the islands are at rest and the desktop's wave lies flat: the lock then starts
    // from the screen as it is, with nothing moving while it comes up.
    function proceed() {
        if (resting.running || waitingForWave || !covering || locked)
            return ;

        if (still)
            lockNow();
        else
            freeze();
    }

    // Snapshots the screens, then locks.
    function freeze() {
        snapshot.command = ["sh", "-c", snapshot.script, "sh", snapshotDir].concat(Quickshell.screens.map((screen) => {
            return screen.name;
        }));
        snapshot.running = true;
    }

    // A lock screen has played its way out and hands its island over (LockSurface).
    function relay(name, shot, rect) {
        if (!unlocking)
            return ;

        setRelay(name, {
            "shot": shot,
            "rect": rect,
            "drawn": shot === null
        });
    }

    // A relay drew its first frame: it will show the moment the lock goes.
    function relayDrawn(name) {
        if (relays[name] === undefined)
            return ;

        setRelay(name, Object.assign({}, relays[name], {
            "drawn": true
        }));
    }

    function setRelay(name, value) {
        const next = Object.assign({}, relays);
        if (value === null)
            delete next[name];
        else
            next[name] = value;
        relays = next;
        if (unlocking && Quickshell.screens.every((screen) => {
            return relays[screen.name]?.drawn ?? false;
        }))
            unlockNow();

    }

    // Every island handed over. The bars show theirs again at once, unseen: their first
    // frame once the lock is gone shows the island as the relays do.
    function unlockNow() {
        if (!unlocking)
            return ;

        handover.stop();
        islandAway = false;
        locked = false;
        covering = false;
        unlocking = false;
        cleanup.running = true;
    }

    // The lock screens are shown (WlSessionLock.secure): the bars, out of sight, draw
    // their islands hidden, the frame they keep until the lock is gone.
    function secured() {
        islandAway = true;
    }

    // A bar drew again after the lock went: its island shows for itself, and its relay
    // goes.
    function home(name) {
        setRelay(name, null);
    }

    function lockNow() {
        deadline.stop();
        resting.stop();
        waitingForWave = false;
        locked = true;
    }

    function snapshotFor(screen) {
        return screen ? snapshotDir + "/hyprpunk-lock-" + screen.name + ".ppm" : "";
    }

    function submit() {
        if (password === "" || authenticating || unlocking)
            return ;

        error = "";
        authenticating = true;
        if (!pam.start()) {
            authenticating = false;
            fail("Authentication unavailable");
        }
    }

    function fail(message) {
        password = "";
        error = message;
        errorHide.restart();
        failed();
    }



    PamContext {
        id: pam

        config: "login"
        onPamMessage: {
            if (responseRequired)
                respond(locker.password);

        }
        onCompleted: (result) => {
            locker.authenticating = false;
            if (result === PamResult.Success) {
                locker.password = "";
                locker.unlocking = true;
                handover.restart();
                // The lock screens play their way out, then unlock (unlockNow).
            } else {
                // pam_faillock tells why once the account is held.
                locker.fail(messageIsError && message !== "" ? message : result === PamResult.MaxTries ? "Too many tries" : "Wrong password");
            }
        }
        onError: {
            locker.authenticating = false;
            locker.fail("Authentication error");
        }
    }

    // The desktop's levels, followed while the lock covers the screen: the desktop's wave
    // settles into the floor meanwhile (VisualizerShell.qml), and rises once unlocked.
    CavaLevels {
        id: cava

        shared: true
        // Turned off, there's no wave to follow: cava, started for the lock, would send
        // its first levels most of a second later, in the middle of the animation.
        active: locker.covering && MusicSettings.wave
        onFlat: {
            if (!locker.waitingForWave)
                return ;

            locker.waitingForWave = false;
            locker.proceed();
        }
    }

    Process {
        id: snapshot

        // $1 the directory, then the screens' names.
        readonly property string script: 'dir="$1"; shift
rm -f "$dir"/hyprpunk-lock-*.ppm
for output; do grim -o "$output" -t ppm "$dir/hyprpunk-lock-$output.ppm" & done
wait'

        onExited: locker.lockNow()
    }

    // A card folding back onto its island, or the island leaving an OSD (Bar.lockShown).
    // grim then takes a moment more before the lock comes.
    Timer {
        id: resting

        interval: Math.max(Motion.swap.duration, Motion.resize.large.duration)
        onTriggered: locker.proceed()
    }

    // Locks anyway when something's late: the desktop's wave lying flat (not running, or
    // getting no frames) or grim. The lock then comes without the screen it blurs out of.
    Timer {
        id: deadline

        interval: 1500
        onTriggered: locker.lockNow()
    }

    Process {
        id: cleanup

        command: ["sh", "-c", 'rm -f "$1"/hyprpunk-lock-*.ppm', "sh", locker.snapshotDir]
    }

    // Unlocks anyway when the lock screens are late handing their islands over, well
    // past their way out: those screens show no island a moment.
    Timer {
        id: handover

        interval: 2000
        onTriggered: locker.unlockNow()
    }

    Timer {
        id: errorHide

        interval: 2200
        onTriggered: locker.error = ""
    }

}
