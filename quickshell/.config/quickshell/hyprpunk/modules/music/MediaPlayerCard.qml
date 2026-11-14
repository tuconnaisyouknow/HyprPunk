import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.components
import qs.services
import qs.theme

// The now-playing card, in the spirit of Apple's player, with the lyrics underneath.
// What plays, where it is and its lyrics are Music's: the card draws them, the position
// moving on its own frames between two of Music's answers.
Rectangle {
    id: card

    // Spotify's player, or null to show nothing (the lock screen keeping what you listen
    // to private).
    required property var player
    // Drawn under the glass, for a card with no blurred panel behind it.
    property color backgroundColor: "transparent"
    // Off when something else draws the glass and the cover (the bar's music popup
    // animates them out of the cover pill).
    property bool glassVisible: true
    property bool coverVisible: true
    // Off when the lyrics are shown somewhere else (beside the card on the lock screen),
    // which then uses lyricsLine.
    property bool lyricsInside: true
    // Artwork geometry, followed by the bar's popup when it animates the cover.
    readonly property int artSize: 56
    readonly property int artMargin: Metrics.spacing.huge
    readonly property int artRadius: Metrics.radius.normal
    // Shown: the position is followed and the card animates.
    property bool active: true
    readonly property bool playing: player !== null && player.isPlaying
    // The time the position is drawn at, moved on every frame while playing.
    property real now: Date.now()
    readonly property real length: Music.length
    readonly property real position: Music.positionAt(now)
    // While scrubbing, the bar follows the pointer and the player seeks on release.
    property real scrubPosition: -1
    readonly property real shownPosition: scrubPosition >= 0 ? scrubPosition : position
    // The player alone, then the lyrics under it.
    readonly property int playerHeight: 172
    readonly property int lyricsHeight: 250
    readonly property int fullHeight: playerHeight + lyricsHeight
    readonly property bool lyricsShown: player !== null && Music.lyricsShown
    readonly property bool lyricsFound: player !== null && Music.lyricsFound
    readonly property int lyricsLine: Music.lyricsLine(position)
    // The side controls' glyphs, the skips' and play's: the main ones stand out.
    readonly property int sideIcon: Metrics.text.title
    readonly property int skipIcon: 28
    readonly property int playIcon: 34

    function formatTime(seconds) {
        const total = Math.max(0, Math.floor(seconds));
        const minutes = Math.floor(total / 60);
        const rest = total % 60;
        return minutes + ":" + (rest < 10 ? "0" : "") + rest;
    }

    implicitHeight: lyricsFound && lyricsInside ? fullHeight : playerHeight
    radius: Metrics.radius.card
    color: "transparent"
    // Picks up from where the track is now, not where it was when last shown.
    onActiveChanged: now = Date.now()

    ServiceRef {
        service: Music
        active: card.active && card.player !== null
    }

    FrameAnimation {
        running: card.active && card.playing
        onTriggered: card.now = Date.now()
    }

    // A new answer, or a seek: drawn at once, even while paused.
    Connections {
        function onPolledTimeChanged() {
            card.now = Date.now();
        }

        target: Music
    }

    GlassSurface {
        visible: card.glassVisible
        radius: parent.radius
        backgroundColor: card.backgroundColor
    }

    ClippingRectangle {
        id: artwork

        x: card.artMargin
        y: card.artMargin
        width: card.artSize
        height: card.artSize
        opacity: card.coverVisible ? 1 : 0
        radius: card.artRadius
        color: Colors.surface1

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
            color: Colors.primary
            font.family: Metrics.font
            font.pixelSize: card.artSize * 0.4
        }

    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: lyricsButton.left
        anchors.verticalCenter: artwork.verticalCenter
        anchors.leftMargin: card.artMargin + card.artSize + Metrics.spacing.large
        anchors.rightMargin: Metrics.spacing.large
        spacing: Metrics.spacing.hairline

        MarqueeText {
            Layout.fillWidth: true
            running: card.active
            text: card.player !== null ? (card.player.trackTitle || card.player.identity) : ""
            color: Colors.primary
            font.family: Metrics.font
            font.pixelSize: Metrics.text.emphasis
            font.weight: Font.DemiBold
        }

        Text {
            Layout.fillWidth: true
            text: card.player !== null ? (card.player.trackArtist || card.player.trackAlbum) : ""
            color: Colors.secondary
            font.family: Metrics.font
            font.pixelSize: Metrics.text.body
            elide: Text.ElideRight
        }

    }

    // Bars bouncing while the track plays, resting low while paused. Each at its own
    // pace, so they never move together.
    Row {
        id: equalizer

        anchors.right: parent.right
        anchors.rightMargin: card.artMargin + Metrics.spacing.hairline
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
                radius: width / 2
                color: Colors.primary

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
                        easing.type: Motion.pulse.easing
                    }

                    NumberAnimation {
                        to: 0.25 + bar.index * 0.1
                        duration: bar.modelData * 0.8
                        easing.type: Motion.pulse.easing
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
        y: card.artMargin + card.artSize + Metrics.spacing.huge
        height: Metrics.spacing.normal

        // Thicker under the pointer, to show you can grab it.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: progress.active ? parent.height : 5
            radius: height / 2
            color: Colors.alpha(Colors.light, 0.14)

            Rectangle {
                width: parent.width * progress.ratio
                height: parent.height
                radius: parent.radius
                color: Colors.primary
            }

            Behavior on height {
                Anim {
                    token: Motion.resize.small
                }

            }

        }

        // Taller than the bar, so it is easy to grab.
        Item {
            anchors.fill: parent
            anchors.topMargin: -Metrics.spacing.normal
            anchors.bottomMargin: -Metrics.spacing.normal
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
                        Music.seek(card.scrubPosition);
                        card.scrubPosition = -1;
                    }
                }
                onCentroidChanged: {
                    if (active)
                        card.scrubPosition = Math.max(0, Math.min(1, centroid.position.x / progress.width)) * card.length;

                }
            }

            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: (eventPoint) => {
                    Music.seek(Math.max(0, Math.min(1, eventPoint.position.x / progress.width)) * card.length);
                }
            }

        }

    }

    Text {
        anchors.left: progress.left
        anchors.top: progress.bottom
        anchors.topMargin: Metrics.spacing.small
        text: card.formatTime(card.shownPosition)
        color: Colors.secondary
        font.family: Metrics.font
        font.pixelSize: Metrics.text.small
        font.features: {
            "tnum": 1
        }
    }

    Text {
        anchors.right: progress.right
        anchors.top: progress.bottom
        anchors.topMargin: Metrics.spacing.small
        text: "-" + card.formatTime(card.length - card.shownPosition)
        color: Colors.secondary
        font.family: Metrics.font
        font.pixelSize: Metrics.text.small
        font.features: {
            "tnum": 1
        }
    }

    IconButton {
        id: lyricsButton

        anchors.right: equalizer.left
        anchors.rightMargin: Metrics.spacing.small
        anchors.verticalCenter: artwork.verticalCenter
        icon: "󰍰"
        iconSize: card.sideIcon
        lit: card.lyricsShown
        enabled: card.player !== null
        onClicked: Lyrics.setEnabled(!Lyrics.enabled)
    }

    // The side controls' glyphs line up with the cover and the bar's ends, their halo
    // reaching past them.
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: card.artMargin - Metrics.spacing.normal
        anchors.rightMargin: card.artMargin - Metrics.spacing.normal
        y: card.playerHeight - Metrics.spacing.large - height
        height: playButton.height

        IconButton {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            icon: card.player !== null && card.player.shuffle ? "󰒝" : "󰒞"
            iconSize: card.sideIcon
            lit: card.player !== null && card.player.shuffle
            enabled: card.player !== null && card.player.shuffleSupported
            onClicked: card.player.shuffle = !card.player.shuffle
        }

        Row {
            anchors.centerIn: parent
            spacing: Metrics.spacing.section

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: width
                icon: "󰑟"
                iconSize: card.skipIcon
                lit: true
                enabled: card.player !== null && card.player.canGoPrevious
                onClicked: Music.skip(-1)
            }

            IconButton {
                id: playButton

                anchors.verticalCenter: parent.verticalCenter
                width: 46
                height: width
                icon: card.playing ? "󰏤" : "󰐊"
                iconSize: card.playIcon
                lit: true
                enabled: card.player !== null && card.player.canTogglePlaying
                onClicked: card.player.togglePlaying()
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: width
                icon: "󰈑"
                iconSize: card.skipIcon
                lit: true
                enabled: card.player !== null && card.player.canGoNext
                onClicked: Music.skip(1)
            }

        }

        IconButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            icon: card.player === null || card.player.loopState === MprisLoopState.None ? "󰑗" : card.player.loopState === MprisLoopState.Track ? "󰑘" : "󰑖"
            iconSize: card.sideIcon
            lit: card.player !== null && card.player.loopState !== MprisLoopState.None
            enabled: card.player !== null && card.player.loopSupported
            onClicked: {
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
        id: lyricsView

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: card.artMargin
        anchors.rightMargin: card.artMargin
        y: card.playerHeight
        height: card.lyricsHeight - Metrics.spacing.huge
        visible: card.lyricsInside && opacity > 0
        // Kept while the previous track's lines slide away.
        opacity: card.lyricsFound || lyricsView.leaving ? 1 : 0
        active: card.active && card.lyricsInside && card.lyricsFound
        ready: Music.positionKnown
        lines: card.lyricsFound ? Lyrics.lines : []
        synced: Lyrics.synced
        current: card.lyricsLine
        onSeekRequested: (seconds) => {
            return Music.seek(seconds);
        }

        Behavior on opacity {
            Anim {
                token: Motion.color.normal
            }

        }

    }

    Behavior on implicitHeight {
        Anim {
            token: Motion.resize.large
        }

    }

}
