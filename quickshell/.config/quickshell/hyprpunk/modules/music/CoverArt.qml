import QtQuick
import Quickshell
import qs.components
import qs.theme

// The track's cover: round in the island, a rounded square in the player, and every
// shape between as the player grows out of the island (PlayerCard). A cover only fades
// in over another cover, on a track change; the first one is simply there, so a copy of
// a cover already shown (the lock's island taking over from the bar's) starts as it is.
// Until there's one, a note on a plain tile.
Item {
    id: cover

    property url source
    property real radius: width / 2
    // Decoded at this size whatever the size shown: about twice the size it's shown at, so
    // it stays sharp on a doubled screen and smooth when drawn smaller. The island's
    // covers share one picture, the player's and the one flying into it another.
    property int decodeSize: 128
    // The two pictures take turns: the front one shows the latest cover, the other loads
    // the next one, and is the old one under the new while it fades in.
    property bool aFront: true
    readonly property Image front: aFront ? artA : artB
    readonly property Image back: aFront ? artB : artA
    // Off, the next cover takes its place at once: it comes in with a move of its own.
    property bool fades: true
    // How far the front picture has faded in over the other.
    property real fade: 1
    readonly property bool frontShown: front.status === Image.Ready

    // The cover loaded (or failed to): it comes to the front.
    function take(image) {
        if (image !== back || image.source.toString() !== source.toString())
            return ;

        const over = frontShown && fades;
        aFront = !aFront;
        fade = over ? 0 : 1;
        if (over)
            fadeIn.restart();

    }

    function load() {
        if (source.toString() === front.source.toString())
            return ;

        back.source = source;
        // Already loaded, as when the same cover comes back: no status change to wait for.
        if (back.status === Image.Ready || back.status === Image.Error)
            take(back);

    }

    onSourceChanged: load()
    Component.onCompleted: load()

    Rectangle {
        anchors.fill: parent
        // Under the cover's antialiased edge, it would ring it.
        visible: !cover.frontShown || cover.fade < 1
        radius: cover.radius
        color: Colors.surface1

        Text {
            anchors.centerIn: parent
            text: "󰎆"
            color: Colors.primary
            font.family: Metrics.font
            font.pixelSize: Math.round(Math.min(cover.width, cover.height) * 0.4)
        }

    }

    Image {
        id: artA

        visible: false
        asynchronous: true
        cache: true
        sourceSize.width: cover.decodeSize
        sourceSize.height: cover.decodeSize
        onStatusChanged: {
            if (status === Image.Ready || status === Image.Error)
                cover.take(artA);

        }
    }

    Image {
        id: artB

        visible: false
        asynchronous: true
        cache: true
        sourceSize.width: cover.decodeSize
        sourceSize.height: cover.decodeSize
        onStatusChanged: {
            if (status === Image.Ready || status === Image.Error)
                cover.take(artB);

        }
    }

    // Rounded in the shader, from the pictures themselves: a layer and a mask took a
    // frame to show and cost two offscreen passes.
    ShaderEffect {
        readonly property var front: cover.front
        readonly property var back: cover.back
        readonly property vector2d size: Qt.vector2d(width, height)
        readonly property real radius: Math.min(cover.radius, width / 2, height / 2)
        readonly property real frontAlpha: cover.frontShown ? cover.fade : 0
        readonly property real backAlpha: cover.back.status === Image.Ready && cover.fade < 1 ? 1 : 0
        readonly property vector2d frontCrop: crop(cover.front)
        readonly property vector2d backCrop: crop(cover.back)

        // The share of a picture its middle square takes, on each axis.
        function crop(image) {
            const side = Math.min(image.implicitWidth, image.implicitHeight);
            return Qt.vector2d(side / Math.max(1, image.implicitWidth), side / Math.max(1, image.implicitHeight));
        }

        anchors.fill: parent
        // The pictures are read where they sit in the atlas (qt_SubRect_), not copied out.
        supportsAtlasTextures: true
        fragmentShader: Qt.resolvedUrl(Quickshell.shellPath("shaders/cover.frag.qsb"))
    }

    Anim {
        id: fadeIn

        target: cover
        property: "fade"
        to: 1
        token: Motion.color.normal
    }

}
