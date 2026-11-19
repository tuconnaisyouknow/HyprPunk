import QtQuick

// The password as you type it, a dot per character in the island, as on the lock screen:
// the island widens with each one. Faint while it's checked or as it goes, red as a wrong
// one goes.
IslandPart {
    id: dots

    // How many characters are typed.
    property int count: 0
    property bool checking: false
    property bool alert: false
    // Past this the island would crowd the bar: further characters still count, unseen.
    readonly property int most: 24
    readonly property int dotSize: 6
    readonly property int dotSpacing: 5
    // The dots shown: kept while they close, so they shrink together with their place,
    // and cleared once it's closed.
    property int shownCount: 0

    shown: count > 0 || checking
    openWidth: Math.max(1, Math.min(shownCount, most)) * (dotSize + dotSpacing) - dotSpacing
    openHeight: dotSize
    onCountChanged: {
        if (count > 0)
            shownCount = count;

    }
    onVisibleChanged: {
        if (!visible)
            shownCount = 0;

    }

    // All the places laid out once: each dot pops in or out at its own, while the island
    // eases to the new width.
    Row {
        spacing: dots.dotSpacing

        Repeater {
            model: dots.most

            Rectangle {
                required property int index

                width: dots.dotSize
                height: dots.dotSize
                radius: dots.dotSize / 2
                color: dots.alert ? Colors.red : dots.checking || dots.count === 0 ? Colors.alpha(Colors.secondary, 0.5) : Colors.primary
                scale: index < dots.shownCount ? 1 : 0
                visible: scale > 0

                Behavior on scale {
                    enabled: dots.visible

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
