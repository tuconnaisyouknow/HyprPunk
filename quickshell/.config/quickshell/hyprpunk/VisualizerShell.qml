import QtQuick
import Quickshell
import Quickshell.Wayland

// The music wave at the bottom of the desktop, under the windows, run as its own small
// Quickshell (shell.qml starts it with `qs -n -p …/VisualizerShell.qml`). Apart from the
// shell, it keeps moving while the shell stalls building the lock screen.
ShellRoot {
    CavaLevels {
        id: cava
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData

            screen: modelData
            // The lock screen draws its own wave at the same place (LockSurface.qml)
            implicitWidth: Math.round(modelData.width * 0.5)
            implicitHeight: 110
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            // Kept mapped while it fades out
            visible: cava.playing || wave.opacity > 0
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "hyprpunk-visualizer"

            anchors.bottom: true

            // Clicks go through to the desktop
            mask: Region {
            }

            VisualizerWave {
                id: wave

                anchors.fill: parent
                music: cava
            }

        }

    }

}
