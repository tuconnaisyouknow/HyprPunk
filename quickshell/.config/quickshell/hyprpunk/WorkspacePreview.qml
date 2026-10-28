import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// A workspace in miniature: the wallpaper, its windows where they sit (floating ones
// on top) and the bar over them. Each window is captured once, when shown, since live
// captures would redraw them all every frame. The bar isn't a window, so it comes in
// as a snapshot (grabToImage).
ClippingRectangle {
    id: preview

    // HyprlandWorkspace, null for none.
    property var workspace: null
    // HyprlandMonitor the workspace is on, for the windows' places and the shape.
    property var monitor: null
    property string wallpaper: ""
    // Picture of the bar, and where it stands on the screen.
    property url barImage
    property rect barRect
    readonly property real screenX: monitor !== null ? monitor.x : 0
    readonly property real screenY: monitor !== null ? monitor.y : 0
    readonly property real screenWidth: monitor !== null ? monitor.width / monitor.scale : 1920
    readonly property real screenHeight: monitor !== null ? monitor.height / monitor.scale : 1080
    readonly property real ratio: width / screenWidth
    readonly property var windows: workspace !== null ? workspace.toplevels.values : []

    implicitHeight: Math.round(width * screenHeight / screenWidth)
    radius: 12
    color: "#11111b"

    Image {
        anchors.fill: parent
        source: preview.wallpaper !== "" ? "file://" + preview.wallpaper : ""
        sourceSize.width: 640
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }

    Repeater {
        model: preview.windows

        ClippingRectangle {
            id: window

            required property var modelData
            readonly property var ipc: modelData.lastIpcObject || {}
            readonly property var at: ipc.at || [0, 0]
            readonly property var size: ipc.size || [0, 0]

            x: (at[0] - preview.screenX) * preview.ratio
            y: (at[1] - preview.screenY) * preview.ratio
            width: size[0] * preview.ratio
            height: size[1] * preview.ratio
            visible: size[0] > 0 && size[1] > 0
            z: ipc.fullscreen ? 2 : ipc.floating ? 1 : 0
            radius: 4
            color: "#313244"
            border.width: 1
            border.color: modelData.activated ? "#cba6f7" : Qt.rgba(180 / 255, 190 / 255, 254 / 255, 0.25)

            // While the capture comes, or when the window cannot be captured.
            IconImage {
                anchors.centerIn: parent
                visible: !capture.hasContent
                implicitSize: Math.min(32, Math.min(parent.width, parent.height) * 0.6)
                source: {
                    const entry = DesktopEntries.heuristicLookup(window.ipc.class || "");
                    return Quickshell.iconPath(entry !== null ? entry.icon : "", "application-x-executable");
                }
            }

            ScreencopyView {
                id: capture

                anchors.fill: parent
                captureSource: window.modelData.wayland
                live: false
            }

        }

    }

    Image {
        x: preview.barRect.x * preview.ratio
        y: preview.barRect.y * preview.ratio
        width: preview.barRect.width * preview.ratio
        height: preview.barRect.height * preview.ratio
        z: 3
        source: preview.barImage
        smooth: true
        mipmap: true
    }

    Rectangle {
        anchors.centerIn: parent
        visible: preview.workspace !== null && preview.windows.length === 0
        width: emptyLabel.implicitWidth + 24
        height: emptyLabel.implicitHeight + 12
        radius: height / 2
        color: Qt.rgba(17 / 255, 17 / 255, 27 / 255, 0.7)

        Text {
            id: emptyLabel

            anchors.centerIn: parent
            text: "Empty"
            color: "#b4befe"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

    }

}
