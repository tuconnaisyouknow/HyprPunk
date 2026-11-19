import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.components
import qs.config
import qs.services
import qs.theme

// The now-playing card, in the spirit of Apple's player, with the lyrics underneath.
// While there's more than one player it has a page for each, after the first one, which
// follows whatever plays: the wheel, a sideways drag or the island card's keys turn
// them, their dots sit under the controls and the player's name between the two times.
// What plays, where it is and its lyrics are Music's: the card draws
// them, the position moving on its own frames between two of Music's answers.
Rectangle {
    id: card

    // The player followed, or null to show nothing (the lock screen keeping what you listen
    // to private).
    required property var player
    // Drawn under the glass, for a card with no blurred panel behind it.
    property color backgroundColor: "transparent"
    // Off when something else draws the glass, the cover and the equalizer (the island's
    // player flies them out of the island).
    property bool glassVisible: true
    property bool coverVisible: true
    property bool equalizerVisible: true
    // Off when the lyrics are shown somewhere else (beside the card on the lock screen),
    // which then uses lyricsLine.
    property bool lyricsInside: true
    // Where the artwork and the equalizer sit, for the island's player flying them in.
    readonly property int artSize: 56
    readonly property int artMargin: Metrics.spacing.huge
    readonly property int artRadius: Metrics.radius.normal
    readonly property point equalizerCenter: Qt.point(equalizer.x + equalizer.width / 2, equalizer.y + equalizer.height / 2)
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
    // The player alone, then the pages' dots and the lyrics under it, each with the room
    // it takes for now.
    readonly property int playerHeight: controls.y + controls.height + Metrics.spacing.large
    readonly property int dotSize: 6
    readonly property int sourcesHeight: dotSize + Metrics.spacing.large
    readonly property int lyricsHeight: 250
    readonly property int fullHeight: playerHeight + sourcesHeight + lyricsHeight
    property real sourcesRoom: sourcesShown ? sourcesHeight : 0
    property real lyricsRoom: lyricsFound && lyricsInside ? lyricsHeight : 0
    // Nothing to turn to with a single player.
    readonly property bool sourcesShown: player !== null && Players.sources.length > 1
    // Whatever plays, then each player, as Players picks them.
    readonly property var pages: [""].concat(Players.sources.map((source) => {
        return source.dbusName;
    }))
    readonly property int page: Math.max(0, pages.indexOf(Players.pickedSource))
    // How far the cover, the title and the player's name stand from their place while a
    // page turns, how far they go, and how much they show on the way.
    property real pageShift: 0
    readonly property int pageTravel: 28
    readonly property real pageOpacity: 1 - Math.abs(pageShift) / pageTravel
    readonly property bool turning: turn.running
    // The position as the bar draws it, gliding from one player's to the next.
    readonly property real drawnPosition: length > 0 ? progress.ratio * length : shownPosition
    // How far the wheel has gone in this gesture, and whether it turned a page already.
    property real wheelDelta: 0
    property bool wheelTurned: false
    readonly property bool lyricsShown: player !== null && Music.lyricsShown
    readonly property bool lyricsFound: player !== null && Music.lyricsFound
    readonly property int lyricsLine: Music.lyricsLine(position)
    // The side controls' glyphs, the skips' and play's: the main ones stand out.
    readonly property int sideIcon: Metrics.text.title
    readonly property int skipIcon: 28
    readonly property int playIcon: 34

    // To another page: the cover, the title and the player's name leave the way the pages
    // go, and the next ones come in from the other side. The rest stays, and changes
    // where it stands.
    function turnTo(index) {
        if (!sourcesShown || index < 0 || index >= pages.length || index === page || turn.running)
            return ;

        turn.source = pages[index];
        turn.direction = index > page ? 1 : -1;
        turn.restart();
    }

    // A notch of a wheel, or as much of a touchpad's small steps, turns one page, and the
    // rest of that gesture turns no other.
    function wheel(delta) {
        wheelRest.restart();
        if (wheelTurned)
            return ;

        wheelDelta += delta;
        if (Math.abs(wheelDelta) < 120)
            return ;

        wheelTurned = true;
        turnTo(page + (wheelDelta > 0 ? -1 : 1));
    }

    // From the keys: -1 up, 1 down.
    function scrollLyrics(direction) {
        if (lyricsFound && lyricsInside)
            lyricsView.scroll(direction);

    }

    function formatTime(seconds) {
        const total = Math.max(0, Math.floor(seconds));
        const minutes = Math.floor(total / 60);
        const rest = total % 60;
        return minutes + ":" + (rest < 10 ? "0" : "") + rest;
    }

    implicitHeight: playerHeight + sourcesRoom + lyricsRoom
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

    // Over the player, under its controls: the wheel, or a drag to the side, turns the
    // page. The lyrics keep the wheel for themselves.
    Item {
        width: parent.width
        height: card.playerHeight + card.sourcesRoom
        enabled: card.sourcesShown

        // A wheel handler only hears one way, so one each: up and down, and sideways.
        // A gesture that goes both ways counts for the one it goes most.
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                if (Math.abs(event.angleDelta.y) >= Math.abs(event.angleDelta.x))
                    card.wheel(event.angleDelta.y);

            }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            orientation: Qt.Horizontal
            onWheel: (event) => {
                if (Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y))
                    card.wheel(event.angleDelta.x);

            }
        }

        // The gesture is over: the next one starts from nothing.
        Timer {
            id: wheelRest

            interval: 200
            onTriggered: {
                card.wheelDelta = 0;
                card.wheelTurned = false;
            }
        }

        DragHandler {
            target: null
            xAxis.enabled: true
            yAxis.enabled: false
            // How far it went: gone by the time the drag is over.
            property real pulled: 0

            onActiveTranslationChanged: {
                if (active)
                    pulled = activeTranslation.x;

            }
            onActiveChanged: {
                if (!active && Math.abs(pulled) > 40)
                    card.turnTo(card.page + (pulled > 0 ? -1 : 1));

            }
        }

    }

    SequentialAnimation {
        id: turn

        property string source: ""
        property int direction: 1

        Anim {
            target: card
            property: "pageShift"
            to: -turn.direction * card.pageTravel
            token: Motion.leave.small
        }

        ScriptAction {
            script: {
                Players.pick(turn.source);
                card.pageShift = turn.direction * card.pageTravel;
            }
        }

        Anim {
            target: card
            property: "pageShift"
            to: 0
            token: Motion.enter.normal
        }

    }

    CoverArt {
        id: artwork

        x: card.artMargin
        y: card.artMargin
        width: card.artSize
        height: card.artSize
        visible: card.coverVisible
        opacity: card.pageOpacity
        fades: !card.turning
        radius: card.artRadius

        transform: Translate {
            x: card.pageShift
        }

        source: card.player !== null ? card.player.trackArtUrl : ""
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: lyricsButton.left
        anchors.verticalCenter: artwork.verticalCenter
        anchors.leftMargin: card.artMargin + card.artSize + Metrics.spacing.large
        anchors.rightMargin: Metrics.spacing.large
        spacing: Metrics.spacing.hairline
        opacity: card.pageOpacity

        transform: Translate {
            x: card.pageShift
        }

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

    Equalizer {
        id: equalizer

        anchors.right: parent.right
        anchors.rightMargin: card.artMargin + Metrics.spacing.hairline
        anchors.verticalCenter: artwork.verticalCenter
        visible: card.equalizerVisible
        playing: card.playing
        running: card.active && card.equalizerVisible && MusicSettings.equalizer
    }

    Item {
        id: progress

        property real ratio: card.length > 0 ? Math.min(1, card.shownPosition / card.length) : 0
        readonly property bool active: progressHover.hovered || card.scrubPosition >= 0

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: card.artMargin
        anchors.rightMargin: card.artMargin
        y: card.artMargin + card.artSize + Metrics.spacing.huge
        height: Metrics.spacing.normal

        // Only as a page turns: the level glides to where the next player is.
        Behavior on ratio {
            enabled: card.turning

            Anim {
                token: Motion.move.normal
            }

        }

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
        id: elapsed

        anchors.left: progress.left
        anchors.top: progress.bottom
        anchors.topMargin: Metrics.spacing.small
        text: card.formatTime(card.drawnPosition)
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
        // A stream has no end to count down to.
        opacity: card.length > 0 ? 1 : 0
        text: "-" + card.formatTime(card.length - card.drawnPosition)

        Behavior on opacity {
            Anim {
                token: Motion.color.small
            }

        }

        color: Colors.secondary
        font.family: Metrics.font
        font.pixelSize: Metrics.text.small
        font.features: {
            "tnum": 1
        }
    }

    // The player you're on, between the two times, after "Auto" on the page that follows
    // whatever plays.
    Text {
        anchors.horizontalCenter: progress.horizontalCenter
        anchors.top: progress.bottom
        anchors.topMargin: Metrics.spacing.small
        width: Math.min(implicitWidth, progress.width - 110)
        visible: opacity > 0
        opacity: card.pageOpacity * card.sourcesRoom / card.sourcesHeight
        text: card.player !== null ? (card.page === 0 ? "Auto · " : "") + card.player.identity : ""
        color: Colors.secondary
        elide: Text.ElideRight
        font.family: Metrics.font
        font.pixelSize: Metrics.text.small

        transform: Translate {
            x: card.pageShift
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
    // reaching past them. As far under the times as the pages' dots are under them.
    Item {
        id: controls

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: card.artMargin - Metrics.spacing.normal
        anchors.rightMargin: card.artMargin - Metrics.spacing.normal
        y: elapsed.y + elapsed.height + Metrics.spacing.large
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

    // A dot per page, the one you're on drawn out in the accent. A click goes to its page.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: card.playerHeight
        spacing: card.dotSize
        visible: opacity > 0
        opacity: card.sourcesRoom / card.sourcesHeight

        Repeater {
            // The last ones stay while they fade out.
            Binding on model {
                when: card.sourcesShown
                value: card.pages.length
                restoreMode: Binding.RestoreNone
            }

            Rectangle {
                id: dot

                required property int index
                readonly property bool current: index === card.page

                width: current ? 3 * card.dotSize : card.dotSize
                height: card.dotSize
                radius: height / 2
                color: current ? Colors.primary : Colors.alpha(Colors.secondary, 0.5)

                HoverHandler {
                    margin: card.dotSize / 2
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    margin: card.dotSize / 2
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: card.turnTo(dot.index)
                }

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

    LyricsView {
        id: lyricsView

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: card.artMargin
        anchors.rightMargin: card.artMargin
        y: card.playerHeight + card.sourcesRoom
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

    Behavior on sourcesRoom {
        Anim {
            token: Motion.resize.large
        }

    }

    Behavior on lyricsRoom {
        Anim {
            token: Motion.resize.large
        }

    }

}
