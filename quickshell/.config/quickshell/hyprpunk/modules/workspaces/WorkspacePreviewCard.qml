import QtQuick
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.components
import qs.theme

// A peek at your other workspaces, one at a time, the empty ones as the bare wallpaper. Swipe through them with the arrows,
// a drag or the touchpad, the dots show where you are, and a click takes you there.
ClippingRectangle {
    id: card

    // Their ids, in order.
    required property var workspaceIds
    // The one shown first, 0 for the first.
    property int initialId: 0
    property var monitor: null
    property string wallpaper: ""
    property url barImage
    property rect barRect
    readonly property int currentId: list.currentIndex >= 0 && list.currentIndex < workspaceIds.length ? workspaceIds[list.currentIndex] : 0

    signal workspaceChosen(int id)

    // The keyboard's way through, once the card is opened with its shortcut.
    function step(delta) {
        if (delta < 0)
            list.decrementCurrentIndex();
        else
            list.incrementCurrentIndex();
    }

    function choose() {
        if (currentId !== 0)
            workspaceChosen(currentId);

    }

    radius: Metrics.cardRadius
    color: Colors.crust

    ListView {
        id: list

        anchors.fill: parent
        orientation: ListView.Horizontal
        model: card.workspaceIds
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightMoveDuration: 320
        boundsBehavior: Flickable.StopAtBounds
        // Every preview kept: their windows are captured once, on creation.
        cacheBuffer: width * 10
        clip: true
        Component.onCompleted: {
            currentIndex = Math.max(0, card.workspaceIds.indexOf(card.initialId));
            positionViewAtIndex(currentIndex, ListView.Beginning);
        }

        delegate: WorkspacePreview {
            required property var modelData

            width: list.width
            height: list.height
            radius: 0
            // Null while it's empty and nobody's on it.
            workspace: Hyprland.workspaces.values.find((workspace) => {
                return workspace.id === modelData;
            }) || null
            monitor: card.monitor
            wallpaper: card.wallpaper
            barImage: card.barImage
            barRect: card.barRect

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: card.workspaceChosen(modelData)
            }

        }

    }

    SwipeArrow {
        anchors.left: parent.left
        anchors.leftMargin: Metrics.spacing.normal
        icon: "keyboard_arrow_left"
        shown: list.currentIndex > 0
        onTriggered: list.decrementCurrentIndex()
    }

    SwipeArrow {
        anchors.right: parent.right
        anchors.rightMargin: Metrics.spacing.normal
        icon: "keyboard_arrow_right"
        shown: list.currentIndex < list.count - 1
        onTriggered: list.incrementCurrentIndex()
    }

    // Where the preview stands among them.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Metrics.spacing.normal
        visible: list.count > 1
        width: dots.implicitWidth + 16
        height: 16
        radius: height / 2
        color: Colors.alpha(Colors.crust, 0.65)

        Row {
            id: dots

            anchors.centerIn: parent
            spacing: Metrics.spacing.normal

            Repeater {
                model: list.count

                Rectangle {
                    required property int index

                    anchors.verticalCenter: parent.verticalCenter
                    width: index === list.currentIndex ? 14 : 6
                    height: 6
                    radius: 3
                    color: index === list.currentIndex ? Colors.primary : Colors.secondary

                    Behavior on width {
                        Anim {
                            token: Motion.resize.normal
                        }

                    }

                    ColorFade on color {
                        token: Motion.color.normal
                    }

                }

            }

        }

    }

    component SwipeArrow: Rectangle {
        id: arrow

        required property string icon
        required property bool shown

        signal triggered()

        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 30
        radius: height / 2
        color: Colors.alpha(Colors.crust, arrowMouse.containsMouse ? 0.85 : 0.65)
        opacity: shown ? 1 : 0
        visible: opacity > 0
        scale: arrowMouse.pressed ? 0.88 : 1

        Icon {
            anchors.centerIn: parent
            text: arrow.icon
            color: Colors.primary
            size: Metrics.text.title
        }

        // A MouseArea keeps the click to itself; with a TapHandler the preview
        // underneath would get it too and jump to that workspace.
        MouseArea {
            id: arrowMouse

            anchors.fill: parent
            enabled: arrow.shown
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: arrow.triggered()
        }

        Behavior on opacity {
            Anim {
                token: Motion.color.small
            }

        }

        Behavior on scale {
            Anim {
                token: Motion.pop
            }

        }

        ColorFade on color {
            token: Motion.color.small
        }

    }

}
