import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Screenshots: of the screen, of a region (or a window) chosen on the frozen screen, or
// of a region then annotated in place (ScreenshotAnnotator). Saved in ~/Pictures/Screenshots and copied, then
// shown in the island. Recordings too, of the screen or of a region chosen the same
// way, with the system's sound (wf-recorder), until asked again or stopped from the
// island: saved in ~/Videos/Recordings. Asked by the keybinds
// (`qs -c hyprpunk ipc call screenshot <screen|region|annotate|record|recordRegion|
// stop|menu>`) and the screenshot menu, through the shell's state.
Scope {
    id: screenshot

    required property var shellState
    // While a screenshot is taken, chosen or saved: other requests wait for it.
    property bool busy: false
    property string mode: ""
    property string screenName: ""
    // The screen's scale: grim's pixels for the selection's logical ones.
    property real scale: 1
    // The screen's place in the layout, for the recorded region.
    property point origin: Qt.point(0, 0)
    // The whole screen, frozen before the selection is shown over it.
    property string frozenFile: ""
    readonly property string folder: Quickshell.env("HOME") + "/Pictures/Screenshots"
    readonly property string videoFolder: Quickshell.env("HOME") + "/Videos/Recordings"

    function capture(mode, name) {
        const monitor = Hyprland.monitors.values.find((item) => {
            return item.name === name;
        }) || Hyprland.focusedMonitor;
        if (monitor === null)
            return ;

        busy = true;
        screenshot.mode = mode;
        screenName = monitor.name;
        scale = monitor.lastIpcObject.scale || 1;
        origin = Qt.point(monitor.x, monitor.y);
        if (mode === "record") {
            record(null);
            return ;
        }
        frozenFile = Quickshell.env("XDG_RUNTIME_DIR") + "/hyprpunk-screenshot-" + Date.now() + ".png";
        grimProcess.command = ["grim", "-o", screenName, frozenFile];
        grimProcess.running = true;
    }

    // rect: the logical region on the screen, null for the whole screen; with a file,
    // the region already annotated.
    function save(rect) {
        const file = folder + "/Screenshot_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".png";
        const crop = rect === null || rect.file ? "" : [rect.width, rect.height, rect.x, rect.y].map((value) => {
            return Math.round(value * scale);
        }).join(":");
        saveProcess.file = file;
        saveProcess.command = ["sh", "-c", saveProcess.script, "sh", frozenFile, file, crop, rect !== null && rect.file ? rect.file : ""];
        saveProcess.running = true;
    }

    // rect: the logical region on the screen, null for the whole screen.
    function record(rect) {
        const file = videoFolder + "/Recording_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".mp4";
        const area = rect === null ? ["-o", screenName] : ["-g", Math.round(origin.x + rect.x) + "," + Math.round(origin.y + rect.y) + " " + Math.round(rect.width) + "x" + Math.round(rect.height)];
        recorder.file = file;
        recorder.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && shift && exec wf-recorder -y --audio=@DEFAULT_MONITOR@ -F "crop=trunc(iw/2)*2:trunc(ih/2)*2" -x yuv420p "$@"', "sh", file].concat(area).concat(["-f", file]);
        // Once the selection is gone from the screen.
        recordDelay.restart();
    }

    function stopRecording() {
        if (recorder.running)
            recorder.signal(2);

    }

    // The keybinds and the menu ask with a delay, for the menu to fold away first. A
    // recording's request while one runs stops it.
    Connections {
        function onScreenshotRequestsChanged() {
            const request = screenshot.shellState.screenshotRequest;
            if (request.mode === "stop" || (screenshot.shellState.recording && request.mode.startsWith("record"))) {
                screenshot.stopRecording();
                return ;
            }
            if (screenshot.busy)
                return ;

            requestDelay.mode = request.mode;
            requestDelay.screen = request.screen;
            requestDelay.interval = Math.max(1, request.delay);
            requestDelay.restart();
        }

        function onScreenshotSelected(rect) {
            if (!screenshot.busy)
                return ;

            if (rect === null) {
                // Cancelled.
                cleanup.command = ["rm", "-f", screenshot.frozenFile, screenshot.frozenFile + ".annotated.png"];
                cleanup.running = true;
                screenshot.busy = false;
                return ;
            }
            if (screenshot.mode === "record-region") {
                cleanup.command = ["rm", "-f", screenshot.frozenFile];
                cleanup.running = true;
                screenshot.record(rect);
                return ;
            }
            screenshot.save(rect);
        }

        target: screenshot.shellState
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
            screenshot.shellState.recordingScreen = screenshot.screenName;
            screenshot.shellState.recordingStarted = Date.now();
            screenshot.shellState.recording = true;
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
                screenshot.shellState.screenshotSelection = {
                "screen": screenshot.screenName,
                "file": screenshot.frozenFile,
                "scale": screenshot.scale,
                "mode": screenshot.mode,
                "annotatedFile": screenshot.frozenFile + ".annotated.png"
            };
        }
    }

    Process {
        id: saveProcess

        property string file: ""
        // $1 the frozen screen, $2 the screenshot, $3 the crop (w:h:x:y, empty for the
        // whole screen), $4 the annotated region when there is one.
        readonly property string script: 'mkdir -p "$(dirname "$2")"
if [ -n "$4" ]; then mv "$4" "$2" || exit 1
elif [ -n "$3" ]; then ffmpeg -loglevel error -y -i "$1" -vf "crop=$3" "$2" || exit 1
else cp "$1" "$2" || exit 1
fi
rm -f "$1"
wl-copy --type image/png < "$2" >/dev/null 2>&1'

        onExited: (code) => {
            screenshot.busy = false;
            if (code === 0)
                screenshot.shellState.screenshotTaken = {
                "screen": screenshot.screenName,
                "file": file,
                "annotated": screenshot.mode === "annotate"
            };

        }
    }

    // Stopped with SIGINT, for wf-recorder to finish the file.
    Process {
        id: recorder

        property string file: ""

        stderr: StdioCollector {
            id: recorderErrors
        }

        onExited: (code) => {
            const seconds = Math.round((Date.now() - screenshot.shellState.recordingStarted) / 1000);
            screenshot.shellState.recording = false;
            posterProcess.duration = seconds;
            posterProcess.poster = Quickshell.env("XDG_RUNTIME_DIR") + "/hyprpunk-recording-" + Date.now() + ".jpg";
            posterProcess.command = ["sh", "-c", posterProcess.script, "sh", file, posterProcess.poster];
            posterProcess.running = true;
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

        onExited: (code) => {
            if (code === 0) {
                screenshot.shellState.screenshotTaken = {
                    "screen": screenshot.screenName,
                    "file": poster,
                    "video": recorder.file,
                    "duration": duration
                };
                return ;
            }
            const error = recorderErrors.text.trim().split("\n").pop() || "wf-recorder could not record the screen";
            Quickshell.execDetached(["notify-send", "-a", "Screen recording", "Recording failed", error]);
        }
    }

    Process {
        id: cleanup
    }

    IpcHandler {
        function screen(): void {
            screenshot.shellState.requestScreenshot("screen", "", 0);
        }

        function region(): void {
            screenshot.shellState.requestScreenshot("region", "", 0);
        }

        function annotate(): void {
            screenshot.shellState.requestScreenshot("annotate", "", 0);
        }

        // Starts recording the screen, or stops the recording.
        function record(): void {
            screenshot.shellState.requestScreenshot("record", "", 0);
        }

        // Starts recording a region, or stops the recording.
        function recordRegion(): void {
            screenshot.shellState.requestScreenshot("record-region", "", 0);
        }

        function stop(): void {
            screenshot.shellState.requestScreenshot("stop", "", 0);
        }

        // The menu of the screenshots and recordings, in the island.
        function menu(): void {
            screenshot.shellState.requestPanel("screenshot", "toggle", "");
        }

        target: "screenshot"
    }

}
