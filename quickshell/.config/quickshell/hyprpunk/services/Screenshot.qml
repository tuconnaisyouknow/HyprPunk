pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// Screenshots and screen recordings, asked for (request) by the shortcuts, the screenshot
// menu and the island. Screenshots go to their folder, the clipboard or both, recordings
// to theirs, with the sound and frame rate you chose (CaptureSettings). It holds what the
// shell shows of them: the recording under way, the region being chosen and the last
// capture.
Singleton {
    id: screenshot

    // Busy taking, choosing or saving one: other requests wait their turn.
    property bool busy: false
    property string mode: ""
    property string screenName: ""
    // The screen's scale, to turn the selection's logical size into grim's pixels.
    property real scale: 1
    // The screen's place in the layout, for the recorded region.
    property point origin: Qt.point(0, 0)
    // The whole screen, frozen before the selection is shown over it.
    property string frozenFile: ""
    // The windows visible on it then ({x, y, width, height} on the screen), the top one
    // first, for the selection to pick one.
    property var windows: []
    property var monitorInfo: null
    // The screen being recorded, since recordingStarted (ms since epoch), to its file.
    // The recording runs on its own (screen-recorder.sh) and tells the shell that
    // follows it, so one that reloads finds it again.
    property bool recording: false
    property string recordingScreen: ""
    property real recordingStarted: 0
    property string recordingFile: ""
    readonly property string recorderScript: Session.scripts + "/screen-recorder.sh"
    // The region being chosen, for the selector: {screen, file, scale, mode,
    // annotatedFile}, null otherwise.
    property var selection: null
    // The last capture, for the island: {screen, file, annotated, copied, saved}, or for a
    // recording {screen, file (its first frame), video, duration in s}.
    property var taken: null

    // The region chosen ({x, y, width, height} on the screen), null when cancelled.
    signal selected(var rect)

    // mode: "screen", "region", "annotate", "record", "record-region", "share-region" or
    // "stop"; screen: its name, empty for the focused one; delay in ms, so a menu can
    // fold away first. Asking to record while a recording runs stops it.
    function request(mode, screen, delay) {
        if (mode === "stop" || (recording && mode.startsWith("record"))) {
            stopRecording();
            return ;
        }
        if (busy)
            return ;

        requestDelay.mode = mode;
        requestDelay.screen = screen || "";
        requestDelay.interval = Math.max(1, delay || 0);
        requestDelay.restart();
    }

    // The selector's answer: the region, null when cancelled.
    function select(rect) {
        selection = null;
        selected(rect);
        if (!busy)
            return ;

        if (rect === null) {
            cleanup.command = ["rm", "-f", frozenFile, frozenFile + ".annotated.png"];
            cleanup.running = true;
            busy = false;
            return ;
        }
        if (mode === "record-region") {
            cleanup.command = ["rm", "-f", frozenFile];
            cleanup.running = true;
            record(rect);
            return ;
        }
        // The region an app gets to share: ScreenShare takes it from here.
        if (mode === "share-region") {
            cleanup.command = ["rm", "-f", frozenFile];
            cleanup.running = true;
            busy = false;
            return ;
        }
        save(rect);
    }

    function capture(mode, name) {
        const monitor = Hyprland.monitors.values.find((item) => {
            return item.name === name;
        }) || Hyprland.focusedMonitor;
        if (monitor === null)
            return ;

        busy = true;
        CaptureSettings.readUserDirs();
        screenshot.mode = mode;
        screenName = monitor.name;
        scale = monitor.lastIpcObject.scale || 1;
        origin = Qt.point(monitor.x, monitor.y);
        if (mode === "record") {
            record(null);
            return ;
        }
        if (mode !== "screen") {
            windows = [];
            monitorInfo = monitor.lastIpcObject;
            windowsReader.running = true;
        }
        frozenFile = Quickshell.env("XDG_RUNTIME_DIR") + "/hyprpunk-screenshot-" + Date.now() + ".png";
        grimProcess.command = ["grim", "-o", screenName, frozenFile];
        grimProcess.running = true;
    }

    // rect: the logical region on the screen, null for the whole screen; with a file,
    // the region already annotated.
    // Only copied, it's kept in the runtime folder for the island's preview, until the next one.
    function save(rect) {
        const name = "Screenshot_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".png";
        const file = CaptureSettings.saves ? CaptureSettings.screenshotsFolder + "/" + name : Quickshell.env("XDG_RUNTIME_DIR") + "/hyprpunk-copied/" + name;
        const crop = rect === null || rect.file ? "" : [rect.width, rect.height, rect.x, rect.y].map((value) => {
            return Math.round(value * scale);
        }).join(":");
        saveProcess.file = file;
        saveProcess.copies = CaptureSettings.copies;
        saveProcess.saves = CaptureSettings.saves;
        saveProcess.command = ["sh", "-c", saveProcess.script, "sh", frozenFile, file, crop, rect !== null && rect.file ? rect.file : "", saveProcess.copies ? "copy" : "", saveProcess.saves ? "" : "replace"];
        saveProcess.running = true;
    }

    // rect: the logical region on the screen, null for the whole screen.
    function record(rect) {
        const file = CaptureSettings.recordingsFolder + "/Recording_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".mp4";
        const area = rect === null ? ["-o", screenName] : ["-g", Math.round(origin.x + rect.x) + "," + Math.round(origin.y + rect.y) + " " + Math.round(rect.width) + "x" + Math.round(rect.height)];
        // What plays on the computer, or the microphone, as PulseAudio names them.
        const audio = {
            "system": ["--audio=@DEFAULT_MONITOR@"],
            "microphone": ["--audio=@DEFAULT_SOURCE@"]
        }[CaptureSettings.audio] || [];
        const framerate = CaptureSettings.framerate > 0 ? ["-r", String(CaptureSettings.framerate)] : [];
        recorder.program = [recorderScript, "start", screenName, file].concat(audio, framerate, area);
        // Once the selection is gone from the screen.
        recordDelay.restart();
    }

    function stopRecording() {
        if (recording)
            Quickshell.execDetached([recorderScript, "stop"]);

    }

    Timer {
        id: requestDelay

        property string mode: ""
        property string screen: ""

        onTriggered: screenshot.capture(mode, screen)
    }

    Timer {
        id: recordDelay

        interval: 150
        onTriggered: {
            recorder.running = true;
            screenshot.busy = false;
        }
    }

    Process {
        id: grimProcess

        onExited: (code) => {
            if (code !== 0) {
                screenshot.busy = false;
                return ;
            }
            if (screenshot.mode === "screen")
                screenshot.save(null);
            else
                screenshot.selection = {
                "screen": screenshot.screenName,
                "file": screenshot.frozenFile,
                "scale": screenshot.scale,
                "mode": screenshot.mode,
                "annotatedFile": screenshot.frozenFile + ".annotated.png"
            };
        }
    }

    // Its workspace's windows and any open special one's, topmost first: fullscreen and
    // floating ones, then by last focus.
    Process {
        id: windowsReader

        command: ["hyprctl", "-j", "clients"]

        stdout: StdioCollector {
            onStreamFinished: {
                const info = screenshot.monitorInfo;
                const workspaces = [info.activeWorkspace ? info.activeWorkspace.id : -1, info.specialWorkspace ? info.specialWorkspace.id : 0];
                let clients;
                try {
                    clients = JSON.parse(text);
                } catch (error) {
                    return ;
                }
                screenshot.windows = clients.filter((client) => {
                    return client.mapped && !client.hidden && workspaces.includes(client.workspace.id);
                }).sort((a, b) => {
                    const above = (client) => {
                        return client.workspace.id < 0 || client.floating || client.fullscreen ? 0 : 1;
                    };
                    return above(a) - above(b) || a.focusHistoryID - b.focusHistoryID;
                }).map((client) => {
                    return {
                        "x": client.at[0] - info.x,
                        "y": client.at[1] - info.y,
                        "width": client.size[0],
                        "height": client.size[1]
                    };
                });
            }
        }

    }

    Process {
        id: saveProcess

        property string file: ""
        property bool copies: true
        property bool saves: true
        // $1 the frozen screen, $2 the screenshot, $3 the crop (w:h:x:y, empty for the
        // whole screen), $4 the annotated region when there is one, $5 "copy" to put it
        // on the clipboard, $6 "replace" to drop the last one only copied.
        readonly property string script: 'mkdir -p "$(dirname "$2")"
[ -n "$6" ] && find "$(dirname "$2")" -name "*.png" -delete
if [ -n "$4" ]; then mv "$4" "$2" || exit 1
elif [ -n "$3" ]; then ffmpeg -loglevel error -y -i "$1" -vf "crop=$3" "$2" || exit 1
else cp "$1" "$2" || exit 1
fi
rm -f "$1"
[ -z "$5" ] || wl-copy --type image/png < "$2" >/dev/null 2>&1'

        onExited: (code) => {
            screenshot.busy = false;
            if (code === 0)
                screenshot.taken = {
                "screen": screenshot.screenName,
                "file": file,
                "annotated": screenshot.mode === "annotate",
                "copied": copies,
                "saved": saves
            };

        }
    }

    // Follows the recording: the one it starts, or as the shell starts, the one a
    // shell before it left running. It tells what's recorded, then ends with it.
    TiedProcess {
        id: recorder

        program: [screenshot.recorderScript, "follow"]
        running: true
        onExited: {
            if (!screenshot.recording)
                return ;

            screenshot.recording = false;
            posterProcess.duration = Math.round((Date.now() - screenshot.recordingStarted) / 1000);
            posterProcess.poster = Quickshell.env("XDG_RUNTIME_DIR") + "/hyprpunk-recording-" + Date.now() + ".jpg";
            posterProcess.command = ["sh", "-c", posterProcess.script, "sh", screenshot.recordingFile, posterProcess.poster];
            posterProcess.running = true;
        }

        stdout: SplitParser {
            onRead: (line) => {
                const [screen, started, file] = line.split("\t");
                screenshot.recordingScreen = screen;
                screenshot.recordingStarted = Number(started);
                screenshot.recordingFile = file;
                screenshot.recording = true;
            }
        }

    }

    // The recording's first frame, for the island.
    Process {
        id: posterProcess

        property int duration: 0
        property string poster: ""
        // $1 the recording, $2 its first frame.
        readonly property string script: '[ -s "$1" ] || exit 1
rm -f "${XDG_RUNTIME_DIR}"/hyprpunk-recording-*.jpg
ffmpeg -loglevel error -y -i "$1" -frames:v 1 -vf scale=-2:180 "$2"'

        // A recording that failed has nothing to show: screen-recorder.sh says why.
        onExited: (code) => {
            if (code !== 0)
                return ;

            screenshot.taken = {
                "screen": screenshot.recordingScreen,
                "file": poster,
                "video": screenshot.recordingFile,
                "duration": duration
            };
        }
    }

    Process {
        id: cleanup
    }

}
