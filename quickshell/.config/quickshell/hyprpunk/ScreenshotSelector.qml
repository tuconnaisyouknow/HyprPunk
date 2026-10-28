import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Picking what to capture, over the frozen screen. Drag out a region, or click a
// window (it lights up as you hover), or click elsewhere for the whole screen.
// Escape or a right click cancels. Everything else is dimmed and the size shows
// underneath. When annotating, the region stays put under the annotator.
PanelWindow {
    id: selector

    required property var shellState
    // Fixed once: the window's own screen property shifts while it maps.
    required property string screenName
    readonly property var request: shellState.screenshotSelection
    readonly property bool active: request !== null && request.screen === screenName
    // The visible windows ({x, y, width, height} on this screen), the top one first.
    property var windows: []
    property point pressPoint: Qt.point(0, 0)
    property bool dragging: false
    property var dragRect: null
    property var hoveredWindow: null
    // The region being annotated, null while choosing.
    property var annotatedRegion: null
    // The region outlined: the one annotated, dragged, or the window under the pointer.
    readonly property var focusRect: annotatedRegion !== null ? annotatedRegion : dragging ? dragRect : hoveredWindow

    function finish(rect) {
        if (rect !== null && request.mode === "annotate" && annotatedRegion === null) {
            annotatedRegion = rect;
            return ;
        }
        shellState.screenshotSelection = null;
        shellState.screenshotSelected(rect);
    }

    function windowAt(x, y) {
        return windows.find((item) => {
            return x >= item.x && x < item.x + item.width && y >= item.y && y < item.y + item.height;
        }) || null;
    }

    visible: active
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hyprpunk-screenshot"
    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    onActiveChanged: {
        dragging = false;
        dragRect = null;
        hoveredWindow = null;
        annotatedRegion = null;
        windows = [];
        if (active)
            windowsProcess.running = true;

    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // The screen as it was: what is chosen is cut from it.
    Image {
        anchors.fill: parent
        source: selector.active ? "file://" + selector.request.file : ""
        cache: false
        smooth: true
    }

    // The dim around the region (everything before one is outlined).
    Item {
        id: dim

        readonly property color shade: Qt.rgba(17 / 255, 17 / 255, 27 / 255, 0.55)
        readonly property var rect: selector.focusRect !== null ? selector.focusRect : {
            "x": 0,
            "y": 0,
            "width": 0,
            "height": 0
        }

        anchors.fill: parent

        Rectangle {
            width: parent.width
            height: selector.focusRect !== null ? dim.rect.y : parent.height
            color: dim.shade
        }

        Rectangle {
            visible: selector.focusRect !== null
            y: dim.rect.y + dim.rect.height
            width: parent.width
            height: parent.height - y
            color: dim.shade
        }

        Rectangle {
            visible: selector.focusRect !== null
            y: dim.rect.y
            width: dim.rect.x
            height: dim.rect.height
            color: dim.shade
        }

        Rectangle {
            visible: selector.focusRect !== null
            x: dim.rect.x + dim.rect.width
            y: dim.rect.y
            width: parent.width - x
            height: dim.rect.height
            color: dim.shade
        }

        // Around the region, not over it.
        Rectangle {
            visible: selector.focusRect !== null
            x: dim.rect.x - border.width
            y: dim.rect.y - border.width
            width: dim.rect.width + 2 * border.width
            height: dim.rect.height + 2 * border.width
            radius: 4
            color: "transparent"
            border.width: 2
            border.color: "#cba6f7"
        }

        // The region's size, under it (over it at the bottom of the screen).
        Rectangle {
            visible: selector.active && selector.annotatedRegion === null && selector.focusRect !== null && dim.rect.width > 0
            x: Math.max(8, Math.min(parent.width - width - 8, dim.rect.x + dim.rect.width / 2 - width / 2))
            y: dim.rect.y + dim.rect.height + 10 + height < parent.height ? dim.rect.y + dim.rect.height + 10 : dim.rect.y + dim.rect.height - height - 10
            width: sizeLabel.implicitWidth + 20
            height: 26
            radius: 13
            color: Qt.rgba(30 / 255, 30 / 255, 46 / 255, 0.9)

            Text {
                id: sizeLabel

                anchors.centerIn: parent
                readonly property real scale: selector.request !== null ? selector.request.scale : 1

                text: Math.round(dim.rect.width * scale) + " × " + Math.round(dim.rect.height * scale)
                color: "#cba6f7"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.weight: Font.Bold
            }

        }

    }

    // How to choose, at the bottom of the screen.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        width: hint.implicitWidth + 32
        height: 34
        radius: 17
        color: Qt.rgba(30 / 255, 30 / 255, 46 / 255, 0.9)
        opacity: selector.dragging || selector.annotatedRegion !== null ? 0 : 1

        GlassSurface {
            radius: parent.radius
            tinted: false
        }

        Text {
            id: hint

            anchors.centerIn: parent
            text: "Drag a region · Click a window · Esc to cancel"
            color: "#b4befe"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 160
            }

        }

    }

    MouseArea {
        anchors.fill: parent
        enabled: selector.annotatedRegion === null
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.CrossCursor
        focus: true
        Keys.onEscapePressed: selector.finish(null)
        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                selector.finish(null);
                return ;
            }
            selector.pressPoint = Qt.point(mouse.x, mouse.y);
            selector.dragging = false;
        }
        onPositionChanged: (mouse) => {
            if (!pressed || mouse.buttons !== Qt.LeftButton) {
                selector.hoveredWindow = selector.windowAt(mouse.x, mouse.y);
                return ;
            }
            const x = Math.max(0, Math.min(width, mouse.x));
            const y = Math.max(0, Math.min(height, mouse.y));
            if (!selector.dragging && Math.abs(x - selector.pressPoint.x) + Math.abs(y - selector.pressPoint.y) < 6)
                return ;

            selector.dragging = true;
            selector.dragRect = {
                "x": Math.min(x, selector.pressPoint.x),
                "y": Math.min(y, selector.pressPoint.y),
                "width": Math.abs(x - selector.pressPoint.x),
                "height": Math.abs(y - selector.pressPoint.y)
            };
        }
        onReleased: (mouse) => {
            if (mouse.button !== Qt.LeftButton)
                return ;

            if (selector.dragging)
                selector.finish(selector.dragRect.width >= 2 && selector.dragRect.height >= 2 ? selector.dragRect : null);
            else
                selector.finish(selector.windowAt(mouse.x, mouse.y) || {
                "x": 0,
                "y": 0,
                "width": width,
                "height": height
            });
        }
    }

    Loader {
        anchors.fill: parent
        active: selector.annotatedRegion !== null

        sourceComponent: ScreenshotAnnotator {
            region: selector.annotatedRegion
            frozenFile: selector.request.file
            scale: selector.request.scale
            outputFile: selector.request.annotatedFile
            onFinished: (file) => {
                const region = selector.annotatedRegion;
                selector.shellState.screenshotSelection = null;
                selector.shellState.screenshotSelected({
                    "x": region.x,
                    "y": region.y,
                    "width": region.width,
                    "height": region.height,
                    "file": file
                });
            }
            onCancelled: selector.finish(null)
        }

    }

    // The windows visible on this screen (its workspace and any open special one),
    // topmost first: fullscreen and floating ones, then by last focus.
    Process {
        id: windowsProcess

        command: ["hyprctl", "-j", "clients"]

        stdout: StdioCollector {
            onStreamFinished: {
                const monitor = Hyprland.monitorFor(selector.screen);
                if (monitor === null)
                    return ;

                const info = monitor.lastIpcObject;
                const workspaces = [info.activeWorkspace ? info.activeWorkspace.id : -1, info.specialWorkspace ? info.specialWorkspace.id : 0];
                let clients;
                try {
                    clients = JSON.parse(text);
                } catch (error) {
                    return ;
                }
                selector.windows = clients.filter((client) => {
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

}
