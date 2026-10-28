import QtQuick

// A line of text that scrolls round when it's too long, like an old MP3 player's
// display. When it fits, it just sits there.
Item {
    id: marquee

    property alias text: label.text
    property alias color: label.color
    property alias font: label.font
    // Off while the text is not shown.
    property bool running: true
    // Space between the end of the text and its next turn.
    property int gap: 48
    // Pixels per second.
    property real speed: 32
    readonly property bool overflowing: label.implicitWidth > width

    function restart() {
        scroll.stop();
        strip.x = 0;
        if (running && overflowing)
            scroll.start();

    }

    implicitHeight: label.implicitHeight
    clip: true
    onTextChanged: restart()
    onOverflowingChanged: restart()
    onRunningChanged: restart()

    Row {
        id: strip

        spacing: marquee.gap

        Text {
            id: label
        }

        // The start coming back in behind the end.
        Text {
            visible: marquee.overflowing
            text: label.text
            color: label.color
            font: label.font
        }

    }

    // Reads the start first, then goes round once, and again.
    SequentialAnimation {
        id: scroll

        loops: Animation.Infinite

        PauseAnimation {
            duration: 1800
        }

        NumberAnimation {
            target: strip
            property: "x"
            from: 0
            to: -(label.implicitWidth + marquee.gap)
            duration: (label.implicitWidth + marquee.gap) / marquee.speed * 1000
        }

    }

}
