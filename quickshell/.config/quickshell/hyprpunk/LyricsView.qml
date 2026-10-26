import QtQuick
import QtQuick.Effects

// Lyrics in the style of Apple Music: big bold lines, the one being sung lit and
// held near the top, the others dimmed and blurred the further they are. A click
// on a timed line seeks to it; scrolling by hand pauses the follow for a moment.
Item {
    id: view

    // [{"t": seconds, "text": "..."}], t is -1 for untimed lyrics.
    property var lines: []
    property bool synced: false
    property bool instrumental: false
    // Lyrics.status: "idle", "loading", "found", "missing" or "network".
    property string status: "idle"
    // Index of the line being sung, -1 before the first one.
    property int current: -1
    // Off while the card is not shown: no blur layers, no follow animation.
    property bool active: true
    // The line being sung sits this far down the view.
    readonly property real anchorRatio: 0.3
    readonly property string message: {
        if (status === "loading")
            return "Looking for lyrics…";

        if (status === "network")
            return "Lyrics unavailable, trying again soon";

        if (status === "missing")
            return "No lyrics for this track";

        if (instrumental)
            return "Instrumental";

        return "";
    }

    // Scrolled by hand: the view stops following until resumeFollow runs out.
    property bool handScrolled: false

    signal seekRequested(real seconds)

    function follow() {
        if (handScrolled || !synced || lines.length === 0)
            return ;

        const line = current >= 0 ? lineRepeater.itemAt(current) : null;
        const wanted = line ? line.y - height * anchorRatio : 0;
        followAnimation.to = Math.max(0, Math.min(wanted, flickable.contentHeight - height));
        followAnimation.restart();
    }

    onCurrentChanged: follow()
    onLinesChanged: {
        handScrolled = false;
        followAnimation.stop();
        flickable.contentY = 0;
        Qt.callLater(follow);
    }
    onHeightChanged: Qt.callLater(follow)
    onActiveChanged: {
        if (active) {
            handScrolled = false;
            followAnimation.stop();
            Qt.callLater(follow);
        }
    }

    Text {
        anchors.centerIn: parent
        width: parent.width
        visible: view.message !== ""
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: view.message
        color: "#7f849c"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
        font.weight: Font.DemiBold
    }

    Flickable {
        id: flickable

        anchors.fill: parent
        visible: view.lines.length > 0
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
            topPadding: view.synced ? view.height * view.anchorRatio : 12
            bottomPadding: view.height * (1 - view.anchorRatio)
            spacing: 14

            Repeater {
                id: lineRepeater

                model: view.lines

                LyricLine {
                }

            }

            Text {
                width: column.width
                topPadding: 10
                text: view.synced ? "Lyrics from LRCLIB" : "Not synced · Lyrics from LRCLIB"
                color: "#6c7086"
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
        readonly property int distance: view.synced ? Math.abs(index - Math.max(0, view.current)) : 0
        readonly property bool lit: view.synced && index === view.current
        // An empty timed line is a pause in the singing.
        readonly property bool pause: view.synced && modelData.text === ""

        width: column.width
        wrapMode: Text.WordWrap
        text: pause ? "• • •" : (modelData.text || " ")
        color: lit ? "#cba6f7" : "#b4befe"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: view.synced ? 19 : 16
        font.weight: Font.Bold
        lineHeight: 1.1
        transformOrigin: Item.Left
        scale: !view.synced || lit ? 1 : 0.95
        opacity: !view.synced ? 0.85 : lit ? 1 : Math.max(0.18, 0.5 - 0.08 * (distance - 1))
        // Blurred only near the view: the lines out of sight need no layer.
        layer.enabled: view.active && view.synced && distance > 0 && distance <= 6
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 12
            blur: Math.min(0.5, 0.1 * line.distance)
        }

        HoverHandler {
            enabled: view.synced && line.modelData.t >= 0
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            enabled: view.synced && line.modelData.t >= 0
            onTapped: view.seekRequested(line.modelData.t)
        }

        Behavior on opacity {
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
