import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.state

// One screen's island as the lock left it (Lock.relay), in a window of its own over the
// bar. Made under the lock, its first frame goes through where the bar's can't, so the
// island shows as it should the moment the lock goes, while the bar still shows the
// frame it drew under it, without its island. It goes once the bar has drawn again
// (Lock.home). It's the lock's own island spot, cut to the island's shape: nothing of it
// changes as the bar's island comes under it.
Scope {
    id: relay

    required property var modelData
    readonly property var held: Lock.relays[modelData.name] ?? null
    readonly property var bar: ShellState.forScreen(modelData)?.bar ?? null

    LazyLoader {
        active: relay.held !== null && relay.held.shot !== null

        PanelWindow {
            id: window

            readonly property rect island: relay.held?.rect ?? Qt.rect(0, 0, 0, 0)

            screen: relay.modelData
            implicitHeight: Math.ceil(island.y + island.height)
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "hyprpunk-relay"
            color: "transparent"
            // Mapped once it has the frame: under the lock, its first frame is its only one.
            visible: shot.status === Image.Ready

            anchors {
                top: true
                left: true
                right: true
            }

            // The pointer goes through to the bar.
            mask: Region {
            }

            ClippingRectangle {
                x: window.island.x
                y: window.island.y
                width: window.island.width
                height: window.island.height
                radius: height / 2
                color: "transparent"

                Image {
                    id: shot

                    anchors.fill: parent
                    source: relay.held?.shot?.url ?? ""
                    cache: false
                }

                Connections {
                    function onFrameSwapped() {
                        Lock.relayDrawn(relay.modelData.name);
                    }

                    target: shot.Window.window
                    enabled: !(relay.held?.drawn ?? true)
                }

            }

        }

    }

    // The bar draws again only once the lock is gone, its island as the relay's.
    Connections {
        function onFrameSwapped() {
            Lock.home(relay.modelData.name);
        }

        target: relay.bar !== null ? relay.bar.Window.window : null
        enabled: relay.held !== null && !Lock.locked
    }

}
