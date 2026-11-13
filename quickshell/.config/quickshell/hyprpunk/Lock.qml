import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland

// The lock screen. It's a real session lock: if the shell crashes, the screens stay
// locked. Every screen gets the bar's look, and the password is checked by PAM like
// any login. `qs -c hyprpunk ipc call lock lock` locks it (the shortcut, the session
// menu and hypridle, for logind, do that), `lock lockInstantly` skips the animation before sleep.
// Without the animation in the settings (LockSettings), the lock covers the screen and
// leaves it at once, and only its island plays its padlock.
Scope {
    id: locker

    // The bars, for their state (resources, network, sound, battery, player).
    required property var bars
    // Typed on any screen, shown on all of them.
    property string password: ""
    property bool authenticating: false
    // The right password: the padlock opens, then the screens unlock.
    property bool unlocking: false
    // Told in the island after a failed try, "" otherwise.
    property string error: ""
    // Locking for sleep (lid closed): no animation, it would freeze and only play on waking.
    property bool instant: false
    // The animation turned off in the settings, as it was when locking: no blur, no pills
    // moving, so no snapshot or wave to wait for either.
    property bool still: false
    readonly property bool locked: sessionLock.locked
    // Snapshots of the screens just before locking, so the lock can blur out of them
    // and back. Uncompressed, since a PNG takes grim most of a second.
    readonly property string snapshotDir: Quickshell.env("XDG_RUNTIME_DIR")
    // For the lock screen's music wave.
    readonly property var music: cava
    // On its way or up.
    property bool covering: false
    // Waiting for the desktop's wave to lie flat, so the snapshot doesn't keep it.
    property bool waitingForWave: false

    // Each failed try, for the island to shake.
    signal failed()
    // Sleep arrives mid-animation: finish it at once.
    signal settled()

    function engage(instant) {
        if (sessionLock.locked) {
            if (instant)
                settled();

            return ;
        }
        // On its way: the lock comes right after, already shown.
        if (covering) {
            if (instant) {
                locker.instant = true;
                if (waitingForWave)
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
        deadline.restart();
        // Not before sleep, which can't wait, nor for a wave turned off.
        if (still)
            lockNow();
        else if (music.playing && MusicSettings.wave && !instant)
            waitingForWave = true;
        else
            freeze();
    }

    // Snapshots the screens, then locks.
    function freeze() {
        waitingForWave = false;
        snapshot.command = ["sh", "-c", snapshot.script, "sh", snapshotDir].concat(Quickshell.screens.map((screen) => {
            return screen.name;
        }));
        snapshot.running = true;
    }

    // Once the lock screens have played their way out. The first one is enough: they all
    // play the same animation.
    function unlockNow() {
        if (!unlocking)
            return ;

        sessionLock.locked = false;
        covering = false;
        tellBars(false);
        unlocking = false;
        cleanup.running = true;
    }

    function lockNow() {
        deadline.stop();
        waitingForWave = false;
        if (!sessionLock.locked) {
            tellBars(true);
            sessionLock.locked = true;
        }

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

    function barFor(screen) {
        if (!screen)
            return null;

        return bars.find((bar) => {
            return bar.screen.name === screen.name;
        }) || bars[0] || null;
    }

    // Tells the bars when the session locks, so their islands keep still under the lock.
    function tellBars(sessionLocked) {
        for (const bar of bars)
            bar.sessionLocked = sessionLocked;

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
            if (locker.waitingForWave)
                locker.freeze();

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

    Timer {
        id: errorHide

        interval: 2200
        onTriggered: locker.error = ""
    }

    // Decode each screen's wallpaper ahead of time (a 4K one takes a good part of a
    // second), so the lock finds it in the cache and can fade it in straight away.
    Variants {
        model: locker.bars

        Image {
            required property var modelData

            source: Session.wallpaper !== "" ? "file://" + Session.wallpaper : ""
            sourceSize.width: modelData.screen.width
            sourceSize.height: modelData.screen.height
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

    }

    WlSessionLock {
        id: sessionLock

        LockSurface {
            lock: locker
        }

    }

    IpcHandler {
        function lock(): void {
            locker.engage(false);
        }

        function lockInstantly(): void {
            locker.engage(true);
        }

        target: "lock"
    }

}
