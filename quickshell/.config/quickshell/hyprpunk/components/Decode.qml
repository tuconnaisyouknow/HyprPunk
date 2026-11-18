import QtQuick
import qs.theme

// Words arriving on the machine: scrambled, then settling into what they say from the
// left. Put inside a Text that takes "transparent" for its color while this runs: the
// Text keeps its words and its size, and this draws the scramble over them. It plays
// when the words appear and when they change, never on what's already there.
Loader {
    id: decode

    readonly property Text words: parent
    property color color
    // Off for words that aren't the machine's.
    property bool live: true
    // How long they stay all scrambled before they settle, for words that come with
    // something else to look at first.
    property int wait: 0
    readonly property bool running: reveal.running
    // 0 and under all scrambled, 1 all settled.
    property real progress: 1
    // It scrambles anew a few times on the way, not at every frame.
    readonly property int step: Math.floor((wait + progress * Motion.decode.duration) / Motion.decode.pace)
    readonly property int settled: Math.floor(Math.max(0, progress) * words.text.length)

    function start() {
        if (live && words.visible && words.text !== "")
            reveal.restart();

    }

    // The spaces stay, so the words keep their shape as they come.
    function scrambled(step) {
        const text = words.text;
        const signs = Motion.decode.signs;
        let out = text.slice(0, settled);
        for (let i = settled; i < text.length; i++) out += text[i] === " " ? " " : signs[Math.floor(Math.random() * signs.length)]
        return out;
    }

    anchors.fill: parent
    active: running
    Component.onCompleted: start()

    Connections {
        function onTextChanged() {
            decode.start();
        }

        function onVisibleChanged() {
            decode.start();
        }

        target: decode.words
    }

    NumberAnimation {
        id: reveal

        target: decode
        property: "progress"
        from: -decode.wait / Motion.decode.duration
        to: 1
        duration: decode.wait + Motion.decode.duration
    }

    sourceComponent: Text {
        text: decode.scrambled(decode.step)
        color: decode.color
        font: decode.words.font
        elide: decode.words.elide
        horizontalAlignment: decode.words.horizontalAlignment
        verticalAlignment: decode.words.verticalAlignment
    }

}
