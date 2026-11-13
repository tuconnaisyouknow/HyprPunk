import QtQuick

// The values a setting can take, side by side, wrapping onto a new line when they run
// out of room: the chosen one in the accent. A number saved from a terminal that isn't
// among them shows up as a choice of its own, in order, so it's never hidden. It stays
// while the control lives. The choices are only rebuilt when they really change, not
// on each choice or when the same values come again: that would take the keyboard away
// from the one you're on.
Flow {
    id: choices

    // Numbers in order, or names in the order to show them.
    required property var values
    property var value: null
    // How a value reads ("5 min").
    property var label: (value) => {
        return String(value);
    }
    // The saved numbers seen that aren't among the usual ones.
    property var extras: []
    property var shown: []

    signal selected(var value)

    function keepValue() {
        if (typeof value === "number" && !values.includes(value) && !extras.includes(value))
            extras = extras.concat([value]);

    }

    function update() {
        const next = extras.length > 0 ? values.concat(extras).sort((a, b) => {
            return a - b;
        }) : values;
        if (JSON.stringify(next) !== JSON.stringify(shown))
            shown = next;

    }

    spacing: 6
    onValueChanged: keepValue()
    // Once the value has caught up with new values too, so the chosen one is built
    // chosen rather than turning to the accent as you watch.
    onValuesChanged: Qt.callLater(update)
    onExtrasChanged: Qt.callLater(update)
    Component.onCompleted: {
        keepValue();
        update();
    }

    Repeater {
        model: choices.shown

        Item {
            id: chip

            required property var modelData
            readonly property bool chosen: modelData === choices.value
            readonly property real radius: height / 2

            function activate() {
                chipBounce.restart();
                if (!chosen)
                    choices.selected(modelData);

            }

            implicitWidth: chipText.implicitWidth + 28
            implicitHeight: 32
            activeFocusOnTab: true

            GlassSurface {
                radius: chip.radius
                hovered: chipHover.hovered
                backgroundColor: chip.chosen ? Theme.alpha(Theme.primary, 0.85) : "transparent"

                Behavior on backgroundColor {
                    ColorAnimation {
                        duration: 160
                    }

                }

            }

            Text {
                id: chipText

                anchors.centerIn: parent
                text: choices.label(chip.modelData)
                color: chip.chosen ? Theme.base : Theme.secondary
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: chip.chosen ? Font.Bold : Font.Medium
            }

            HoverHandler {
                id: chipHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: chip.activate()
            }

            BounceAnimation {
                id: chipBounce

                target: chip
            }

        }

    }

}
