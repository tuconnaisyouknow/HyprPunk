import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.config
import qs.modules.bar
import qs.services
import qs.theme

// The Spotify track's cover as a spinning record, on the right of the bar. It spins
// while the music plays, unless the settings keep it still or leave the cover out
// (MusicSettings), and rolls out for the next track. A click grows the player out of it,
// the cover gliding to its place in the card.
Rectangle {
    id: musicPill

    // Spotify's player, null while it isn't running.
    required property var player
    // Where the screen draws its cards (ScreenShell), the player among them.
    required property Item cardLayer
    // Its screen's state, where the player answers its shortcut.
    required property var screenState
    readonly property alias popup: musicPopup
    // Under the pointer, or its spot in the player, and how far that draws it past its
    // place (like Pill).
    property bool spotHovered: false
    readonly property bool lit: pillHover.hovered || spotHovered
    readonly property real spreadX: pillZoom.spreadX
    readonly property real spreadY: pillZoom.spreadY

    // Angle of the front disc: 0 = upright, where every track starts.
    property real spin: 0
    // 0 -> 1 after a new track or a restart: the disc only starts spinning
    // once it has settled upright.
    property real spinFactor: 1
    // While the player is open, the disc pauses and picks up from the same angle
    // afterwards, without jumping.
    readonly property bool displayFrozen: musicPopup.mapped
    // Kept upright otherwise: a disc turning redraws the whole screen at every frame.
    readonly property bool spins: MusicSettings.cover === "spinning"
    readonly property real frontAngle: spins ? spin + rewind : 0
    // Degrees per second: speeds up and slows down like a turntable.
    property real spinSpeed: spins && musicPill.player !== null && musicPill.player.isPlaying ? 45 : 0
    // Angle of the disc rolling out, frozen when the track changed.
    property real outgoingSpin: 0
    // 0 -> 1 while the discs swap, direction 1 = next track, -1 = previous.
    property real swipe: 1
    property int swipeDirection: 1
    property bool frontIsA: true
    // Extra angle of the front disc while it rewinds (track restarted).
    property real rewind: 0

    // A little pop on play, pause and track changes. Not while the player is
    // open though: the pill sits under the card and would poke out of it.
    function pulse() {
        if (displayFrozen)
            return ;

        pulseAnimation.restart();
    }

    // Spotify's 64px cover rather than the 640px one: shown at 34px anyway, and much quicker to load.
    function pillArt() {
        return musicPill.player.trackArtUrl.replace("/ab67616d0000b273", "/ab67616d00004851");
    }

    function frontDisc() {
        return frontIsA ? discA : discB;
    }

    // The front disc comes in from one side, the other one leaves on the opposite side.
    function discX(front) {
        const travel = discWindow.width + 8;
        return front ? swipeDirection * travel * (1 - swipe) : -swipeDirection * travel * swipe;
    }

    // Rolls without slipping: one turn every 2πr travelled.
    function discRotation(front, x) {
        return (front ? frontAngle : outgoingSpin) + x * 180 / (Math.PI * discWindow.width / 2);
    }

    // The track started again (Music.restarted): the disc turns back upright.
    function rewindDisc() {
        if (displayFrozen) {
            // Hidden under the player's cover: straight back to upright.
            rewindAnimation.stop();
            spin = 0;
            rewind = 0;
        } else {
            // At least one full turn, so it shows.
            spinRamp.stop();
            spinFactor = 0;
            rewindAnimation.to = -(spin + (spin < 120 ? 360 : 0));
            rewindAnimation.restart();
        }
        pulse();
    }

    function resetDiscs() {
        discSwipe.stop();
        rewindAnimation.stop();
        swipe = 1;
        spin = 0;
        rewind = 0;
        spinFactor = 1;
        frontDisc().source = musicPill.player !== null ? pillArt() : "";
    }

    // The track changed (Music.trackChanged): the old disc rolls out, the new one in,
    // 1 from the right, -1 from the left.
    function rollTo(direction) {
        discSwipe.stop();
        // The new disc waits outside the hole, the old one stays in place.
        swipe = 0;
        // The old disc keeps its angle, the new one rolls in and lands upright.
        outgoingSpin = frontAngle;
        rewindAnimation.stop();
        rewind = 0;
        spin = 0;
        spinRamp.stop();
        spinFactor = 0;
        swipeDirection = direction;
        const previousArt = frontDisc().source;
        frontIsA = !frontIsA;
        const art = pillArt();
        // Spotify sometimes sends the new art a moment later (onTrackArtUrlChanged).
        const artPending = art === "" || art === previousArt.toString();
        frontDisc().source = artPending ? "" : art;
        // No waiting for the cover: it fades in on the disc once loaded.
        pulse();
        discSwipe.restart();
    }

    onDisplayFrozenChanged: {
        // Starts again gently once the player is folded back.
        if (!displayFrozen) {
            spinFactor = 0;
            spinRamp.restart();
        } else {
            // A pulse still running would grow out from under the cover.
            pulseAnimation.stop();
            scale = 1;
        }
    }
    Component.onCompleted: Qt.callLater(resetDiscs)
    // Deferred: while the bar is being built, the animations don't exist yet.
    onPlayerChanged: Qt.callLater(resetDiscs)
    implicitWidth: Metrics.pillHeight
    implicitHeight: Metrics.pillHeight
    radius: height / 2
    transform: PillZoom {
        id: pillZoom

        pill: musicPill
        active: musicPill.lit
        pressed: pillTap.pressed
    }
    // The pill's background is painted by the hole and the ring below; a fill here
    // would show twice under the ring.
    color: "transparent"

    // Shows while a disc rolls in or out of the hole.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius: width / 2
        color: Colors.panel
    }

    Behavior on spinSpeed {
        Anim {
            token: Motion.record.speed
        }

    }

    // Two discs, so on a track change the old one can roll out while the new one
    // rolls in, forwards or backwards.
    Item {
        id: discWindow

        anchors.fill: parent
        // Slightly larger than the hole: its edge is drawn by the ring above.
        anchors.margins: Metrics.spacing.hairline

        CoverDisc {
            id: discA

            bare: MusicSettings.cover === "off"

            width: parent.width
            height: parent.height
            x: musicPill.discX(musicPill.frontIsA)
            rotation: musicPill.discRotation(musicPill.frontIsA, x)
            visible: musicPill.frontIsA || musicPill.swipe < 1
        }

        CoverDisc {
            id: discB

            bare: MusicSettings.cover === "off"

            width: parent.width
            height: parent.height
            x: musicPill.discX(!musicPill.frontIsA)
            rotation: musicPill.discRotation(!musicPill.frontIsA, x)
            visible: !musicPill.frontIsA || musicPill.swipe < 1
        }

    }

    Rectangle {
        id: discWindowMask

        anchors.fill: discWindow
        radius: width / 2
        visible: false
        layer.enabled: true
    }

    // A layer on discWindow was not redrawn when a disc rotated.
    ShaderEffectSource {
        id: discWindowSource

        sourceItem: discWindow
        hideSource: true
        live: true
        visible: false
    }

    MultiEffect {
        anchors.fill: discWindow
        source: discWindowSource
        maskEnabled: true
        maskSource: discWindowMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }

    // The pill around the hole. The masks leave a jagged edge (worse while spinning),
    // so the ring covers it; the hole stays 32px wide.
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: 3
        border.color: Colors.panel
        antialiasing: true
    }

    // Over the ring, like the other pills' rim.
    GlassSurface {
        z: 1
        radius: musicPill.radius
        tinted: false
        hovered: musicPill.lit
    }

    // Spins while playing, keeps its angle while paused.
    FrameAnimation {
        running: musicPill.spinSpeed > 0 && !musicPill.displayFrozen
        onTriggered: musicPill.spin = (musicPill.spin + musicPill.spinSpeed * musicPill.spinFactor * frameTime) % 360
    }

    SequentialAnimation {
        id: pulseAnimation

        Anim {
            target: musicPill
            property: "scale"
            to: Motion.record.popScale
            token: Motion.record.popOut
        }

        Anim {
            target: musicPill
            property: "scale"
            to: 1
            token: Motion.record.popBack
            easing.overshoot: Motion.record.popOvershoot
        }

    }

    // One quick turn backwards, like a record pulled back by hand.
    Anim {
        id: rewindAnimation

        target: musicPill
        property: "rewind"
        from: 0
        token: Motion.record.rewind
        onFinished: {
            musicPill.spin = 0;
            musicPill.rewind = 0;
            spinRamp.restart();
        }
    }

    Connections {
        function onTrackChanged(direction) {
            musicPill.rollTo(direction);
        }

        function onRestarted() {
            musicPill.rewindDisc();
        }

        target: Music
    }

    // Starts spinning gently, like a turntable getting up to speed.
    Anim {
        id: spinRamp

        target: musicPill
        property: "spinFactor"
        to: 1
        token: Motion.record.spinUp
    }

    Anim {
        id: discSwipe

        target: musicPill
        property: "swipe"
        from: 0
        to: 1
        token: Motion.record.roll
        onFinished: spinRamp.restart()
    }

    Connections {
        function onIsPlayingChanged() {
            musicPill.pulse();
        }

        function onTrackArtUrlChanged() {
            // The cover sometimes arrives after the track change, and sometimes just before,
            // while the old disc is still in front (rollTo handles that case).
            if (Music.playerTrack() === Music.currentTrack)
                musicPill.frontDisc().source = musicPill.pillArt();

        }

        target: musicPill.player
    }

    // Answers the pointer like the other pills you can click.
    HoverHandler {
        id: pillHover
    }

    TapHandler {
        id: pillTap

        cursorShape: Qt.PointingHandCursor
        // Pressed as long as you like, like the other pills.
        longPressThreshold: 0
        onTapped: musicPopup.togglePinned()
    }

    // Opens like the calendar: the card grows out of the cover pill and
    // the cover glides to its place in the player.
    PillPopup {
        id: musicPopup

        // The cover settles during the first 70% so it never crosses the fading-in title.
        readonly property real coverProgress: Math.min(1, progress / 0.7)
        // The disc's angle (-180..180): the cover leaves at that angle and straightens up
        // as the player opens, then turns back to it when folding away.
        readonly property real discAngle: ((musicPill.frontAngle % 360) + 540) % 360 - 180

        cardLayer: musicPill.cardLayer
        pill: musicPill
        pillName: "player"
        panelName: "player"
        screenState: musicPill.screenState
        // No player to show while Spotify isn't running.
        requestable: musicPill.player !== null
        align: Qt.AlignRight
        available: musicPill.player !== null
        implicitWidth: 380
        // Tall enough for the lyrics: the card grows and shrinks inside it.
        implicitHeight: musicPlayerCard.fullHeight
        cardHeight: musicPlayerCard.height

        MediaPlayerCard {
            id: musicPlayerCard

            active: musicPopup.mapped
            anchors.top: parent.top
            anchors.right: parent.right
            width: musicPopup.width
            opacity: Math.max(0, (musicPopup.progress - 0.7) / 0.3)
            player: musicPill.player
            glassVisible: false
            coverVisible: false
        }

        // From the pill's little round cover to the player's artwork. Nothing spins: the disc
        // grows at its frozen angle and the square cover fades in over it (and back out).
        Item {
            readonly property real size: musicPopup.lerp(32 * pillZoom.yScale, musicPlayerCard.artSize)
            readonly property real squareOpacity: Math.min(1, Math.max(0, (musicPopup.coverProgress - 0.4) / 0.5))

            anchors.top: parent.top
            anchors.left: parent.left
            // From the zoomed pill's cover, which sits a little above the card's own place.
            anchors.topMargin: musicPopup.lerp(3 * pillZoom.yScale - musicPill.spreadY, musicPlayerCard.artMargin)
            // Slides from the right edge to the left one of the growing card, so it is never cut.
            anchors.leftMargin: (1 - musicPopup.coverProgress) * (musicPopup.card.width - 3 * pillZoom.xScale - size) + musicPopup.coverProgress * musicPlayerCard.artMargin
            width: size
            height: size

            CoverDisc {
                anchors.fill: parent
                visible: parent.squareOpacity < 1
                rotation: musicPopup.discAngle
                antialiasing: true
                // Same art as the pill's disc, so both match when it folds back.
                source: musicPill.player !== null ? musicPill.pillArt() : ""
                bare: MusicSettings.cover === "off"
                decodeSize: 64
            }

            ClippingRectangle {
                anchors.fill: parent
                opacity: parent.squareOpacity
                visible: opacity > 0
                radius: musicPlayerCard.artRadius
                color: Colors.surface1

                Image {
                    id: musicPopupCover

                    anchors.fill: parent
                    source: musicPill.player !== null ? musicPill.player.trackArtUrl : ""
                    asynchronous: true
                    cache: true
                    fillMode: Image.PreserveAspectCrop
                    // Its size changes while the player opens: smooth downscaling at any size.
                    mipmap: true
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: musicPopupCover.status !== Image.Ready
                    text: "󰎆"
                    color: Colors.primary
                    font.family: Metrics.font
                    font.pixelSize: musicPopup.lerp(16, musicPlayerCard.artSize * 0.4)
                }

            }

        }

    }

}
