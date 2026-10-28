import QtQuick
import Quickshell.Widgets

// A looping carousel of pictures, for the wallpapers and the SDDM themes.
// The middle one is bigger with a mauve ring, the one in use gets a check mark.
// Scroll to turn it, click a neighbour to bring it to the middle, click the middle
// one to pick it (activated()).
Item {
    id: carousel

    // [{ "id": string, "image": path or "" for a placeholder with the id }].
    property var items: []
    property string currentId: ""
    // Where the carousel is heading. It keeps counting past the end so it can loop
    // (the middle item is items[wrap(target)]), and position animates after it.
    property int target: 0
    property real position: 0
    property bool animatePosition: false
    readonly property int count: items.length
    readonly property int centreIndex: count > 0 ? wrap(target) : -1
    readonly property string centreId: centreIndex >= 0 ? items[centreIndex].id : ""
    readonly property int thumbWidth: 320
    readonly property int thumbHeight: 180
    // Distance from the centre to the first and the second neighbour.
    readonly property real firstStep: 284
    readonly property real secondStep: 150
    property real wheelDelta: 0

    signal activated()

    function wrap(index) {
        return ((index % count) + count) % count;
    }

    function step(delta) {
        if (count > 1)
            target += delta;

    }

    // Puts an item in the centre without turning the carousel to it.
    function centreOn(id) {
        const index = items.findIndex((item) => {
            return item.id === id;
        });
        animatePosition = false;
        target = Math.max(0, index);
        position = target;
        animatePosition = true;
    }

    // Replaces the items, keeping the same one in the centre (or the one in use).
    function setItems(list) {
        if (JSON.stringify(list) === JSON.stringify(items))
            return ;

        const centre = centreId;
        items = list;
        centreOn(list.some((item) => {
            return item.id === centre;
        }) ? centre : currentId);
    }

    implicitHeight: thumbHeight
    onTargetChanged: position = target

    Behavior on position {
        enabled: carousel.animatePosition

        NumberAnimation {
            duration: 340
            easing.type: Easing.OutCubic
        }

    }

    WheelHandler {
        onWheel: (event) => {
            carousel.wheelDelta += event.angleDelta.y || event.angleDelta.x;
            while (Math.abs(carousel.wheelDelta) >= 120) {
                carousel.step(carousel.wheelDelta > 0 ? -1 : 1);
                carousel.wheelDelta -= carousel.wheelDelta > 0 ? 120 : -120;
            }
        }
    }

    Repeater {
        model: carousel.items

        Item {
            id: slide

            required property var modelData
            required property int index
            // Signed distance to the centre in slides, looping around (-count/2..count/2).
            readonly property real offset: {
                const count = carousel.count;
                return (((index - carousel.position) % count) + count + count / 2) % count - count / 2;
            }
            readonly property real distance: Math.abs(offset)

            x: carousel.width / 2 - width / 2 + Math.sign(offset) * (distance <= 1 ? distance * carousel.firstStep : carousel.firstStep + (distance - 1) * carousel.secondStep)
            width: carousel.thumbWidth
            height: carousel.thumbHeight
            scale: distance <= 1 ? 1 - 0.3 * distance : Math.max(0.4, 0.7 - 0.2 * (distance - 1))
            opacity: distance <= 1 ? 1 - 0.3 * distance : Math.max(0, 0.7 - 0.4 * (distance - 1))
            visible: opacity > 0
            z: 10 - distance

            ClippingRectangle {
                anchors.fill: parent
                radius: 12
                color: Theme.crust

                // The whole image, never cropped.
                Image {
                    anchors.fill: parent
                    visible: slide.modelData.image !== ""
                    source: slide.modelData.image !== "" ? "file://" + slide.modelData.image : ""
                    sourceSize.width: 640
                    sourceSize.height: 360
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    mipmap: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: slide.modelData.image === ""
                    text: slide.modelData.id
                    color: Theme.mauve
                    font.family: Theme.font
                    font.pixelSize: 16
                    font.weight: Font.Bold
                }

                GlassSurface {
                    z: 1
                    radius: 12
                    tinted: false
                }

            }

            // Mauve ring on the item in the centre.
            Rectangle {
                anchors.fill: parent
                radius: 12
                color: "transparent"
                border.width: 2
                border.color: Theme.mauve
                opacity: Math.max(0, 1 - slide.distance * 2)
            }

            // Badge on the item in use.
            Rectangle {
                visible: slide.modelData.id === carousel.currentId
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 10
                width: 28
                height: 28
                radius: 14
                color: "transparent"

                GlassSurface {
                    radius: parent.radius
                    backgroundColor: Theme.alpha(Theme.mauve, 0.9)
                }

                Text {
                    anchors.centerIn: parent
                    text: ""
                    color: Theme.base
                    font.family: Theme.font
                    font.pixelSize: 13
                }

            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            // The centre is activated, a neighbour turns the carousel to it.
            TapHandler {
                onTapped: {
                    if (slide.distance < 0.5)
                        carousel.activated();
                    else
                        carousel.step(Math.round(slide.offset));
                }
            }

        }

    }

}
