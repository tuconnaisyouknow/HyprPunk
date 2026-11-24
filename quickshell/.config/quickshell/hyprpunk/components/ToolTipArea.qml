import QtQuick
import Quickshell
import qs.theme

// A name that shows up after half a second over what it's put in: a small pill of the
// shell's glass, a fixed gap from it on one side and centred along that side. It pops
// out of that side and folds back into it.
Item {
    id: area

    required property string text
    // The side it stands on.
    property int edge: Edges.Bottom
    // From the element to the glass.
    readonly property int gap: Metrics.spacing.normal
    // Room around the glass for its pop past its size, which the window would cut.
    readonly property int pad: Metrics.spacing.small
    readonly property bool vertical: edge === Edges.Top || edge === Edges.Bottom
    property bool shown: false

    anchors.fill: parent

    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hovered) {
                showDelay.restart();
            } else {
                showDelay.stop();
                area.shown = false;
            }
        }
    }

    Timer {
        id: showDelay

        interval: 500
        onTriggered: area.shown = true
    }

    PopupWindow {
        // Mapped until it has folded back: Hyprland closes popups at once.
        visible: area.text !== "" && (area.shown || bubble.scale > 0)
        implicitWidth: bubble.width + 2 * area.pad
        implicitHeight: bubble.height + 2 * area.pad
        color: "transparent"
        grabFocus: false

        // The element, stretched out by the gap on its side: the window lies against it,
        // centred along it.
        anchor {
            item: area
            edges: area.edge
            gravity: area.edge
            adjustment: area.vertical ? PopupAdjustment.SlideX : PopupAdjustment.SlideY
            rect.x: area.edge === Edges.Left ? -(area.gap - area.pad) : 0
            rect.y: area.edge === Edges.Top ? -(area.gap - area.pad) : 0
            rect.width: area.width + (area.vertical ? 0 : area.gap - area.pad)
            rect.height: area.height + (area.vertical ? area.gap - area.pad : 0)
        }

        // Scaled rather than faded: the blur behind it follows what's drawn, and would
        // snap off halfway through a fade.
        Item {
            id: bubble

            x: area.pad
            y: area.pad
            width: label.implicitWidth + 2 * Metrics.spacing.large
            height: label.implicitHeight + 2 * Metrics.spacing.small
            scale: area.shown ? 1 : 0
            transformOrigin: area.edge === Edges.Bottom ? Item.Top : area.edge === Edges.Top ? Item.Bottom : area.edge === Edges.Left ? Item.Right : Item.Left

            GlassSurface {
                radius: height / 2
                backgroundColor: Colors.panel
            }

            Text {
                id: label

                anchors.centerIn: parent
                text: area.text
                color: Colors.secondary
                font.family: Metrics.font
                font.pixelSize: Metrics.text.body
            }

            Behavior on scale {
                Anim {
                    token: area.shown ? Motion.pop : Motion.leave.small
                }

            }

        }

        // Click-through: an empty input region.
        mask: Region {
        }

    }

}
