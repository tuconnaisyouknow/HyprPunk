import QtQuick
import Quickshell
import Quickshell.Wayland

// The music wave at the bottom of the desktop, under the windows, run as its own small
// Quickshell (shell.qml starts it with `qs -n -p …/VisualizerShell.qml`): in the shell,
// it would share its thread with the bar and drop a frame every few dozen. It settles
// into the floor while the lock screen is on its way or up (it follows the levels then),
// telling it when it lies flat, and the lock screen's own wave rises in its place
// (LockSurface.qml). Turned off in the settings (MusicSettings), neither shows and cava
// doesn't run.
ShellRoot {
    CavaLevels {
        id: cava

        needed: MusicSettings.wave
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
            visible: MusicSettings.wave && (cava.playing || wave.opacity > 0)
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "hyprpunk-visualizer"

            anchors.bottom: true

            // Clicks go through to the desktop
            mask: Region {
            }

            VisualizerWave {
                id: wave

                // How far up it stands, moving steadily. Eased in and out, the same both
                // ways like the lock screen's: it lands in the floor rather than hitting it,
                // which looked cut off just before the screen froze.
                property real raised: 1

                anchors.fill: parent
                music: cava
                presence: raised < 0.5 ? 4 * Math.pow(raised, 3) : 1 - Math.pow(2 - 2 * raised, 3) / 2

                // Moved by the frames it draws rather than by the clock. Under the lock its
                // window gets no frames, so the rise plays from its start once it shows,
                // not mostly over. The first frame back comes long after the last one: no
                // frame moves it further than one at 30 fps.
                FrameAnimation {
                    readonly property real target: cava.followed ? 0 : 1

                    // Runs on while the lock's coming: the frame after the one that drew it
                    // flat tells the lock it can take its snapshot. Under the lock, no frames
                    // come and nothing more is told.
                    running: cava.followed || wave.raised !== target
                    onTriggered: {
                        if (cava.followed && wave.raised === 0) {
                            cava.tell("flat");
                            return ;
                        }
                        const step = Math.min(frameTime, 1 / 30) * 1000 / Theme.waveSettle;
                        wave.raised = target > wave.raised ? Math.min(target, wave.raised + step) : Math.max(target, wave.raised - step);
                    }
                }

            }

        }

    }

}
