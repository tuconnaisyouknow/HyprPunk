import QtQuick
import QtQuick.Effects

// Lyrics the Apple Music way: big bold lines, the one being sung lit up near the top,
// the rest dimmer and blurrier the further away they are. Click a line to jump there;
// scroll by hand and it stops following for a moment.
// On a new track, the old lines slide up and fade, and the new ones rise into place
// one after another.
Item {
    id: view

    // [{"t": seconds, "text": "..."}], t is -1 for untimed lyrics.
    property var lines: []
    property bool synced: false
    // Index of the line being sung, -1 before the first one.
    property int current: -1
    // Off while the card is not shown: no blur layers, no follow animation.
    property bool active: true
    // The line being sung sits this far down the view.
    readonly property real anchorRatio: 0.3
    // Scrolled by hand: the view stops following until resumeFollow runs out.
    property bool handScrolled: false
    // The LRCLIB credit: dim on a card, brighter straight over a wallpaper.
    property color creditColor: "#6c7086"
    // False until the player's position is known, so the view can start right on the
    // current line instead of scrolling down to it from the top.
    property bool ready: true
    // Set once the view stands on a line; until then it goes there without scrolling.
    property bool placed: false
    // What the view shows: the lines change once the previous ones have left.
    property var shownLines: []
    property bool shownSynced: false
    property bool leaving: false
    // The line sung when the old lines started leaving, for them to keep their look.
    property int leavingCurrent: -1
    readonly property int shownCurrent: leaving ? leavingCurrent : current
    // The new lines are rising into place.
    property bool entering: false

    signal seekRequested(real seconds)

    function follow() {
        if (handScrolled || leaving || !ready || !shownSynced || shownLines.length === 0)
            return ;

        const line = current >= 0 ? lineRepeater.itemAt(current) : null;
        const wanted = line ? line.y - height * anchorRatio : 0;
        const target = Math.max(0, Math.min(wanted, flickable.contentHeight - height));
        if (!placed) {
            followAnimation.stop();
            flickable.contentY = target;
            placed = true;
            return ;
        }
        followAnimation.to = target;
        followAnimation.restart();
    }

    function show() {
        leaving = false;
        shownLines = lines;
        shownSynced = synced;
        handScrolled = false;
        placed = false;
        followAnimation.stop();
        flickable.contentY = 0;
        Qt.callLater(follow);
    }

    // Waits for both the lines and whether they're timed: Lyrics sets the lines first,
    // and showing them right away would lay them out untimed, then shuffle them again.
    function update() {
        // The same lines again (looked up once more): nothing moves.
        if (lines.length === shownLines.length && JSON.stringify(lines) === JSON.stringify(shownLines)) {
            if (!leaving)
                shownSynced = synced;

            return ;
        }

        // Nothing to see leave: straight in.
        if (!active || shownLines.length === 0) {
            leaveAnimation.stop();
            column.leave = 0;
            entering = active && lines.length > 0;
            if (entering)
                enterDone.restart();

            show();
            return ;
        }
        // A leave already running shows the latest lines once done.
        if (!leaving) {
            leavingCurrent = current;
            leaving = true;
            leaveAnimation.restart();
        }
    }

    onCurrentChanged: follow()
    onReadyChanged: Qt.callLater(follow)
    onLinesChanged: Qt.callLater(update)
    onSyncedChanged: Qt.callLater(update)
    onHeightChanged: Qt.callLater(follow)
    onActiveChanged: {
        if (active) {
            handScrolled = false;
            followAnimation.stop();
            Qt.callLater(follow);
        }
    }

    Flickable {
        id: flickable

        anchors.fill: parent
        contentHeight: column.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // The top and bottom lines fade out under the card's edges.
        layer.enabled: true
        onMovementStarted: {
            view.handScrolled = true;
            followAnimation.stop();
            resumeFollow.stop();
        }
        onMovementEnded: resumeFollow.restart()

        Column {
            id: column

            width: flickable.width
            topPadding: view.shownSynced ? view.height * view.anchorRatio : 12
            bottomPadding: view.height * (1 - view.anchorRatio)
            spacing: 14

            // Slides up and fades as the old lines leave.
            property real leave: 0

            opacity: 1 - leave

            transform: Translate {
                y: -20 * column.leave
            }

            Repeater {
                id: lineRepeater

                model: view.shownLines

                LyricLine {
                }

            }

            Text {
                width: column.width
                topPadding: 10
                // Not alone while the lines are looked for.
                visible: view.shownLines.length > 0
                text: view.shownSynced ? "Lyrics from LRCLIB" : "Not synced · Lyrics from LRCLIB"
                color: view.creditColor
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
            }

        }

        NumberAnimation on contentY {
            id: followAnimation

            running: false
            duration: 560
            easing.type: Easing.OutCubic
        }

        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: fadeMask
            maskThresholdMin: 0
            maskSpreadAtMin: 1
        }

    }

    SequentialAnimation {
        id: leaveAnimation

        NumberAnimation {
            target: column
            property: "leave"
            to: 1
            duration: 260
            easing.type: Easing.InCubic
        }

        ScriptAction {
            script: {
                column.leave = 0;
                view.entering = view.lines.length > 0;
                if (view.entering)
                    enterDone.restart();

                view.show();
            }
        }

    }

    // Once the last line has risen.
    Timer {
        id: enterDone

        interval: 900
        onTriggered: view.entering = false
    }

    Timer {
        id: resumeFollow

        interval: 3000
        onTriggered: {
            view.handScrolled = false;
            view.follow();
        }
    }

    // Opaque in the middle, transparent at the top and bottom edges.
    Item {
        id: fadeMask

        anchors.fill: flickable
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.fill: parent

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "transparent"
                }

                GradientStop {
                    position: 0.14
                    color: "black"
                }

                GradientStop {
                    position: 0.8
                    color: "black"
                }

                GradientStop {
                    position: 1
                    color: "transparent"
                }

            }

        }

    }

    component LyricLine: Text {
        id: line

        required property var modelData
        required property int index
        // Lines from the one being sung: 0 for it, 1 for its neighbours…
        readonly property int distance: view.shownSynced ? Math.abs(index - Math.max(0, view.shownCurrent)) : 0
        readonly property bool lit: view.shownSynced && index === view.shownCurrent
        // An empty timed line is a pause in the singing.
        readonly property bool pause: view.shownSynced && modelData.text === ""
        // 0 while rising into place with the new lines, 1 once there.
        property real arrive: 1

        width: column.width
        wrapMode: Text.WordWrap
        text: pause ? "• • •" : (modelData.text || " ")
        color: lit ? "#cba6f7" : "#b4befe"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: view.shownSynced ? 19 : 16
        font.weight: Font.Bold
        lineHeight: 1.1
        transformOrigin: Item.Left
        scale: !view.shownSynced || lit ? 1 : 0.95
        opacity: (!view.shownSynced ? 0.85 : lit ? 1 : Math.max(0.18, 0.5 - 0.08 * (distance - 1))) * arrive
        // Blurred only near the view: the lines out of sight need no layer.
        layer.enabled: view.active && view.shownSynced && distance > 0 && distance <= 6
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 12
            blur: Math.min(0.5, 0.1 * line.distance)
        }
        Component.onCompleted: {
            if (view.entering) {
                arrive = 0;
                arrival.start();
            }
        }

        transform: Translate {
            y: 18 * (1 - line.arrive)
        }

        // The line being sung first, then the others the further they are.
        SequentialAnimation {
            id: arrival

            PauseAnimation {
                duration: Math.min(8, view.shownSynced ? line.distance : line.index) * 45
            }

            NumberAnimation {
                target: line
                property: "arrive"
                to: 1
                duration: 420
                easing.type: Easing.OutCubic
            }

        }

        HoverHandler {
            enabled: view.shownSynced && line.modelData.t >= 0
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            enabled: view.shownSynced && line.modelData.t >= 0
            onTapped: view.seekRequested(line.modelData.t)
        }

        // Off while rising: it would trail behind the arrival.
        Behavior on opacity {
            enabled: line.arrive === 1

            NumberAnimation {
                duration: 300
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: 360
                easing.type: Easing.OutCubic
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: 300
            }

        }

    }

}
