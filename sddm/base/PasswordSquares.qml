import QtQuick

// The password as you type it, a square per character in the island, as on the lock
// screen: the island widens with each one. Faint while it's checked or as it goes, red as
// a wrong one goes.
IslandPart {
    id: squares

    // How many characters are typed.
    property int count: 0
    property bool checking: false
    property bool alert: false
    // Past this the island would crowd the bar: further characters still count, unseen.
    readonly property int most: 24
    // A square looks bigger than it is: any larger and they read as blocks.
    readonly property int side: 5
    readonly property int spacing: 6
    // The squares shown: kept while they close, so they shrink together with their place,
    // and cleared once it's closed.
    property int shownCount: 0

    shown: count > 0 || checking
    // Even, like every part's place: an odd count leaves a pixel after the last square.
    openWidth: 2 * Math.ceil((Math.max(1, Math.min(shownCount, most)) * (side + spacing) - spacing) / 2)
    openHeight: side
    onCountChanged: {
        if (count > 0)
            shownCount = count;

    }
    onVisibleChanged: {
        if (!visible)
            shownCount = 0;

    }

    // All the places laid out once: each square pops in or out at its own, while the
    // island eases to the new width.
    Row {
        spacing: squares.spacing

        Repeater {
            model: squares.most

            Rectangle {
                required property int index

                width: squares.side
                height: squares.side
                color: squares.alert ? Colors.red : squares.checking || squares.count === 0 ? Colors.alpha(Colors.secondary, 0.5) : Colors.primary
                scale: index < squares.shownCount ? 1 : 0
                visible: scale > 0

                Behavior on scale {
                    enabled: squares.visible

                    NumberAnimation {
                        duration: Motion.pop.duration
                        easing.type: Motion.pop.easing
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: Motion.color.duration
                        easing.type: Motion.color.easing
                    }

                }

            }

        }

    }

}
