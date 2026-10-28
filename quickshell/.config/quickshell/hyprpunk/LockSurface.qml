import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// The lock screen on one display: the blurred wallpaper, a slimmed-down bar (resources,
// the island as a padlock, the status pill), the date and time with the player and its
// lyrics in the middle, and a password prompt that only shows up while you type.
//
// Locking starts from the screen as it was: the bar's pills leave, move or stay, the
// island grows from the clock into a padlock that clicks shut, and everything blurs into
// the wallpaper. Unlocking plays it all backwards once the padlock has opened.
WlSessionLockSurface {
    id: surface

    required property var lock
    readonly property var bar: lock.barFor(screen)
    readonly property bool promptShown: lock.password !== "" || lock.authenticating
    // Where the bar's pills were when locking (Bar.lockGeometry), null until known.
    property var from: null
    // 0 is the screen as it was, 1 the lock fully in place.
    property real reveal: lock.instant ? 1 : 0
    // 0 = the pills where the bar has them, 1 = where the lock has them.
    property real morph: lock.instant ? 1 : 0
    // Showing the time like the bar's island, before growing and after unlocking.
    property bool intro: !lock.instant
    property bool leaving: false
    // The padlock closes once the island has grown, and stays shut until unlocked.
    property bool padlockClosed: lock.instant
    // The first moments, while the island tells it locked.
    property bool locking: !lock.instant
    // The bar's OSDs (volume, brightness, battery...) show in the island too.
    readonly property bool osdShown: bar !== null && bar.statusOsdVisible
    readonly property string islandMode: leaving || intro ? "clock" : lock.unlocking ? "unlocking" : lock.error !== "" ? "error" : locking ? "locking" : osdShown ? "osd" : ""
    // The island's states that show the padlock.
    readonly property bool padlockShown: islandMode !== "clock" && islandMode !== "osd"

    // Progress of what comes in between from and to of the reveal.
    function stage(from, to) {
        return Math.max(0, Math.min(1, (reveal - from) / (to - from)));
    }

    function smooth(t) {
        return t * t * (3 - 2 * t);
    }

    // From where the bar has a pill to where the lock wants it.
    function between(start, end) {
        return start + (end - start) * morph;
    }

    // Straight to the lock fully shown, for sleep.
    function settle() {
        introDelay.stop();
        padlockDelay.stop();
        lockingDelay.stop();
        revealIn.stop();
        morphIn.stop();
        intro = false;
        padlockClosed = true;
        locking = false;
        reveal = 1;
        morph = 1;
    }

    function freeze() {
        if (from === null && bar !== null)
            from = bar.lockGeometry();

    }

    color: "#11111b"
    onBarChanged: freeze()
    Component.onCompleted: freeze()

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    NumberAnimation {
        id: revealIn

        target: surface
        property: "reveal"
        to: 1
        duration: 1100
        easing.type: Easing.OutQuad
    }

    NumberAnimation {
        id: morphIn

        target: surface
        property: "morph"
        to: 1
        duration: 550
        easing.type: Easing.InOutCubic
    }

    // The padlock opens first, then everything goes back to the screen as it was.
    SequentialAnimation {
        id: revealOut

        PauseAnimation {
            duration: 450
        }

        ScriptAction {
            script: surface.leaving = true
        }

        ParallelAnimation {
            NumberAnimation {
                target: surface
                property: "reveal"
                to: 0
                duration: 500
                easing.type: Easing.InOutQuad
            }

            NumberAnimation {
                target: surface
                property: "morph"
                to: 0
                duration: 450
                easing.type: Easing.InOutCubic
            }

        }

    }

    Connections {
        function onUnlockingChanged() {
            if (surface.lock.unlocking) {
                revealIn.stop();
                morphIn.stop();
                revealOut.restart();
            }
        }

        function onSettled() {
            if (!surface.lock.unlocking)
                surface.settle();

        }

        target: surface.lock
    }

    // The island shows the time for a moment, like the bar's, and the rest of the lock
    // follows as soon as it starts to grow.
    Timer {
        id: introDelay

        interval: 120
        running: !surface.lock.instant
        onTriggered: {
            surface.intro = false;
            if (!surface.lock.unlocking) {
                revealIn.start();
                morphIn.start();
            }
        }
    }

    Timer {
        id: padlockDelay

        interval: 380
        running: !surface.lock.instant
        onTriggered: surface.padlockClosed = true
    }

    // Told until the rest of the lock has come.
    Timer {
        id: lockingDelay

        interval: 1700
        running: !surface.lock.instant
        onTriggered: surface.locking = false
    }

    Image {
        id: snapshot

        anchors.fill: parent
        source: surface.lock.snapshotFor(surface.screen) !== "" ? "file://" + surface.lock.snapshotFor(surface.screen) : ""
        cache: false
        visible: false
    }

    Image {
        id: wallpaper

        anchors.fill: parent
        source: surface.bar !== null && surface.bar.wallpaperPath !== "" ? "file://" + surface.bar.wallpaperPath : ""
        sourceSize.width: surface.width
        sourceSize.height: surface.height
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }

    // The screen as it was, with the bar painted over by the wallpaper: the lock draws
    // its own pills, so no ghost of them is left blurring in the background.
    Item {
        id: frozenScreen

        anchors.fill: parent
        visible: false

        ShaderEffectSource {
            anchors.fill: parent
            sourceItem: snapshot
        }

        Item {
            width: parent.width
            height: 56
            clip: true

            ShaderEffectSource {
                width: surface.width
                height: surface.height
                sourceItem: wallpaper
            }

        }

    }

    // Blurs first, so the wallpaper then fades in over an already blurred screen.
    MultiEffect {
        anchors.fill: parent
        source: frozenScreen
        visible: snapshot.status === Image.Ready
        blurEnabled: true
        blur: surface.smooth(surface.stage(0, 0.55))
        blurMax: 64
        // Wider than the wallpaper's: the windows' shapes are gone before it comes.
        blurMultiplier: 1.5
        brightness: -0.12 * surface.stage(0, 0.55)
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        visible: wallpaper.status === Image.Ready
        blurEnabled: true
        blur: 1
        blurMax: 64
        brightness: -0.12
        opacity: surface.smooth(surface.stage(0.25, 1))
        scale: 1.04 - 0.04 * surface.stage(0.25, 1)
    }

    Item {
        id: content

        anchors.fill: parent

        // The bar's pills the lock doesn't keep, cut out of the snapshot: they fade away
        // where they stood (and come back when unlocking).
        Repeater {
            model: surface.from !== null ? surface.from.others : []

            ClippingRectangle {
                id: fadingPill

                required property var modelData

                x: modelData.x
                y: modelData.y
                width: modelData.width
                height: modelData.height
                radius: modelData.radius
                color: "transparent"
                opacity: 1 - surface.smooth(Math.min(1, surface.morph / 0.6))
                scale: 1 - 0.12 * surface.morph

                ShaderEffectSource {
                    width: parent.width
                    height: parent.height
                    sourceItem: snapshot
                    sourceRect: Qt.rect(fadingPill.modelData.x, fadingPill.modelData.y, fadingPill.modelData.width, fadingPill.modelData.height)
                }

            }

        }

        // The resources: from their place after the workspaces to the left edge.
        Pill {
            readonly property var start: surface.from !== null ? surface.from.monitor : null

            x: start !== null ? surface.between(start.x, 24) : 24
            y: start !== null ? start.y : 6
            visible: surface.bar !== null && surface.width >= 1200
            // Not in the bar (a narrow screen): it fades in instead.
            opacity: start !== null ? 1 : surface.morph

            IconText {
                icon: ""
                text: surface.bar !== null ? surface.bar.memoryText : ""
            }

            IconText {
                icon: ""
                text: surface.bar !== null ? surface.bar.cpuUsage + "%" : ""
            }

        }

        // The island grows like an OSD to lock, unlock or say a try failed,
        // and shrinks back to the time once unlocked.
        Pill {
            id: island

            readonly property bool expanded: surface.islandMode !== "" && surface.islandMode !== "clock"
            readonly property real startCenter: surface.from !== null ? surface.from.island.x + surface.from.island.width / 2 : surface.width / 2
            // The bar's island sits 3px higher, and 3px lower while it shows an OSD.
            property real centerY: expanded ? 31 : 25
            property real shake: 0
            // The last state, for the fade between two states.
            property string previousMode: "clock"

            x: surface.between(startCenter, surface.width / 2) - width / 2 + shake
            // Locked for sleep, it starts on the padlock.
            Component.onCompleted: previousMode = surface.islandMode
            y: centerY - height / 2
            spacing: 0
            horizontalPadding: expanded ? 36 : 20
            implicitHeight: expanded ? 50 : 38

            // Each part opens and closes its own width and the island follows, so nothing
            // pokes out of its edges while it grows or shrinks.
            Label {
                visible: Layout.preferredWidth > 0
                Layout.preferredWidth: surface.islandMode === "clock" ? implicitWidth : 0
                clip: true
                text: Qt.formatDateTime(clock.date, "HH:mm")

                Behavior on Layout.preferredWidth {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }

                }

            }

            // Hidden straight away when going back to the time: the open shackle would
            // hang over the digits while the width closes.
            LockIcon {
                visible: Layout.preferredWidth > 0
                opacity: surface.padlockShown ? 1 : 0
                Layout.preferredWidth: surface.padlockShown ? implicitWidth : 0
                closed: surface.padlockClosed && !surface.lock.unlocking

                Behavior on Layout.preferredWidth {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }

                }

            }

            Text {
                id: islandLabel

                visible: Layout.preferredWidth > 0
                Layout.preferredWidth: island.expanded && surface.padlockShown ? implicitWidth : 0
                Layout.leftMargin: island.expanded && surface.padlockShown ? 10 : 0
                clip: true
                text: surface.islandMode === "unlocking" ? "Unlocked" : surface.islandMode === "locking" ? "Locked" : surface.lock.error
                color: surface.islandMode === "error" ? "#f38ba8" : "#cba6f7"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
                font.weight: Font.Bold

                Behavior on Layout.preferredWidth {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on Layout.leftMargin {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }

                }

            }

            // The bar's OSD, its width opening and closing like the other parts.
            Item {
                visible: Layout.preferredWidth > 0
                Layout.preferredWidth: surface.islandMode === "osd" ? osdLoader.implicitWidth : 0
                implicitHeight: osdLoader.implicitHeight
                clip: true

                Loader {
                    id: osdLoader

                    anchors.verticalCenter: parent.verticalCenter
                    active: surface.bar !== null

                    sourceComponent: IslandOsd {
                        bar: surface.bar
                        visible: surface.bar.statusOsdVisible
                    }

                }

                Behavior on Layout.preferredWidth {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }

                }

            }

            // Another OSD over the one shown: its content fades in like in the bar.
            Connections {
                function onStatusOsdLabelChanged() {
                    if (surface.islandMode === "osd")
                        islandFade.restart();

                }

                target: surface.bar
            }

            Connections {
                function onFailed() {
                    shakeAnimation.restart();
                }

                target: surface.lock
            }

            // Like the bar's OSDs, new content fades in once the island is ~90% open so the
            // edges don't clip it. Between two padlock states only the text fades.
            Connections {
                function onIslandModeChanged() {
                    const padlockKept = ["clock", "osd"].indexOf(island.previousMode) < 0 && surface.padlockShown;
                    island.previousMode = surface.islandMode;
                    islandFade.stop();
                    labelFade.stop();
                    if (padlockKept)
                        labelFade.restart();
                    else
                        islandFade.restart();
                }

                target: surface
            }

            SequentialAnimation {
                id: labelFade

                PropertyAction {
                    target: islandLabel
                    property: "opacity"
                    value: 0
                }

                PauseAnimation {
                    duration: 110
                }

                NumberAnimation {
                    target: islandLabel
                    property: "opacity"
                    to: 1
                    duration: 140
                    easing.type: Easing.OutCubic
                }

            }

            SequentialAnimation {
                id: islandFade

                PropertyAction {
                    target: island
                    property: "contentOpacity"
                    value: 0
                }

                PauseAnimation {
                    duration: 110
                }

                NumberAnimation {
                    target: island
                    property: "contentOpacity"
                    to: 1
                    duration: 140
                    easing.type: Easing.OutCubic
                }

            }

            SequentialAnimation {
                id: shakeAnimation

                loops: 2

                NumberAnimation {
                    target: island
                    property: "shake"
                    to: -9
                    duration: 50
                    easing.type: Easing.OutQuad
                }

                NumberAnimation {
                    target: island
                    property: "shake"
                    to: 9
                    duration: 90
                    easing.type: Easing.InOutQuad
                }

                NumberAnimation {
                    target: island
                    property: "shake"
                    to: 0
                    duration: 50
                    easing.type: Easing.InQuad
                }

            }

            Behavior on horizontalPadding {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }

            }

            Behavior on implicitHeight {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }

            }

            Behavior on centerY {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }

            }

        }

        // Status only, where the bar has it: the control center does not open while locked.
        Pill {
            readonly property var start: surface.from !== null ? surface.from.control : null

            x: start !== null ? surface.between(start.x, surface.width - 24 - width) : surface.width - 24 - width
            y: start !== null ? start.y : 6
            visible: surface.bar !== null

            // Created once the screen's bar is known.
            Loader {
                active: surface.bar !== null

                sourceComponent: ControlStatus {
                    bar: surface.bar
                }

            }

        }

        // The date and time in the middle, the date as wide as the time. Hours in mauve,
        // minutes in glass like the pills: see-through over the blur, with the glass rim.
        Item {
            id: clockBlock

            // With the player under it, one block centered on the screen.
            readonly property real blockHeight: height + (playerBlock.visible ? playerBlock.anchors.topMargin + playerBlock.height : 0)

            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round((surface.height - blockHeight) / 2)
            width: timeRow.implicitWidth
            height: dateText.height + timeRow.implicitHeight
            opacity: surface.stage(0.35, 0.85)

            // The player shows or goes: the block moves to stay centered.
            Behavior on y {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }

            }

            Text {
                id: dateText

                readonly property var locale: surface.bar !== null ? surface.bar.regionalLocale : Qt.locale()
                readonly property string day: locale.toString(clock.date, "dddd d MMMM")

                width: parent.width
                text: day.charAt(0).toUpperCase() + day.slice(1)
                color: "#b4befe"
                horizontalAlignment: Text.AlignHCenter
                font.family: "JetBrainsMono Nerd Font"
                // As wide as the time: measured at 40px, then scaled to its width.
                font.pixelSize: Math.max(12, Math.floor(40 * parent.width / Math.max(1, dateMetrics.advanceWidth)))
                font.weight: Font.DemiBold

                TextMetrics {
                    id: dateMetrics

                    text: dateText.text
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 40
                    font.weight: Font.DemiBold
                }

            }

            Row {
                id: timeRow

                y: dateText.height

                Text {
                    text: Qt.formatDateTime(clock.date, "HH")
                    color: "#cba6f7"
                    font: minutesText.font
                }

                Item {
                    id: minutes

                    width: minutesText.implicitWidth
                    height: minutesText.implicitHeight

                    // The minutes' glyphs, white, for the masks.
                    Item {
                        id: glyphs

                        anchors.fill: parent
                        visible: false
                        layer.enabled: true

                        Text {
                            id: minutesText

                            text: Qt.formatDateTime(clock.date, ":mm")
                            color: "white"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 150
                            font.weight: Font.Bold
                            font.features: {
                                "tnum": 1
                            }
                        }

                    }

                    // The glyphs blurred a little: what stays opaque is their inside,
                    // without the edges.
                    Item {
                        id: glyphsInner

                        anchors.fill: parent
                        visible: false
                        layer.enabled: true

                        MultiEffect {
                            anchors.fill: parent
                            source: glyphs
                            autoPaddingEnabled: false
                            blurEnabled: true
                            blur: 0.08
                            blurMax: 16
                        }

                    }

                    // The base, translucent: the blurred background shows through.
                    Rectangle {
                        id: fillLight

                        anchors.fill: parent
                        visible: false
                        layer.enabled: true

                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.5)
                            }

                            GradientStop {
                                position: 1
                                color: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.32)
                            }

                        }

                    }

                    // GlassSurface's rim.
                    Rectangle {
                        id: rimLight

                        anchors.fill: parent
                        visible: false
                        layer.enabled: true

                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: Qt.rgba(205 / 255, 214 / 255, 244 / 255, 0.38)
                            }

                            GradientStop {
                                position: 0.45
                                color: Qt.rgba(205 / 255, 214 / 255, 244 / 255, 0.06)
                            }

                            GradientStop {
                                position: 1
                                color: Qt.rgba(205 / 255, 214 / 255, 244 / 255, 0.16)
                            }

                        }

                    }

                    // The rim's light inside the glyphs only.
                    Item {
                        id: rimInGlyphs

                        anchors.fill: parent
                        visible: false
                        layer.enabled: true

                        MultiEffect {
                            anchors.fill: parent
                            source: rimLight
                            maskEnabled: true
                            maskSource: glyphs
                            // Keeps the glyphs' smooth edges: alpha eases from 0 to 1 rather than
                            // being cut at a threshold (smoothstep from min·(1+spread)−spread
                            // to min·(1+spread)).
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1
                        }

                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: fillLight
                        maskEnabled: true
                        maskSource: glyphs
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1
                    }

                    // The rim: where the blurred glyphs fade, along their edges.
                    MultiEffect {
                        anchors.fill: parent
                        source: rimInGlyphs
                        maskEnabled: true
                        maskSource: glyphsInner
                        maskInverted: true
                        maskThresholdMin: 0.85
                        maskSpreadAtMin: 0.15
                    }

                }

            }

            transform: Translate {
                y: -20 * (1 - surface.stage(0.35, 0.85))
            }

        }

        // The player under the time, its lyrics beside it.
        Item {
            id: playerBlock

            // Kept while the next track's lyrics load, so the player only moves for a track
            // that has none, not every time lyrics are looked up.
            property bool lyricsShown: lockPlayer.lyricsFound

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: clockBlock.bottom
            anchors.topMargin: 110
            width: lockPlayer.width + (lyricsShown ? 40 + lockLyrics.width : 0)
            height: lockPlayer.height
            // Waits to know where the track is: a fresh card starts at 0:00 with its lyrics
            // at the top until playerctl answers, which would jump right after waking.
            visible: lockPlayer.player !== null && lockPlayer.positionKnown
            opacity: surface.stage(0.45, 1)
            scale: 0.96 + 0.04 * surface.stage(0.45, 1)

            // Checked a moment later: the lines go just before the next ones are asked for.
            Timer {
                id: lyricsGone

                interval: 100
                onTriggered: {
                    if (!lockPlayer.lyricsFound && !lockPlayer.lyricsLoading)
                        playerBlock.lyricsShown = false;

                }
            }

            Connections {
                function onLyricsFoundChanged() {
                    if (lockPlayer.lyricsFound)
                        playerBlock.lyricsShown = true;
                    else
                        lyricsGone.restart();
                }

                function onLyricsLoadingChanged() {
                    lyricsGone.restart();
                }

                target: lockPlayer
            }

            MediaPlayerCard {
                id: lockPlayer

                width: 380
                lyricsInside: false
                active: player !== null
                player: surface.bar !== null ? surface.bar.spotifyPlayer : null
                backgroundColor: Qt.rgba(30 / 255, 30 / 255, 46 / 255, 0.55)
            }

            LyricsView {
                id: lockLyrics

                anchors.left: lockPlayer.right
                anchors.leftMargin: 40
                anchors.verticalCenter: lockPlayer.verticalCenter
                width: 460
                height: 280
                visible: opacity > 0
                // On a skip, fades out once the lines have slid away and back in with the
                // next ones, keeping its place.
                opacity: lockPlayer.lyricsFound || lockLyrics.leaving ? 1 : 0
                active: lockPlayer.active && playerBlock.lyricsShown
                ready: lockPlayer.positionKnown
                lines: lockPlayer.lyricsFound ? Lyrics.lines : []
                synced: Lyrics.synced
                current: lockPlayer.lyricsLine
                creditColor: "#bac2de"
                onSeekRequested: (seconds) => {
                    if (lockPlayer.player !== null && lockPlayer.player.canSeek)
                        lockPlayer.seek(seconds);

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 220
                    }

                }

            }

            Behavior on width {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }

            }

            transform: Translate {
                y: 24 * (1 - surface.stage(0.45, 1))
            }

        }

        // The password field, same as the SDDM picker's, only shown while typing.
        Rectangle {
            id: prompt

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 120
            width: 300
            height: 44
            radius: 22
            color: "transparent"
            visible: opacity > 0
            opacity: surface.promptShown ? 1 : 0
            scale: surface.promptShown ? 1 : 0.92

            GlassSurface {
                radius: parent.radius
                backgroundColor: Qt.rgba(30 / 255, 30 / 255, 46 / 255, 0.6)
                focused: input.activeFocus
            }

            Text {
                id: promptIcon

                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: surface.lock.authenticating ? "󰔟" : "󰌾"
                color: "#cba6f7"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
            }

            // Always focused, even hidden: the first key typed shows the prompt.
            TextInput {
                id: input

                anchors.left: promptIcon.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                focus: true
                // The surface gets the keyboard once it is shown: the input takes it then.
                Component.onCompleted: forceActiveFocus()
                readOnly: surface.lock.authenticating || surface.lock.unlocking
                // Spaced filled squares and a blinking block cursor, like the SDDM picker.
                echoMode: TextInput.Password
                passwordCharacter: "■"
                color: "#cba6f7"
                selectionColor: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.35)
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                font.letterSpacing: 3
                clip: true
                cursorDelegate: Item {
                }
                onTextEdited: surface.lock.password = text
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                        surface.lock.submit();
                    else if (event.key === Qt.Key_Escape)
                        surface.lock.password = "";
                    else
                        return ;
                    event.accepted = true;
                }

                // Typed on another screen, or cleared after a try.
                Connections {
                    function onPasswordChanged() {
                        if (input.text !== surface.lock.password)
                            input.text = surface.lock.password;

                    }

                    target: surface.lock
                }

                BlockCursor {
                    input: input
                }

            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutBack
                }

            }

        }

    }

}
