import QtQuick
import Quickshell
import qs.components
import qs.services
import qs.theme

// The track's cover: round in the island, a rounded square in the player, and every
// shape between as the player grows out of the island (PlayerCard). A cover only fades
// in over another cover, on a track change; the first one is simply there, so a copy of
// a cover already shown (the lock's island taking over from the bar's) starts as it is.
// Where you see it, a track change rolls it like a record instead, with a pop: the old
// cover out, the next one in from the side it comes from. Until there's one, a note on a
// plain tile.
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
    // Rolls on a track change: off where nobody sees it, the next cover simply fades in.
    property bool rolls: true
    // A disc turns as it rolls; a square doesn't roll, it slides.
    readonly property bool round: radius >= Math.min(width, height) / 2
    // How far the front picture has faded in over the other, or over the note while the
    // cover it takes the place of had rolled away.
    property real fade: 1
    property bool fadesOverBack: true
    readonly property bool frontShown: front.status === Image.Ready
    // The old cover rolling out as the new one rolls in, from 0 to 1, 1 the side the new
    // one comes from (the next track), -1 the other.
    property real roll: 1
    property int rollDirection: 1
    readonly property bool rolling: roll < 1
    // The picture rolling out, what showed when the track changed.
    property Image leaving: null
    // How far a cover rolls, out of sight with a gap.
    readonly property real rollTravel: width + Metrics.spacing.normal
    // The front picture shows: rolling in, only once it's the new track's.
    readonly property bool shown: frontShown && (!rolling || front.source.toString() === source.toString())

    // The cover loaded (or failed to): it comes to the front.
    function take(image) {
        if (image !== back || image.source.toString() !== source.toString())
            return ;

        const over = frontShown && fades;
        fadesOverBack = shown;
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

    // The track changed: what shows rolls out, the new cover rolls in from the given side
    // and lands upright, rolling without slipping, and the cover pops. The new cover fades
    // in on its way once loaded, over the note until then.
    function rollTo(direction) {
        leaving = fade < 1 && fadesOverBack && back.status === Image.Ready ? back : frontShown ? front : null;
        fadeIn.stop();
        fade = 1;
        rollDirection = direction;
        rollAnimation.restart();
        pop.restart();
    }

    onSourceChanged: load()
    Component.onCompleted: load()

    Rectangle {
        anchors.fill: parent
        // Under the cover's antialiased edge, it would ring it.
        visible: !cover.shown || cover.fade < 1
        radius: cover.radius
        color: Colors.surface1

        Icon {
            anchors.centerIn: parent
            text: "music_note"
            color: Colors.primary
            size: Math.round(Math.min(cover.width, cover.height) * 0.4)
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
        // Always a picture to read, drawn at no opacity when none leaves.
        readonly property var leaving: cover.leaving ?? cover.front
        readonly property vector2d size: Qt.vector2d(width, height)
        readonly property real radius: Math.min(cover.radius, width / 2, height / 2)
        readonly property real frontAlpha: cover.shown ? cover.fade : 0
        readonly property real backAlpha: cover.fadesOverBack && cover.back.status === Image.Ready && cover.fade < 1 ? 1 : 0
        readonly property real leavingAlpha: cover.rolling && cover.leaving !== null && cover.leaving.status === Image.Ready ? 1 : 0
        readonly property vector2d frontCrop: crop(cover.front)
        readonly property vector2d backCrop: crop(cover.back)
        readonly property vector2d leavingCrop: crop(leaving)
        // One turn every time it travels its round edge's length.
        readonly property real frontOffset: cover.rollDirection * cover.rollTravel * (1 - cover.roll)
        readonly property real frontAngle: cover.round ? frontOffset / Math.max(1, width / 2) : 0
        readonly property real leavingOffset: -cover.rollDirection * cover.rollTravel * cover.roll
        readonly property real leavingAngle: cover.round ? leavingOffset / Math.max(1, width / 2) : 0

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

    Connections {
        function onTrackChanged(direction) {
            if (cover.rolls && cover.visible)
                cover.rollTo(direction);

        }

        target: Music
    }

    Anim {
        id: rollAnimation

        target: cover
        property: "roll"
        from: 0
        to: 1
        token: Motion.disc.roll
        onFinished: cover.leaving = null
    }

    SequentialAnimation {
        id: pop

        Anim {
            target: cover
            property: "scale"
            to: Motion.disc.popScale
            token: Motion.disc.popOut
        }

        Anim {
            target: cover
            property: "scale"
            to: 1
            token: Motion.disc.popBack
        }

    }

    Anim {
        id: fadeIn

        target: cover
        property: "fade"
        to: 1
        token: Motion.color.normal
    }

}
