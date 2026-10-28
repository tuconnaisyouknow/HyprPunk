import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland

// The lock screen. It's a real session lock: if the shell crashes, the screens stay
// locked. Every screen gets the bar's look, and the password is checked by PAM like
// any login. `qs -c hyprpunk ipc call lock lock` locks it (the shortcut, the session
// menu and hypridle do that), `lock lockInstantly` skips the animation before sleep.
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
    readonly property bool locked: sessionLock.locked
    // Snapshots of the screens just before locking, so the lock can blur out of them
    // and back. Uncompressed, since a PNG takes grim most of a second.
    readonly property string snapshotDir: Quickshell.env("XDG_RUNTIME_DIR")

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
        // The screens are being frozen: the lock comes right after, already shown.
        if (snapshot.running) {
            if (instant)
                locker.instant = true;

            return ;
        }
        locker.instant = instant;
        password = "";
        error = "";
        unlocking = false;
        snapshot.command = ["sh", "-c", snapshot.script, "sh", snapshotDir].concat(Quickshell.screens.map((screen) => {
            return screen.name;
        }));
        snapshot.running = true;
        // Locks anyway if grim takes too long.
        snapshotTimeout.restart();
    }

    function lockNow() {
        snapshotTimeout.stop();
        if (!sessionLock.locked)
            sessionLock.locked = true;

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
                unlockDelay.restart();
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

    // The padlock opens and the screen fades out first.
    Timer {
        id: unlockDelay

        interval: 1000
        onTriggered: {
            sessionLock.locked = false;
            locker.unlocking = false;
            cleanup.running = true;
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

    Timer {
        id: snapshotTimeout

        interval: 1000
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

            source: modelData.wallpaperPath !== "" ? "file://" + modelData.wallpaperPath : ""
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
