import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets

// Now-playing card in the style of Apple's player: artwork, title and artist on
// top, a scrubbable progress bar with times, then the transport controls, and the
// lyrics under them once switched on with the microphone button by the equalizer.
Rectangle {
    id: card

    required property var player
    // Drawn under the glass, for a card with no blurred panel behind it.
    property color backgroundColor: "transparent"
    // Off when the card sits inside another surface that draws its own glass
    // and cover (the bar's music popup animates them from the cover pill).
    property bool glassVisible: true
    property bool coverVisible: true
    // Artwork geometry, followed by the bar's popup when it animates the cover.
    readonly property int artSize: 56
    readonly property int artMargin: 16
    readonly property int artRadius: 12
    // Off while the card is not shown: stops polling and animating.
    property bool active: true
    readonly property bool playing: player !== null && player.isPlaying
    // MprisPlayer.position drifts with Spotify (it keeps counting from the previous
    // track): position and length are asked with playerctl instead, and the
    // position runs on between two answers.
    readonly property string playerctlName: player !== null ? player.dbusName.replace("org.mpris.MediaPlayer2.", "") : ""
    property real polledPosition: 0
    property real polledLength: 0
    property real polledTime: 0
    property real now: 0
    readonly property real length: polledLength > 0 ? polledLength : (player !== null ? player.length : 0)
    readonly property real position: Math.min(length, polledPosition + (playing ? Math.max(0, now - polledTime) / 1000 : 0))
    // While scrubbing, the bar follows the pointer and the player seeks on release.
    property real scrubPosition: -1
    readonly property real shownPosition: scrubPosition >= 0 ? scrubPosition : position
    // The player alone, then the lyrics under it.
    readonly property int playerHeight: 172
    readonly property int lyricsHeight: 250
    readonly property int fullHeight: playerHeight + lyricsHeight
    readonly property bool lyricsShown: Lyrics.enabled && player !== null
    // The line being sung, a moment early so it does not read as late.
    readonly property int lyricsLine: {
        if (!Lyrics.synced || Lyrics.answeredTrack !== Lyrics.track)
            return -1;

        const now = position + 0.2;
        let index = -1;
        for (let i = 0; i < Lyrics.lines.length && Lyrics.lines[i].t <= now; i++)
            index = i;
        return index;
    }

    // Emitted just before skipping: 1 = next track, -1 = previous.
    signal skipRequested(int direction)

    function formatTime(seconds) {
        const total = Math.max(0, Math.floor(seconds));
        const minutes = Math.floor(total / 60);
        const rest = total % 60;
        return minutes + ":" + (rest < 10 ? "0" : "") + rest;
    }

    implicitHeight: lyricsShown ? fullHeight : playerHeight
    radius: 18
    color: "transparent"

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }

    }

    GlassSurface {
        visible: card.glassVisible
        radius: parent.radius
        backgroundColor: card.backgroundColor
    }

    function poll() {
        if (playerctlName !== "")
            positionProbe.running = true;

    }

    function seek(seconds) {
        player.position = seconds;
        polledPosition = seconds;
        polledTime = Date.now();
        now = polledTime;
        pollAfterSeek.restart();
    }

    onActiveChanged: {
        if (active) {
            // Runs on from the last answer until the new one arrives.
            now = Date.now();
            poll();
        }
    }
    onPlayingChanged: poll()

    Connections {
        function onPostTrackChanged() {
            card.poll();
        }

        target: card.player
    }

    Timer {
        interval: 1000
        running: card.active && card.player !== null
        repeat: true
        triggeredOnStart: true
        onTriggered: card.poll()
    }

    // Settles first: the title, the artist and the length do not change together.
    Timer {
        id: lyricsRequest

        interval: 500
        onTriggered: {
            if (card.player !== null && card.length > 0)
                Lyrics.request(card.player.trackArtist, card.player.trackTitle, card.player.trackAlbum, card.length);

        }
    }

    Connections {
        function onTrackTitleChanged() {
            lyricsRequest.restart();
        }

        function onTrackArtistChanged() {
            lyricsRequest.restart();
        }

        target: card.player
    }

    onLengthChanged: lyricsRequest.restart()
    onPlayerChanged: lyricsRequest.restart()

    Timer {
        id: pollAfterSeek

        interval: 300
        onTriggered: card.poll()
    }

    FrameAnimation {
        running: card.active && card.playing
        onTriggered: card.now = Date.now()
    }

    Process {
        id: positionProbe

        command: ["playerctl", "-p", card.playerctlName, "metadata", "--format", "{{position}} {{mpris:length}}"]

        stdout: StdioCollector {
            onStreamFinished: {
                const [position, length] = text.trim().split(" ").map((value) => {
                    return parseInt(value);
                });
                if (isNaN(position))
                    return ;

                card.polledPosition = position / 1e6;
                card.polledLength = isNaN(length) ? 0 : length / 1e6;
                card.polledTime = Date.now();
                card.now = card.polledTime;
            }
        }

    }

    ClippingRectangle {
        id: artwork

        x: card.artMargin
        y: card.artMargin
        width: card.artSize
        height: card.artSize
        opacity: card.coverVisible ? 1 : 0
        radius: card.artRadius
        color: "#45475a"

        Image {
            id: albumArt

            anchors.fill: parent
            source: card.player !== null ? card.player.trackArtUrl : ""
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectCrop
            mipmap: true
            visible: status === Image.Ready
        }

        Text {
            anchors.centerIn: parent
            visible: albumArt.status !== Image.Ready
            text: "󰎆"
            color: "#cba6f7"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 24
        }

    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: lyricsButton.left
        anchors.verticalCenter: artwork.verticalCenter
        anchors.leftMargin: card.artMargin + card.artSize + 12
        anchors.rightMargin: 12
        spacing: 2

        MarqueeText {
            Layout.fillWidth: true
            running: card.active
            text: card.player !== null ? (card.player.trackTitle || card.player.identity) : ""
            color: "#cba6f7"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Text {
            Layout.fillWidth: true
            text: card.player !== null ? (card.player.trackArtist || card.player.trackAlbum) : ""
            color: "#b4befe"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            elide: Text.ElideRight
        }

    }

    // Bars bouncing while the track plays, resting low while paused.
    Row {
        id: equalizer

        anchors.right: parent.right
        anchors.rightMargin: card.artMargin + 2
        anchors.verticalCenter: artwork.verticalCenter
        height: 18
        spacing: 3

        Repeater {
            model: [380, 520, 300, 450]

            Rectangle {
                id: bar

                required property int modelData
                required property int index
                property real level: 0.3

                anchors.bottom: parent.bottom
                width: 3
                height: parent.height * level
                radius: 1.5
                color: "#cba6f7"

                SequentialAnimation on level {
                    running: card.active && card.playing
                    loops: Animation.Infinite
                    onRunningChanged: {
                        if (!running)
                            bar.level = 0.3;

                    }

                    NumberAnimation {
                        to: 1
                        duration: bar.modelData
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        to: 0.25 + bar.index * 0.1
                        duration: bar.modelData * 0.8
                        easing.type: Easing.InOutSine
                    }

                }

            }

        }

    }

    Item {
        id: progress

        readonly property real ratio: card.length > 0 ? Math.min(1, card.shownPosition / card.length) : 0
        readonly property bool active: progressHover.hovered || card.scrubPosition >= 0

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: card.artMargin
        anchors.rightMargin: card.artMargin
        y: card.artMargin + card.artSize + 16
        height: 8

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: progress.active ? 8 : 5
            radius: height / 2
            color: Qt.rgba(205 / 255, 214 / 255, 244 / 255, 0.14)

            Rectangle {
                width: parent.width * progress.ratio
                height: parent.height
                radius: parent.radius
                color: "#cba6f7"
            }

            Behavior on height {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }

            }

        }

        // Taller than the bar, so it is easy to grab.
        Item {
            anchors.fill: parent
            anchors.topMargin: -8
            anchors.bottomMargin: -8
            enabled: card.player !== null && card.player.canSeek && card.length > 0

            HoverHandler {
                id: progressHover

                cursorShape: Qt.PointingHandCursor
            }

            DragHandler {
                target: null
                xAxis.enabled: true
                yAxis.enabled: false
                onActiveChanged: {
                    if (!active && card.scrubPosition >= 0) {
                        card.seek(card.scrubPosition);
                        card.scrubPosition = -1;
                    }
                }
                onCentroidChanged: {
                    if (active)
                        card.scrubPosition = Math.max(0, Math.min(1, centroid.position.x / progress.width)) * card.length;

                }
            }

            TapHandler {
                onTapped: (eventPoint) => {
                    card.seek(Math.max(0, Math.min(1, eventPoint.position.x / progress.width)) * card.length);
                }
            }

        }

    }

    Text {
        anchors.left: progress.left
        anchors.top: progress.bottom
        anchors.topMargin: 5
        text: card.formatTime(card.shownPosition)
        color: "#b4befe"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 11
        font.features: {
            "tnum": 1
        }
    }

    Text {
        anchors.right: progress.right
        anchors.top: progress.bottom
        anchors.topMargin: 5
        text: "-" + card.formatTime(card.length - card.shownPosition)
        color: "#b4befe"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 11
        font.features: {
            "tnum": 1
        }
    }

    PlayerControl {
        id: lyricsButton

        anchors.right: equalizer.left
        anchors.rightMargin: 4
        anchors.verticalCenter: artwork.verticalCenter
        icon: "󰍰"
        iconSize: 17
        size: 32
        highlighted: card.lyricsShown
        secondary: true
        available: card.player !== null
        onTriggered: Lyrics.setEnabled(!Lyrics.enabled)
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: card.artMargin - 6
        anchors.rightMargin: card.artMargin - 6
        y: card.playerHeight - 10 - height
        height: 44

        PlayerControl {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            icon: card.player !== null && card.player.shuffle ? "󰒝" : "󰒞"
            iconSize: 17
            size: 32
            highlighted: card.player !== null && card.player.shuffle
            secondary: true
            available: card.player !== null && card.player.shuffleSupported
            onTriggered: card.player.shuffle = !card.player.shuffle
        }

        Row {
            anchors.centerIn: parent
            spacing: 26

            PlayerControl {
                anchors.verticalCenter: parent.verticalCenter
                icon: "󰑟"
                iconSize: 28
                available: card.player !== null && card.player.canGoPrevious
                onTriggered: {
                    card.skipRequested(-1);
                    card.player.previous();
                }
            }

            PlayerControl {
                anchors.verticalCenter: parent.verticalCenter
                icon: card.player !== null && card.player.isPlaying ? "󰏤" : "󰐊"
                iconSize: 34
                size: 46
                available: card.player !== null && card.player.canTogglePlaying
                onTriggered: card.player.togglePlaying()
            }

            PlayerControl {
                anchors.verticalCenter: parent.verticalCenter
                icon: "󰈑"
                iconSize: 28
                available: card.player !== null && card.player.canGoNext
                onTriggered: {
                    card.skipRequested(1);
                    card.player.next();
                }
            }

        }

        PlayerControl {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            icon: card.player === null || card.player.loopState === MprisLoopState.None ? "󰑗" : (card.player.loopState === MprisLoopState.Track ? "󰑘" : "󰑖")
            iconSize: 17
            size: 32
            highlighted: card.player !== null && card.player.loopState !== MprisLoopState.None
            secondary: true
            available: card.player !== null && card.player.loopSupported
            onTriggered: {
                if (card.player.loopState === MprisLoopState.None)
                    card.player.loopState = MprisLoopState.Playlist;
                else if (card.player.loopState === MprisLoopState.Playlist)
                    card.player.loopState = MprisLoopState.Track;
                else
                    card.player.loopState = MprisLoopState.None;
            }
        }

    }

    LyricsView {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: card.artMargin + 2
        anchors.rightMargin: card.artMargin + 2
        y: card.playerHeight + 2
        height: card.lyricsHeight - 18
        visible: opacity > 0
        opacity: card.lyricsShown ? 1 : 0
        active: card.active && card.lyricsShown
        lines: Lyrics.answeredTrack === Lyrics.track ? Lyrics.lines : []
        synced: Lyrics.synced
        instrumental: Lyrics.instrumental && Lyrics.answeredTrack === Lyrics.track
        status: Lyrics.status
        current: card.lyricsLine
        onSeekRequested: (seconds) => {
            if (card.player !== null && card.player.canSeek)
                card.seek(seconds);

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 220
            }

        }

    }

    // Plain glyph; a soft round highlight shows on hover and press, like Apple's.
    component PlayerControl: Rectangle {
        id: control

        required property string icon
        required property bool available
        property int iconSize: 21
        property int size: 40
        // Small side controls (shuffle, repeat): dimmed unless switched on.
        property bool secondary: false
        property bool highlighted: false

        signal triggered()

        implicitWidth: size
        implicitHeight: size
        radius: size / 2
        color: "transparent"
        opacity: available ? 1 : 0.35
        scale: controlTap.pressed ? 0.88 : 1

        // Glass halo on hover, brighter while pressed.
        GlassSurface {
            radius: parent.radius
            hovered: controlTap.pressed
            opacity: controlHover.hovered && control.available ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                }

            }

        }

        Text {
            anchors.centerIn: parent
            text: control.icon
            color: control.secondary ? (control.highlighted ? "#cba6f7" : "#7f849c") : "#cba6f7"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: control.iconSize
        }

        HoverHandler {
            id: controlHover

            cursorShape: control.available ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        TapHandler {
            id: controlTap

            enabled: control.available
            onTapped: control.triggered()
        }

        Behavior on scale {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutBack
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: 120
            }

        }

    }

}
