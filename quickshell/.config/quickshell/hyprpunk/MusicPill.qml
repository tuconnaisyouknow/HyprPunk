import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// The Spotify track's cover as a spinning record, on the right of the bar. It spins
// while the music plays and rolls out for the next track. Hovering it grows the player
// out of it, the cover gliding to its place in the card.
Rectangle {
    id: musicPill

    // Spotify's player, null while it isn't running.
    required property var player
    required property var shellState
    // Where the screen draws its cards (ScreenShell), the player among them.
    required property Item cardLayer
    readonly property alias popup: musicPopup

    // Angle of the front disc: 0 = upright, where every track starts.
    property real spin: 0
    // 0 -> 1 after a new track or a restart: the disc only starts spinning
    // once it has settled upright.
    property real spinFactor: 1
    // While the player is open, the disc pauses and picks up from the same angle
    // afterwards, without jumping.
    readonly property bool displayFrozen: musicPopup.mapped
    readonly property real frontAngle: spin + rewind
    // Degrees per second: speeds up and slows down like a turntable.
    property real spinSpeed: musicPill.player !== null && musicPill.player.isPlaying ? 45 : 0
    // Angle of the disc rolling out, frozen when the track changed.
    property real outgoingSpin: 0
    // 0 -> 1 while the discs swap, direction 1 = next track, -1 = previous.
    property real swipe: 1
    property int swipeDirection: 1
    property bool frontIsA: true
    property string currentTrackId: ""
    property var trackHistory: []
    // Set by the player buttons just before skipping.
    property int skipHint: 0
    // Extra angle of the front disc while it rewinds (track restarted).
    property real rewind: 0
    // Last position reported by the player (seconds), when and while playing or not.
    property real knownPosition: 0
    property real knownPositionTime: 0
    property bool knownPositionPlaying: false
    property real trackChangeTime: 0

    // From the player's shortcut: "toggle", "open" or "close".
    function request(action) {
        musicPopup.request(action);
    }

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

    function trackId() {
        const player = musicPill.player;
        return player.metadata["mpris:trackid"] ?? (player.trackTitle + player.trackArtist);
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

    function rememberPosition(position) {
        knownPosition = position ?? musicPill.player.position;
        knownPositionTime = Date.now();
        knownPositionPlaying = musicPill.player.isPlaying;
    }

    // "Previous" a few seconds in restarts the track instead of changing it:
    // the position jumps back to 0 on the same track.
    function checkRestart(position) {
        const current = position ?? musicPill.player.position;
        const expected = knownPosition + (knownPositionPlaying ? (Date.now() - knownPositionTime) / 1000 : 0);
        // A position jump right after a track change isn't a restart (it used to give the
        // new disc an extra spin), and "previous" that early changes track anyway.
        const settled = Date.now() - trackChangeTime > 2000;
        const restarted = settled && trackId() === currentTrackId && current < 1.5 && expected > 2;
        rememberPosition(current);
        if (restarted && displayFrozen) {
            // Hidden under the player's cover: straight back to upright.
            rewindAnimation.stop();
            spin = 0;
            rewind = 0;
            pulse();
        } else if (restarted) {
            // Back to upright, at least one full turn so it shows.
            spinRamp.stop();
            spinFactor = 0;
            rewindAnimation.to = -(spin + (spin < 120 ? 360 : 0));
            pulse();
            rewindAnimation.restart();
        }
    }

    function resetDiscs() {
        discSwipe.stop();
        rewindAnimation.stop();
        swipe = 1;
        spin = 0;
        rewind = 0;
        spinFactor = 1;
        currentTrackId = musicPill.player !== null ? trackId() : "";
        trackHistory = currentTrackId !== "" ? [currentTrackId] : [];
        frontDisc().source = musicPill.player !== null ? pillArt() : "";
        if (musicPill.player !== null)
            rememberPosition();

    }

    function changeTrack() {
        const id = trackId();
        if (id === currentTrackId)
            return ;

        // No hint (media keys, the phone…): going back to the previous track
        // in the history means backwards.
        const history = trackHistory.slice();
        let direction = skipHint;
        if (direction === 0 && Date.now() < musicPill.shellState.musicSkipUntil)
            direction = musicPill.shellState.musicSkipDirection;

        if (direction === 0)
            direction = history.length >= 2 && history[history.length - 2] === id ? -1 : 1;

        if (direction < 0 && history.length >= 2 && history[history.length - 2] === id)
            history.pop();
        else
            history.push(id);
        trackHistory = history.slice(-50);
        skipHint = 0;
        currentTrackId = id;
        // The player still reports the old track's position at this point.
        rememberPosition(0);
        trackChangeTime = Date.now();
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
    implicitWidth: 38
    implicitHeight: 38
    radius: 19
    // The pill's background is painted by the hole and the ring below; a fill here
    // would show twice under the ring.
    color: "transparent"

    // Shows while a disc rolls in or out of the hole.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius: width / 2
        color: Theme.panel
    }

    Behavior on spinSpeed {
        NumberAnimation {
            duration: 900
            easing.type: Easing.InOutQuad
        }

    }

    // Two discs, so on a track change the old one can roll out while the new one
    // rolls in, forwards or backwards.
    Item {
        id: discWindow

        anchors.fill: parent
        // Slightly larger than the hole: its edge is drawn by the ring above.
        anchors.margins: 2

        CoverDisc {
            id: discA

            width: parent.width
            height: parent.height
            x: musicPill.discX(musicPill.frontIsA)
            rotation: musicPill.discRotation(musicPill.frontIsA, x)
            visible: musicPill.frontIsA || musicPill.swipe < 1
        }

        CoverDisc {
            id: discB

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
        border.color: Theme.panel
        antialiasing: true
    }

    // Over the ring, like the other pills' rim.
    GlassSurface {
        z: 1
        radius: 19
        tinted: false
    }

    // Spins while playing, keeps its angle while paused.
    FrameAnimation {
        running: musicPill.spinSpeed > 0 && !musicPill.displayFrozen
        onTriggered: musicPill.spin = (musicPill.spin + musicPill.spinSpeed * musicPill.spinFactor * frameTime) % 360
    }

    SequentialAnimation {
        id: pulseAnimation

        NumberAnimation {
            target: musicPill
            property: "scale"
            to: 1.16
            duration: 120
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: musicPill
            property: "scale"
            to: 1
            duration: 480
            easing.type: Easing.OutBack
            easing.overshoot: 3
        }

    }

    // Leaves time for a real track change (which also resets the position)
    // to be announced first.
    Timer {
        id: restartCheckDelay

        interval: 150
        onTriggered: musicPill.checkRestart()
    }

    // One quick turn backwards, like a record pulled back by hand.
    NumberAnimation {
        id: rewindAnimation

        target: musicPill
        property: "rewind"
        from: 0
        duration: 650
        easing.type: Easing.OutCubic
        onFinished: {
            musicPill.spin = 0;
            musicPill.rewind = 0;
            spinRamp.restart();
        }
    }

    // Spotify doesn't always announce a restart (no Seeked signal), so after
    // "previous" we ask for the position directly.
    Timer {
        id: restartProbeDelay

        interval: 350
        onTriggered: restartProbe.running = true
    }

    Process {
        id: restartProbe

        // Position in microseconds, plus the track it belongs to, so a track change
        // that hasn't been announced yet doesn't look like a restart.
        command: ["playerctl", "-p", "spotify", "metadata", "--format", "{{position}} {{mpris:trackid}}"]

        stdout: StdioCollector {
            onStreamFinished: {
                const [position, track] = text.trim().split(" ");
                if (musicPill.player !== null && track === musicPill.currentTrackId && !isNaN(parseInt(position)))
                    musicPill.checkRestart(parseInt(position) / 1e6);

            }
        }

    }

    Connections {
        function onMusicPreviousRequestsChanged() {
            restartProbeDelay.restart();
        }

        target: musicPill.shellState
    }

    // Starts spinning gently, like a turntable getting up to speed.
    NumberAnimation {
        id: spinRamp

        target: musicPill
        property: "spinFactor"
        to: 1
        duration: 700
        easing.type: Easing.InQuad
    }

    NumberAnimation {
        id: discSwipe

        target: musicPill
        property: "swipe"
        from: 0
        to: 1
        duration: 520
        easing.type: Easing.OutCubic
        onFinished: spinRamp.restart()
    }

    Connections {
        function onPostTrackChanged() {
            musicPill.changeTrack();
        }

        function onPositionChanged() {
            restartCheckDelay.restart();
        }

        function onIsPlayingChanged() {
            musicPill.rememberPosition();
            musicPill.pulse();
        }

        function onTrackArtUrlChanged() {
            // The cover sometimes arrives after the track change, and sometimes just before,
            // while the old disc is still in front (changeTrack handles that case).
            if (musicPill.trackId() === musicPill.currentTrackId)
                musicPill.frontDisc().source = musicPill.pillArt();

        }

        target: musicPill.player
    }

    HoverHandler {
        onHoveredChanged: hovered ? musicPopup.hoverStarted() : musicPopup.hoverEnded()
    }

    TapHandler {
        cursorShape: Qt.PointingHandCursor
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

        shellState: musicPill.shellState
        cardLayer: musicPill.cardLayer
        pill: musicPill
        pillName: "player"
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
            onSkipRequested: (direction) => {
                musicPill.skipHint = direction;
                if (direction < 0)
                    restartProbeDelay.restart();

            }
        }

        // From the pill's little round cover to the player's artwork. Nothing spins: the disc
        // grows at its frozen angle and the square cover fades in over it (and back out).
        Item {
            readonly property real size: musicPopup.lerp(32, musicPlayerCard.artSize)
            readonly property real squareOpacity: Math.min(1, Math.max(0, (musicPopup.coverProgress - 0.4) / 0.5))

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: musicPopup.lerp(3, musicPlayerCard.artMargin)
            // Slides from the right edge to the left one of the growing card, so it is never cut.
            anchors.leftMargin: (1 - musicPopup.coverProgress) * (musicPopup.card.width - 3 - size) + musicPopup.coverProgress * musicPlayerCard.artMargin
            width: size
            height: size

            CoverDisc {
                anchors.fill: parent
                visible: parent.squareOpacity < 1
                rotation: musicPopup.discAngle
                antialiasing: true
                // Same art as the pill's disc, so both match when it folds back.
                source: musicPill.player !== null ? musicPill.pillArt() : ""
                decodeSize: 64
            }

            ClippingRectangle {
                anchors.fill: parent
                opacity: parent.squareOpacity
                visible: opacity > 0
                radius: musicPlayerCard.artRadius
                color: Theme.surface1

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
                    color: Theme.mauve
                    font.family: Theme.font
                    font.pixelSize: musicPopup.lerp(16, 24)
                }

            }

        }

    }

}
