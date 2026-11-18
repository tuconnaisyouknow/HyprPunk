import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.config
import qs.modules.bar
import qs.modules.island
import qs.modules.music
import qs.services
import qs.state
import qs.theme

// The lock screen on one display: a slimmed-down bar, the clock with the player, and the
// island, where you type your password.
//
// The lock starts from the screen exactly as it was, nothing moving. From its second
// frame (the first comes late, while the shell builds it and Hyprland shows it), the time
// leaves the island and grows into the clock in the middle, the bar's pills leave, move
// or stay, and everything blurs into the wallpaper. A padlock opens in the island in the
// time's place, the notifications leave with the time, the privacy dot and the recording
// stay, and your password comes as dots in the padlock's place. Unlocking plays it all
// backwards: the padlock gives the time its place back, the clock flies home into it and
// becomes the island's time again, and the lock hands the island over to a relay that
// shows it as the lock goes (Lock.relay). With the animation off, only the island moves.
WlSessionLockSurface {
    id: surface

    // This screen's bar, for where its pills were and the OSD it shows.
    readonly property var bar: ShellState.forScreen(screen)?.bar ?? null
    // Where the bar's pills were when locking (Bar.lockGeometry), null until known.
    property var from: null
    // 0 is the screen as it was, 1 the lock fully in place.
    property real reveal: Lock.instant || Lock.still ? 1 : 0
    // 0 = the pills where the bar has them, 1 = where the lock has them.
    property real morph: Lock.instant || Lock.still ? 1 : 0
    // 0 = the time in the island, 1 = the clock in the middle.
    property real flight: Lock.instant || Lock.still ? 1 : 0
    // Where the time sits in the island, which the clock leaves from and heads back to.
    property rect flightHome: Qt.rect(0, 0, 0, 0)
    // The music wave stands: it rises as the time leaves the island, and settles before
    // anything moves once the password is right.
    property bool waveUp: Lock.instant || Lock.still
    // The time out of the island: the clock has it. Already for sleep.
    property bool timeAway: Lock.instant
    // Past its first frame: laid out at its size, so what follows a change eases to it.
    property bool drawn: false
    // As good as gone, for what has layers: at no opacity Qt takes an item out of the
    // scene, and building it back mid-animation (the minutes' glass, the player's cover
    // and lyrics) drops a frame. Kept at this, they're built with the first frame, which
    // comes late anyway, and show nothing: under half a level of any color.
    readonly property real unseen: 0.0015
    // The island is busy with your password: typed, checked, refused or right.
    readonly property bool answering: Lock.password !== "" || Lock.authenticating || Lock.error !== "" || Lock.unlocking
    // The bar's OSDs (volume, brightness, battery...) show in the island too, once the time
    // has left it and while it has nothing to answer.
    readonly property bool osdShown: bar !== null && bar.osdVisible && timeAway && !answering

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

    // The smoothstep of a share of the way between from and to.
    function ease(value, from, to) {
        return smooth(Math.max(0, Math.min(1, (value - from) / (to - from))));
    }

    // The lock's own moves, once it draws smoothly: the time leaves the island.
    function start() {
        timeAway = true;
        if (Lock.still)
            return ;

        const time = islandView.item !== null ? islandView.item.timeItem : null;
        if (time !== null) {
            const at = time.mapToItem(content, 0, 0);
            flightHome = Qt.rect(at.x, at.y, time.width, time.height);
            flightIn.start();
        } else {
            flight = 1;
        }
        revealIn.start();
        morphIn.start();
        waveUp = true;
    }

    // The island has its time back, squeezed under it: it goes to its relay as the lock
    // shows it.
    function handOver() {
        if (!island.visible) {
            Lock.relay(screen.name, null, Qt.rect(0, 0, 0, 0));
            return ;
        }
        const ratio = scene.Screen.devicePixelRatio;
        // Squeezed around its middle, as it shows.
        const rect = Qt.rect(island.x + island.width * (1 - island.scale) / 2, island.y + island.height * (1 - island.scale) / 2, island.width * island.scale, island.height * island.scale);
        const size = Qt.size(Math.ceil(rect.width * ratio), Math.ceil(rect.height * ratio));
        islandSpot.width = rect.width;
        islandSpot.height = rect.height;
        islandSpot.sourceRect = rect;
        islandSpot.textureSize = size;
        islandSpot.scheduleUpdate();
        const grabbing = islandSpot.grabToImage((shot) => {
            return Lock.relay(screen.name, shot, rect);
        }, size);
        // Without its frame, the bar shows the padlock a moment as the lock goes.
        if (!grabbing)
            Lock.relay(screen.name, null, rect);
    }

    // Straight to the lock fully shown, for sleep.
    function settle() {
        revealIn.stop();
        morphIn.stop();
        flightIn.stop();
        timeAway = true;
        reveal = 1;
        morph = 1;
        flight = 1;
        waveUp = true;
    }

    // What the blurs blur has changed: they're drawn again once, the screen's first.
    function redrawBlurs() {
        for (const level of [sharpLevel, softLevel, midLevel, heavyLevel, wallpaperLevel, barLevel])
            level.scheduleUpdate();
    }

    function freeze() {
        if (from === null && bar !== null)
            from = bar.lockGeometry();

    }

    color: Colors.crust
    onBarChanged: freeze()
    onFromChanged: redrawBlurs()
    onWidthChanged: redrawBlurs()
    onHeightChanged: redrawBlurs()
    Component.onCompleted: freeze()

    // One of the lock's blurs (see sharpLevel): what it blurs, drawn once into a texture
    // `shrink` times smaller than the screen.
    component BlurLevel: ShaderEffectSource {
        property alias source: effect.source
        property alias blurMax: effect.blurMax
        property alias blurMultiplier: effect.blurMultiplier
        property alias brightness: effect.brightness
        property int shrink: 1

        anchors.fill: parent
        textureSize: Qt.size(Math.ceil(width / shrink), Math.ceil(height / shrink))
        sourceItem: effect
        live: false
        visible: false

        MultiEffect {
            id: effect

            width: parent.width
            height: parent.height
            visible: false
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
        }

    }

    // Ticks every second though it shows minutes: its timer stands still during sleep,
    // so on waking it would keep the old time up to a minute.
    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    // The first frame comes late (~100 ms) and before the surface has its size: a move
    // started with it would skip its start. The second one comes on time, and the lock
    // moves from there.
    FrameAnimation {
        id: firstFrame

        running: true
        onTriggered: {
            if (currentFrame < 2)
                return ;

            stop();
            surface.drawn = true;
            // Unless sleep or the password came first.
            if (!Lock.instant && !Lock.unlocking)
                surface.start();

        }
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

    NumberAnimation {
        id: flightIn

        target: surface
        property: "flight"
        to: 1
        duration: Motion.clockFlight.duration
        easing.type: Motion.clockFlight.easing
        easing.overshoot: Motion.clockFlight.overshoot
    }

    // Locking's moves the other way: the screen clears while the pills move (the blur's
    // long, unseen tail would hold back the desktop and its wave, which only come back
    // once the screens unlock), and the clock flies home into the time's place. It becomes
    // the island's time as it lands. The island gives under it, and goes to the bar
    // squeezed, which springs it back (IslandPill).
    SequentialAnimation {
        id: revealOut

        // The music wave lies flat first, as the desktop's did before locking: the
        // desktop's lies flat under the lock, which shows it as the lock goes.
        PauseAnimation {
            duration: Lock.music.playing && MusicSettings.wave ? Motion.waveSettle : 0
        }

        ParallelAnimation {
            NumberAnimation {
                target: surface
                property: "reveal"
                to: 0
                duration: morphIn.duration
                easing.type: revealIn.easing.type
            }

            NumberAnimation {
                target: surface
                property: "morph"
                to: 0
                duration: morphIn.duration
                easing.type: morphIn.easing.type
            }

            // A beat for the time's place to open before the clock heads for it.
            SequentialAnimation {
                PauseAnimation {
                    duration: 200
                }

                NumberAnimation {
                    target: surface
                    property: "flight"
                    to: 0
                    duration: Motion.clockReturn.duration
                    easing.type: Motion.clockReturn.easing
                }

            }

        }

        ScriptAction {
            script: {
                surface.timeAway = false;
                island.squeezed = true;
            }
        }

        PauseAnimation {
            duration: Motion.bounce.pressDuration
        }

        ScriptAction {
            script: surface.handOver()
        }

    }

    // Without the animation, only the island plays its way out: the time comes back in
    // the padlock's place, and the island gives under it.
    SequentialAnimation {
        id: stillOut

        PauseAnimation {
            duration: Motion.swap.duration
        }

        ScriptAction {
            script: {
                surface.timeAway = false;
                island.squeezed = true;
            }
        }

        PauseAnimation {
            duration: Motion.bounce.pressDuration
        }

        ScriptAction {
            script: surface.handOver()
        }

    }

    Connections {
        function onUnlockingChanged() {
            if (!Lock.unlocking)
                return ;

            revealIn.stop();
            morphIn.stop();
            flightIn.stop();
            // Into the time's place, wherever it is as the island moves back and opens it.
            const view = islandView.item;
            if (view !== null) {
                surface.flightHome = Qt.binding(() => {
                    const time = view.timeItem;
                    // Read so the place follows the island moving and resizing.
                    const moved = island.x + island.width + view.timeX;
                    // Its middle, which its part grows around.
                    const middle = time.mapToItem(content, time.width / 2, time.height / 2);
                    return Qt.rect(middle.x - time.width / 2, middle.y - time.height / 2, time.width, time.height);
                });
            }
            if (Lock.still)
                stillOut.restart();
            else
                revealOut.restart();
            surface.waveUp = false;
            // The lock already showed the OSD. Gone now, so the bar's island doesn't
            // open for it once the lock is gone.
            if (surface.bar !== null && surface.bar.osdVisible)
                Osd.dismiss();

        }

        function onSettled() {
            if (!Lock.unlocking)
                surface.settle();

        }

        target: Lock
    }

    // The wallpaper as Hyprland blurs it under the bar (looknfeel.lua's blur, matched
    // against recordings of the bar), seen through the lock's pills: over the plain
    // wallpaper, their see-through glass would change the moment the lock takes over.
    MultiEffect {
        id: barBlur

        anchors.fill: parent
        source: wallpaper
        visible: false
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1
        blurMax: 24
        brightness: -0.015
        saturation: 0.2
    }

    // None without the animation: nothing blurs out of the screen as it was.
    Image {
        id: snapshot

        anchors.fill: parent
        source: !Lock.still && Lock.snapshotFor(surface.screen) !== "" ? "file://" + Lock.snapshotFor(surface.screen) : ""
        cache: false
        visible: false
        onStatusChanged: surface.redrawBlurs()
    }

    Image {
        id: wallpaper

        anchors.fill: parent
        source: Session.wallpaper !== "" ? "file://" + Session.wallpaper : ""
        sourceSize.width: surface.width
        sourceSize.height: surface.height
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
        onStatusChanged: surface.redrawBlurs()
    }

    // The screen as it was, with the bar's pills painted over by the wallpaper: the lock
    // draws its own, so no ghost of them is left blurring in the background. Only where
    // they were: the wallpaper as Qt scales it isn't Hyprland's to the pixel, so the bar's
    // strip around them stays the snapshot's, the same as the screen when the lock goes.
    Item {
        id: frozenScreen

        anchors.fill: parent
        visible: false

        ShaderEffectSource {
            anchors.fill: parent
            sourceItem: snapshot
        }

        Repeater {
            model: surface.from !== null && snapshot.status === Image.Ready ? [surface.from.monitor, surface.from.island, surface.from.control].concat(surface.from.others).filter((pill) => {
                return pill !== null;
            }) : []

            ClippingRectangle {
                id: pillHole

                required property var modelData

                x: modelData.x
                y: modelData.y
                width: modelData.width
                height: modelData.height
                radius: modelData.radius
                color: "transparent"

                ShaderEffectSource {
                    anchors.fill: parent
                    sourceItem: wallpaper
                    sourceRect: Qt.rect(pillHole.x, pillHole.y, pillHole.width, pillHole.height)
                }

            }

        }

    }

    // The blurs, drawn once as the lock comes and again only when what they blur changes
    // (redrawBlurs): left live, Qt drew them all again on every frame and the animation
    // dropped some. The screen as it was, blurred three times wider each time, and the
    // wallpaper as the lock shows it. Blurred, they lose nothing at half or a quarter of
    // the screen's size.
    ShaderEffectSource {
        id: sharpLevel

        anchors.fill: parent
        sourceItem: frozenScreen
        live: false
        visible: false
    }

    BlurLevel {
        id: softLevel

        source: sharpLevel
        blurMax: 12
        shrink: 2
    }

    BlurLevel {
        id: midLevel

        source: sharpLevel
        blurMax: 32
        shrink: 4
    }

    // Wider than the wallpaper's: the windows' shapes are gone before it comes.
    BlurLevel {
        id: heavyLevel

        source: sharpLevel
        blurMax: 64
        blurMultiplier: 1.5
        shrink: 4
    }

    BlurLevel {
        id: wallpaperLevel

        source: wallpaper
        blurMax: 64
        brightness: -0.12
        shrink: 4
    }

    ShaderEffectSource {
        id: barLevel

        anchors.fill: parent
        sourceItem: barBlur
        live: false
        visible: false
    }

    // The island's spot of all the lock shows, drawn only as it's handed over
    // (handOver): the relay gets that much, not the whole screen. Under the scene, which
    // hides it.
    ShaderEffectSource {
        id: islandSpot

        sourceItem: scene
        live: false
    }

    // All the lock shows, in one item: what the island is handed over from (islandSpot).
    Item {
        id: scene

        anchors.fill: parent

        // The background, in one pass over the screen: only the mix of the blurs changes as
        // it moves (shaders/lockbackdrop.frag). Under the pills the lock keeps, the bar's
        // blur shows through their glass, under the wallpaper as it comes in: over the screen
        // blurring out, their glass would let the windows through while the bar's other pills
        // keep the bar's blur. In neon, a wrong password glitches it while the island shakes its head.
        ShaderEffect {
            id: backdrop

            // Through the glitch, from 0 to 1: a new pattern with each of the shake's
            // swings, each weaker than the last.
            property real glitchPhase: 1
            readonly property int glitchStep: Math.floor(glitchPhase * Motion.shake.swings.length)
            readonly property real glitch: glitchPhase < 1 ? 1 - glitchStep / Motion.shake.swings.length : 0
            readonly property real glitchSeed: glitchStep + 1
            readonly property color glitchColor: Colors.red
            readonly property vector2d size: Qt.vector2d(width, height)
            readonly property real blur: surface.smooth(surface.stage(0, 0.55))
            readonly property real dim: surface.stage(0, 0.55)
            readonly property real wall: wallpaper.status === Image.Ready ? surface.smooth(surface.stage(0.25, 1)) : 0
            readonly property real zoom: 1.04 - 0.04 * surface.stage(0.25, 1)
            readonly property vector4d pill0: Qt.vector4d(resourcesPill.x, resourcesPill.y, resourcesPill.width, resourcesPill.height)
            // Squeezed too, around its middle, as the time lands.
            readonly property vector4d pill1: Qt.vector4d(island.x + island.width * (1 - island.scale) / 2, island.y + island.height * (1 - island.scale) / 2, island.width * island.scale, island.height * island.scale)
            readonly property vector4d pill2: Qt.vector4d(controlPill.x, controlPill.y, controlPill.width, controlPill.height)
            readonly property vector3d pillOpacity: Qt.vector3d(resourcesPill.visible ? resourcesPill.opacity : 0, island.visible ? island.opacity : 0, controlPill.visible ? controlPill.opacity : 0)
            readonly property var sharp: sharpLevel
            readonly property var soft: softLevel
            readonly property var mid: midLevel
            readonly property var heavy: heavyLevel
            readonly property var wallpaperBlur: wallpaperLevel
            readonly property var pillBlur: barLevel

            anchors.fill: parent
            fragmentShader: Qt.resolvedUrl(Quickshell.shellPath("shaders/lockbackdrop.frag.qsb"))

            Connections {
                // Neon only: the machine awake faults, the dream just shakes its head.
                function onFailed() {
                    if (Session.theme === "neon")
                        glitchAnimation.restart();

                }

                target: Lock
            }

            NumberAnimation {
                id: glitchAnimation

                target: backdrop
                property: "glitchPhase"
                from: 0
                to: 1
                duration: Motion.shake.swings.length * Motion.shake.swingDuration
            }

        }

        // The music wave, where the desktop's was (VisualizerShell.qml): that one settled into the
        // floor before the screen froze, this one rises as the time leaves the island, past the
        // moments the shell stalls building the lock. Unlocking mirrors it: it settles before the
        // lock plays its way out, then the desktop's rises once unlocked. Both move the same way.
        VisualizerWave {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(parent.width * 0.5)
            height: 110
            visible: MusicSettings.wave
            music: Lock.music
            presence: surface.waveUp ? 1 : 0

            Behavior on presence {
                NumberAnimation {
                    duration: Motion.waveSettle
                    easing.type: Easing.InOutCubic
                }

            }

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
                id: resourcesPill

                readonly property var start: surface.from !== null ? surface.from.monitor : null

                x: start !== null ? surface.between(start.x, Metrics.barMargin) : Metrics.barMargin
                y: start !== null ? start.y : 6
                visible: surface.bar !== null && surface.width >= 1200
                // Not in the bar (a narrow screen): it fades in instead.
                opacity: start !== null ? 1 : surface.morph

                IconText {
                    icon: ""
                    text: SystemStats.memoryText
                }

                IconText {
                    icon: ""
                    text: Math.round(SystemStats.cpuUsage * 100) + "%"
                }

            }

            // The island, the bar's as it was: the time leaves it for the clock with the
            // notifications and a padlock takes its place, the privacy dot and the recording
            // stay, and your password replaces the padlock as dots, or an OSD takes it over.
            // It moves to the middle and back with the other pills, and shakes its head at a
            // wrong password.
            Pill {
                id: island

                readonly property real startCenter: surface.from !== null ? surface.from.island.x + surface.from.island.width / 2 : surface.width / 2
                property real shake: 0
                // Under the time landing back, by as much as the bar's (IslandPill).
                property bool squeezed: false

                // Even, like the bar's, so its content lands on the same pixels.
                width: 2 * Math.round(implicitWidth / 2)
                height: 2 * Math.round(implicitHeight / 2)
                x: surface.between(startCenter, surface.width / 2) - width / 2 + shake
                // Hung from the bar's line, like the bar's island: it grows downwards.
                y: Metrics.barTop
                visible: surface.bar !== null
                horizontalPadding: 0
                implicitHeight: islandView.item !== null ? islandView.item.implicitHeight : Metrics.pillHeight
                scale: squeezed ? Motion.squeeze(width) : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Motion.bounce.pressDuration
                        easing.type: Motion.bounce.pressEasing
                    }

                }

                Loader {
                    id: islandView

                    active: surface.bar !== null

                    sourceComponent: IslandView {
                        id: lockIslandView

                        bar: surface.bar
                        face: surface.osdShown ? "osd" : "clock"
                        // Its place opens again as you're let in, the clock flying home to it.
                        timeShown: !surface.timeAway || Lock.unlocking
                        chipsShown: true
                        padlock: surface.timeAway && !Lock.unlocking && Lock.password === "" && !Lock.authenticating
                        // The clock carries it out, but without the animation.
                        timeLifted: surface.timeAway && !Lock.still
                        interactive: false
                        date: clock.date
                        typed: Lock.password.length
                        checking: Lock.authenticating
                        lockError: Lock.error

                        // Another OSD over the one shown.
                        Connections {
                            function onOsdLabelChanged() {
                                if (surface.osdShown)
                                    lockIslandView.fadeOsd();

                            }

                            target: surface.bar
                        }

                    }

                }

                // A wrong password: the island shakes its head, like a field would.
                Connections {
                    function onFailed() {
                        shakeAnimation.restart();
                    }

                    target: Lock
                }

                Shake {
                    id: shakeAnimation

                    target: island
                    offsetProperty: "shake"
                }

            }

            // Status only, where the bar has it: the control center does not open while locked.
            Pill {
                id: controlPill

                readonly property var start: surface.from !== null ? surface.from.control : null

                x: start !== null ? surface.between(start.x, surface.width - Metrics.barMargin - width) : surface.width - Metrics.barMargin - width
                y: start !== null ? start.y : 6
                visible: surface.bar !== null

                ControlStatus {
                }

            }

            // The date and time in the middle, the date as wide as the time. Hours in the accent,
            // minutes in glass like the pills: see-through over the blur, with the glass rim.
            // The time flies here from the island and back, the date comes once it's landed.
            Item {
                id: clockBlock

                // With the player under it, one block centered on the screen.
                readonly property real blockHeight: height + (playerBlock.visible ? playerBlock.anchors.topMargin + playerBlock.height : 0)

                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round((surface.height - blockHeight) / 2)
                width: timeRow.implicitWidth
                height: dateText.height + timeRow.implicitHeight

                // The player shows or goes: the block moves to stay centered.
                Behavior on y {
                    enabled: surface.drawn

                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }

                }

                Text {
                    id: dateText

                    readonly property string day: Session.regionalFormats.toString(clock.date, "dddd d MMMM")
                    readonly property real shown: surface.ease(surface.flight, 0.8, 1)

                    width: parent.width
                    text: day.charAt(0).toUpperCase() + day.slice(1)
                    color: Colors.secondary
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Metrics.displayFont
                    // As wide as the time: measured at 40px, then scaled to its width.
                    font.pixelSize: Math.max(12, Math.floor(40 * parent.width / Math.max(1, dateMetrics.advanceWidth)))
                    font.weight: Font.Bold
                    font.capitalization: Font.AllUppercase
                    opacity: shown

                    TextMetrics {
                        id: dateMetrics

                        text: dateText.text
                        font.family: Metrics.displayFont
                        font.pixelSize: 40
                        font.weight: Font.Bold
                        font.capitalization: Font.AllUppercase
                    }

                    transform: Translate {
                        y: -12 * (1 - dateText.shown)
                    }

                }

                // The time, from the island's to its place here: shrunk to the island's time and
                // on it, growing as it goes. It sets off as the island's own time and turns into
                // the clock on the way, both as wide.
                Item {
                    id: timeBox

                    // Its size in the island, the island's time's width over its own.
                    readonly property real homeScale: surface.flightHome.width / Math.max(1, width)
                    readonly property real flightScale: homeScale > 0 ? Math.pow(homeScale, 1 - surface.flight) : 1
                    // From its place here to the island's time, middle to middle.
                    readonly property real homeX: surface.flightHome.x + surface.flightHome.width / 2 - (clockBlock.x + x + width / 2)
                    readonly property real homeY: surface.flightHome.y + surface.flightHome.height / 2 - (clockBlock.y + y + height / 2)

                    y: dateText.height
                    width: timeRow.implicitWidth
                    height: timeRow.implicitHeight
                    // Unseen while the island has the time: it's the island's own time from the
                    // moment it leaves to the moment it lands back (handOver).
                    opacity: surface.timeAway ? 1 : surface.unseen
                    transform: [
                        Scale {
                            origin.x: timeBox.width / 2
                            origin.y: timeBox.height / 2
                            xScale: timeBox.flightScale
                            yScale: timeBox.flightScale
                        },
                        Translate {
                            x: timeBox.homeX * (1 - surface.flight)
                            y: timeBox.homeY * (1 - surface.flight)
                        }
                    ]

                    Row {
                        id: timeRow

                        opacity: Math.max(surface.unseen, surface.ease(surface.flight, 0.05, 0.45))

                        Text {
                            id: hours

                            text: Session.hourText(clock.date)
                            color: Colors.primary
                            font: minutes.font
                        }

                        GlassText {
                            id: minutes

                            text: Qt.formatDateTime(clock.date, ":mm")
                            font.family: Metrics.displayFont
                            font.pixelSize: 150
                            font.weight: Font.Bold
                            font.features: {
                                "tnum": 1
                            }
                        }

                        // AM or PM in us, small on the digits' baseline.
                        Text {
                            visible: text !== ""
                            anchors.baseline: hours.baseline
                            leftPadding: 14
                            text: Session.meridiemText(clock.date)
                            color: Colors.secondary
                            font.family: Metrics.displayFont
                            font.pixelSize: 40
                            font.weight: Font.Bold
                        }

                    }

                    // The island's time as the island draws it, as wide as the clock: at the
                    // island's size, it's the island's time exactly.
                    Label {
                        anchors.centerIn: parent
                        text: Session.clockText(clock.date)
                        font.features: {
                            "tnum": 1
                        }
                        scale: timeBox.width / Math.max(1, implicitWidth)
                        opacity: 1 - surface.ease(surface.flight, 0, 0.35)
                        visible: opacity > 0
                    }

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
                // Never there when the settings keep what you listen to private.
                visible: LockSettings.player && lockPlayer.player !== null && Music.positionKnown
                opacity: Math.max(surface.unseen, surface.stage(0.45, 1))
                scale: 0.96 + 0.04 * surface.stage(0.45, 1)

                // Checked a moment later: the lines go just before the next ones are asked for.
                Timer {
                    id: lyricsGone

                    interval: 100
                    onTriggered: {
                        if (!lockPlayer.lyricsFound && !Music.lyricsLoading)
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

                    target: lockPlayer
                }

                Connections {
                    function onLyricsLoadingChanged() {
                        lyricsGone.restart();
                    }

                    target: Music
                }

                MediaPlayerCard {
                    id: lockPlayer

                    width: 380
                    lyricsInside: false
                    active: player !== null
                    player: LockSettings.player ? Music.player : null
                    backgroundColor: Colors.alpha(Colors.base, 0.55)
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
                    ready: Music.positionKnown
                    lines: lockPlayer.lyricsFound ? Lyrics.lines : []
                    synced: Lyrics.synced
                    current: lockPlayer.lyricsLine
                    creditColor: Colors.secondary
                    onSeekRequested: (seconds) => {
                        return Music.seek(seconds);
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

            // Takes the keys for the island's dots (PasswordDots), never drawn. Always focused:
            // the first key typed opens them.
            TextInput {
                id: input

                focus: true
                // The surface gets the keyboard once it is shown: the input takes it then.
                Component.onCompleted: forceActiveFocus()
                opacity: 0
                readOnly: Lock.authenticating || Lock.unlocking
                echoMode: TextInput.Password
                onTextEdited: Lock.password = text
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                        Lock.submit();
                    else if (event.key === Qt.Key_Escape)
                        Lock.password = "";
                    else
                        return ;
                    event.accepted = true;
                }

                // Typed on another screen, or cleared after a try.
                Connections {
                    function onPasswordChanged() {
                        if (input.text !== Lock.password)
                            input.text = Lock.password;

                    }

                    target: Lock
                }

            }

        }

    }

}
