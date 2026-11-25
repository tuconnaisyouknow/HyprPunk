import QtQuick
import QtQuick.Effects
import QtQuick.Window

// The login screen every theme shares: the lock screen over the theme's own video,
// before anyone's there. Who logs in on the left of the bar, the session and the power on
// the right, the island in the middle, where a padlock waits and your password comes as
// squares, and the time where the lock screen has it. sddm.sh copies it into
// each theme.
Rectangle {
    id: root

    // All is drawn at the shell's sizes, a 1080p screen's, and grows with the screen:
    // SDDM knows nothing of the scale Hyprland gives it.
    readonly property real zoom: Screen.height / 1080
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    readonly property QtObject user: users.count > 0 ? users.objectAt(userIndex) : null
    readonly property QtObject session: sessions.count > 0 ? sessions.objectAt(sessionIndex) : null
    // SDDM is checking the password.
    property bool checking: false
    // Told in the island after a failed try, "" otherwise.
    property string error: ""
    // Past its first frames: laid out, so what follows a change eases to it.
    property bool drawn: false
    property date now: new Date()
    // The clock follows the regional formats you picked for the desktop, any locale as
    // glibc names it: 12 h in en_US, 24 h in en_GB. Qt drops a variant (@latin) and takes
    // the language's own.
    readonly property var formats: Qt.locale(config.region || "en_US.UTF-8")
    readonly property bool twelveHour: /a/i.test(formats.timeFormat(Locale.ShortFormat))

    // The hour on its own, AM/PM being a text of its own. Done by hand: Qt only counts
    // to 12 in a format that shows AM/PM too.
    function hourText(date) {
        const hour = date.getHours();
        return twelveHour ? String(hour % 12 || 12) : String(hour).padStart(2, "0");
    }

    // "AM" or "PM" when the formats count to 12, nothing otherwise.
    function meridiemText(date) {
        if (!twelveHour)
            return "";

        return date.getHours() < 12 ? formats.amText : formats.pmText;
    }

    function submit() {
        if (input.text === "" || checking || user === null)
            return ;

        error = "";
        checking = true;
        sddm.login(user.name, input.text, sessionIndex);
    }

    // A wrong password: the island shakes its head and says why. In neon the video
    // glitches too, as the lock screen's background does: the machine awake faults, the
    // dream only says no.
    function refuse() {
        checking = false;
        input.text = "";
        error = "Access denied";
        refusal.restart();
        shakeAnimation.restart();
        if (Colors.emits)
            glitchAnimation.restart();

    }

    width: Screen.width
    height: Screen.height
    color: Colors.crust
    Component.onCompleted: keyboard.numLock = true

    // A pill holding one icon, a circle.
    component IconPill: Pill {
        id: iconPill

        property alias icon: glyph.text
        property alias ink: glyph.color

        width: height
        clickable: true

        // A whole, even number of pixels, the glyph on a whole pixel inside: an odd cell
        // alone in the circle would be drawn off the middle.
        Item {
            implicitWidth: 2 * Math.round(glyph.implicitWidth / 2)
            implicitHeight: glyph.implicitHeight

            Icon {
                id: glyph

                x: Math.round((parent.width - implicitWidth) / 2)
                color: iconPill.hovered ? Colors.primary : Colors.secondary

                Behavior on color {
                    ColorAnimation {
                        duration: Motion.color.duration
                        easing.type: Motion.color.easing
                    }

                }

            }

        }

    }

    // Restarting and shutting down ask for a second click, as in the shell's session
    // menu: the first one arms the pill, lit in red, for a few seconds or until the
    // pointer leaves it.
    component PowerPill: IconPill {
        id: powerPill

        property bool armed: false

        signal confirmed()

        ink: armed ? Colors.over(Colors.red) : hovered ? Colors.primary : Colors.secondary
        // Its halo reaches past the pill in neon.
        clip: false
        onHoveredChanged: {
            if (!hovered)
                armed = false;

        }
        onClicked: {
            if (armed)
                confirmed();
            else
                armed = true;
        }

        Timer {
            interval: Motion.armed
            running: powerPill.armed
            onTriggered: powerPill.armed = false
        }

        underlay: Light {
            anchors.fill: parent
            color: Colors.alpha(Colors.red, 0.9)
            opacity: powerPill.armed ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.color.duration
                    easing.type: Motion.color.easing
                }

            }

        }

    }

    // The shell's fonts, which sddm.sh copies next to the theme: SDDM can't read the ones
    // in your home. Each weight has its own file, so none is a thickened regular.
    FontLoader {
        source: "font/HyprPunkText-Regular.ttf"
    }

    FontLoader {
        source: "font/HyprPunkText-SemiBold.ttf"
    }

    FontLoader {
        source: "font/HyprPunkText-Bold.ttf"
    }

    FontLoader {
        source: "font/HyprPunkDisplay-Bold.ttf"
    }

    // Never shown, only there to read the users' and the sessions' names from SDDM.
    Instantiator {
        id: users

        model: userModel

        QtObject {
            required property string name
            required property string realName
        }

    }

    Instantiator {
        id: sessions

        model: sessionModel

        QtObject {
            required property string name
        }

    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Timer {
        id: refusal

        interval: Motion.refusal
        onTriggered: root.error = ""
    }

    Connections {
        function onLoginFailed() {
            root.refuse();
        }

        target: sddm
    }

    // The first frames come late, while SDDM builds the screen: a move started with them
    // would skip its start. Everything comes from the third one.
    FrameAnimation {
        running: true
        onTriggered: {
            if (currentFrame < 2)
                return ;

            stop();
            root.drawn = true;
            arrival.start();
        }
    }

    BackgroundVideo {
        id: background

        anchors.fill: parent
    }

    // The glitch tears a picture of the video, only taken while it plays.
    ShaderEffectSource {
        id: videoFrame

        anchors.fill: parent
        sourceItem: background
        live: glitchEffect.visible
        visible: false
    }

    ShaderEffect {
        id: glitchEffect

        // Through the glitch, from 0 to 1: a new pattern with each of the island's
        // swings, each weaker than the last.
        property real phase: 1
        readonly property int step: Math.floor(phase * Motion.shake.swings.length)
        readonly property real glitch: 1 - step / Motion.shake.swings.length
        readonly property real glitchSeed: step + 1
        readonly property color glitchColor: Colors.red
        readonly property vector2d size: Qt.vector2d(width, height)
        readonly property var source: videoFrame

        anchors.fill: parent
        visible: phase < 1
        fragmentShader: "glitch.frag.qsb"

        NumberAnimation {
            id: glitchAnimation

            target: glitchEffect
            property: "phase"
            from: 0
            to: 1
            duration: Motion.shake.duration
        }

    }

    Item {
        id: bar

        width: root.width / root.zoom
        height: root.height / root.zoom
        scale: root.zoom
        transformOrigin: Item.TopLeft

        // The video under the bar, blurred as Hyprland blurs the wallpaper under the
        // shell's pills (the lock screen's values).
        VideoBlur {
            id: barBlur

            width: parent.width
            height: Metrics.barHeight
            video: background
            zoom: root.zoom
            blurMax: 24
            brightness: -0.015
            saturation: 0.2
        }

        // And under the clock's minutes, blurred and dimmed as the lock screen has its
        // wallpaper.
        VideoBlur {
            id: clockBlur

            x: clockBlock.x + timeRow.x + minutes.x
            y: clockBlock.y + timeRow.y + minutes.y
            width: minutes.width
            height: minutes.height
            video: background
            zoom: root.zoom
            blurMax: 64
            brightness: -0.12
        }

        // Who logs in. With several users, a click goes to the next one.
        Pill {
            id: userPill

            x: Metrics.barMargin
            lift: Motion.drop.height
            backdrop: barBlur
            clickable: users.count > 1
            onClicked: root.userIndex = (root.userIndex + 1) % users.count

            Icon {
                text: "person"
            }

            Label {
                text: root.user !== null ? root.user.realName || root.user.name : ""
            }

            Behavior on width {
                enabled: root.drawn

                NumberAnimation {
                    duration: Motion.move.duration
                    easing.type: Motion.move.easing
                }

            }

        }

        // The island, the lock screen's: a padlock while the session is closed. Your
        // password replaces it as squares, and a wrong one makes it shake its head and say so.
        Pill {
            id: island

            property real shake: 0

            // Never narrower than tall: around the padlock alone, a circle.
            width: Math.max(implicitWidth, height)
            x: (bar.width - width) / 2 + shake
            lift: Motion.drop.height
            backdrop: barBlur
            spacing: 0

            // Grows two pixels at a time, the one thing rounded in the island: centred on
            // the screen, its content lands on whole pixels, and the parts follow their
            // exact place inside, so they glide instead of stepping back and forth.
            Item {
                implicitWidth: 2 * Math.round(islandRow.implicitWidth / 2)
                implicitHeight: islandRow.implicitHeight

                // Each part opens in the place of the one before it closes, and parts itself
                // from it by as much as it's still there.
                Row {
                    id: islandRow

                    x: (parent.width - width) / 2
                    anchors.verticalCenter: parent.verticalCenter

                    IslandPart {
                        id: padlockPart

                        shown: input.text === "" && !root.checking
                        openWidth: 2 * Math.round(padlock.implicitWidth / 2)
                        openHeight: padlock.implicitHeight

                        Icon {
                            id: padlock

                            x: Math.round((parent.width - implicitWidth) / 2)
                            text: "lock"
                        }

                    }

                    PasswordSquares {
                        id: squaresPart

                        gap: Metrics.spacing.normal * padlockPart.presence
                        count: input.text.length
                        checking: root.checking
                        alert: root.error !== "" && input.text === ""
                    }

                    // Why the try failed, in the machine's capitals: decoded once the shake is
                    // over, and kept while its place closes.
                    IslandPart {
                        id: words

                        property string label: ""

                        gap: Metrics.spacing.normal * Math.min(1, padlockPart.presence + squaresPart.presence)
                        shown: root.error !== ""
                        // Even, like every part's place.
                        openWidth: 2 * Math.ceil(wordsText.implicitWidth / 2)
                        openHeight: wordsText.implicitHeight

                        Connections {
                            function onErrorChanged() {
                                if (root.error !== "")
                                    words.label = root.error;

                            }

                            target: root
                        }

                        Text {
                            id: wordsText

                            text: words.label
                            color: decode.running ? "transparent" : Colors.red
                            font.family: Metrics.font
                            font.pixelSize: Metrics.text.body
                            font.weight: Font.Bold
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 1

                            Decode {
                                id: decode

                                color: Colors.red
                                wait: Motion.shake.duration
                            }

                        }

                    }

                }

            }

        }

        SequentialAnimation {
            id: shakeAnimation

            NumberAnimation {
                target: island
                property: "shake"
                to: Motion.shake.swings[0]
                duration: Motion.shake.swingDuration
            }

            NumberAnimation {
                target: island
                property: "shake"
                to: Motion.shake.swings[1]
                duration: Motion.shake.swingDuration
            }

            NumberAnimation {
                target: island
                property: "shake"
                to: Motion.shake.swings[2]
                duration: Motion.shake.swingDuration
            }

            NumberAnimation {
                target: island
                property: "shake"
                to: Motion.shake.swings[3]
                duration: Motion.shake.swingDuration
            }

        }

        // The session you log into. With several, a click goes to the next one.
        Pill {
            id: sessionPill

            x: restartPill.x - Metrics.spacing.normal - width
            lift: shutDownPill.lift
            backdrop: barBlur
            clickable: sessions.count > 1
            onClicked: root.sessionIndex = (root.sessionIndex + 1) % sessions.count

            Icon {
                text: "monitor"
            }

            Label {
                text: root.session !== null ? root.session.name : ""
            }

            Behavior on width {
                enabled: root.drawn

                NumberAnimation {
                    duration: Motion.move.duration
                    easing.type: Motion.move.easing
                }

            }

        }

        PowerPill {
            id: restartPill

            x: shutDownPill.x - Metrics.spacing.normal - width
            lift: shutDownPill.lift
            backdrop: barBlur
            icon: "restart_alt"
            onConfirmed: sddm.reboot()
        }

        PowerPill {
            id: shutDownPill

            x: bar.width - Metrics.barMargin - width
            lift: Motion.drop.height
            backdrop: barBlur
            icon: "power_settings_new"
            onConfirmed: sddm.powerOff()
        }

        // The time in the middle, as the lock screen draws it alone: the hours in the accent,
        // the minutes in glass like the pills, the digits centered on the screen.
        Item {
            id: clockBlock

            // How much the time is there as it comes.
            property real timeIn: 0
            // The digits from their top to the baseline: the font's line has room above and
            // below them, which would pull them off the middle.
            readonly property real inkTop: hours.baselineOffset + digitInk.tightBoundingRect.y
            readonly property real inkBottom: inkTop + digitInk.tightBoundingRect.height

            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round((bar.height - (inkBottom - inkTop)) / 2 - inkTop)
            width: timeRow.implicitWidth
            height: timeRow.implicitHeight
            opacity: timeIn
            scale: 0.96 + 0.04 * timeIn

            TextMetrics {
                id: digitInk

                text: "0123456789"
                font: minutes.font
            }

            Row {
                id: timeRow

                RollingText {
                    id: hours

                    text: root.hourText(root.now)
                    font: minutes.font
                    // After the minutes' two digits: they always turn from 59 to 00.
                    wait: 2 * Motion.stagger
                }

                GlassText {
                    id: minutes

                    backdrop: clockBlur
                    text: Qt.formatDateTime(root.now, ":mm")
                    font.family: Metrics.displayFont
                    font.pixelSize: 250
                    font.weight: Font.Bold
                    // Each digit as wide as the others, so the clock never shifts.
                    font.features: {
                        "tnum": 1
                    }
                }

            }

            // AM or PM when the formats count to 12, small on the digits' baseline. Out of
            // the row: the digits alone stand in the middle, as on the lock screen.
            Text {
                x: timeRow.width + 18
                y: hours.baselineOffset - baselineOffset
                visible: text !== ""
                text: root.meridiemText(root.now)
                color: Colors.secondary
                font.family: Metrics.displayFont
                font.pixelSize: 52
                font.weight: Font.Bold
            }

            transform: Translate {
                y: 24 * (1 - clockBlock.timeIn)
            }

        }

        // The pills fall into place, the island first, and the time comes.
        ParallelAnimation {
            id: arrival

            NumberAnimation {
                target: clockBlock
                property: "timeIn"
                to: 1
                duration: Motion.enter.duration
                easing.type: Motion.enter.easing
            }

            NumberAnimation {
                target: island
                property: "lift"
                to: 0
                duration: Motion.drop.fallDuration
                easing.type: Motion.drop.fallEasing
            }

            SequentialAnimation {
                PauseAnimation {
                    duration: Motion.stagger
                }

                NumberAnimation {
                    targets: [userPill, shutDownPill]
                    property: "lift"
                    to: 0
                    duration: Motion.drop.fallDuration
                    easing.type: Motion.drop.fallEasing
                }

            }

        }

        // Takes the keys for the island's squares, never drawn.
        TextInput {
            id: input

            focus: true
            opacity: 0
            readOnly: root.checking
            echoMode: TextInput.Password
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    root.submit();
                else if (event.key === Qt.Key_Escape)
                    input.text = "";
                else
                    return ;
                event.accepted = true;
            }

            // SDDM gives the screen the keyboard a moment after showing it: the input
            // takes it then.
            Timer {
                interval: 300
                running: true
                onTriggered: input.forceActiveFocus()
            }

        }

    }

}
