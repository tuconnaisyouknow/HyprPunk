import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

// A drop-down for the forms and the settings, with its label above when it has one.
// Shows the current option, and a click unfolds the others underneath, a few at a time
// when there are many: the list scrolls, and half an option showing at its foot says so.
// A long list is searchable too: a field unfolds first, and what's typed narrows the
// options under it.
ColumnLayout {
    id: select

    property string label: ""
    // [{"label": "...", ...}]: the entries' other keys are the caller's. A searchable
    // one is also found by its "keywords", words that aren't in its label.
    required property var options
    property int currentIndex: 0
    property bool expanded: false
    property bool searchable: false
    property string placeholder: ""
    // How many options show at once, before the list scrolls.
    property int limit: 7
    readonly property var current: options[currentIndex] || null
    readonly property var needles: search.text.trim().toLowerCase().split(/\s+/).filter((word) => {
        return word !== "";
    })
    // What unfolds, as { "option", "index" }: every option, or the ones a searchable
    // list's field matches. The current one comes first, or once you type, a keyword, then the labels
    // that start with it, then the rest, each lot by name.
    readonly property var shown: {
        const all = options.map((option, index) => {
            return {
                "option": option,
                "index": index
            };
        });
        if (!searchable)
            return all;

        const rank = (entry) => {
            if (needles.length === 0)
                return entry.index === currentIndex ? 0 : 1;

            if ((entry.option.keywords || "").split(" ").includes(needles[0]))
                return 0;

            return entry.option.label.toLowerCase().startsWith(needles[0]) ? 1 : 2;
        };
        return all.filter((entry) => {
            const text = (entry.option.label + " " + (entry.option.keywords || "")).toLowerCase();
            return needles.every((word) => {
                return text.includes(word);
            });
        }).sort((a, b) => {
            return rank(a) - rank(b) || a.option.label.localeCompare(b.option.label);
        });
    }

    signal activated(int index)

    function choose(index) {
        currentIndex = index;
        expanded = false;
        activated(index);
    }

    spacing: 5
    // The search starts empty each time, with the keyboard in it.
    onExpandedChanged: {
        search.text = "";
        if (expanded && searchable)
            search.input.forceActiveFocus();

    }

    Text {
        visible: text !== ""
        text: select.label
        color: Colors.secondary
        font.family: Metrics.font
        font.pixelSize: Metrics.text.body
        font.weight: Font.Bold
    }

    Rectangle {
        id: box

        Layout.fillWidth: true
        implicitHeight: 34
        function activate() {
            boxBounce.restart();
            select.expanded = !select.expanded;
        }

        radius: Metrics.radius.normal
        color: Colors.alpha(Colors.crust, boxHover.hovered ? 0.6 : 0.45)
        opacity: select.enabled ? 1 : 0.45
        activeFocusOnTab: true

        Text {
            anchors.left: parent.left
            anchors.right: chevron.left
            anchors.leftMargin: Metrics.spacing.large
            anchors.rightMargin: Metrics.spacing.normal
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: select.current ? select.current.label : ""
            color: Colors.primary
            font.family: Metrics.font
            font.pixelSize: Metrics.text.emphasis
        }

        Text {
            id: chevron

            anchors.right: parent.right
            anchors.rightMargin: Metrics.spacing.large
            anchors.verticalCenter: parent.verticalCenter
            text: "󰅀"
            color: Colors.secondary
            rotation: select.expanded ? 180 : 0
            font.family: Metrics.font
            font.pixelSize: Metrics.text.emphasis

            Behavior on rotation {
                Anim {
                    token: Motion.move.normal
                }

            }

        }

        HoverHandler {
            id: boxHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: box.activate()
        }

        BounceAnimation {
            id: boxBounce

            target: box
        }

        ColorFade on color {
            token: Motion.color.small
        }

    }

    // The options, unfolded under the field. Narrowed by a search while open, they glide.
    Fold {
        Layout.fillWidth: true
        open: select.expanded

        Column {
            width: parent.width
            topPadding: Metrics.spacing.hairline
            spacing: Metrics.spacing.hairline

            // Enter takes the best match, Escape folds the list back.
            FormField {
                id: search

                width: parent.width
                visible: select.searchable
                placeholder: select.placeholder
                escapable: true
                onEscaped: select.expanded = false
                onAccepted: {
                    if (select.shown.length > 0)
                        select.choose(select.shown[0].index);

                }
            }

            // Only the options in sight exist, and one more each way for the keys to
            // move onto. A new search starts again from the top.
            ListView {
                id: optionList

                width: parent.width
                height: Math.min(contentHeight, (select.limit + 0.5) * (32 + spacing))
                spacing: Metrics.spacing.hairline
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 32
                model: select.shown

                delegate: Rectangle {
                    id: option

                    required property var modelData
                    readonly property int optionIndex: modelData.index

                    function activate() {
                        select.choose(optionIndex);
                    }

                    width: optionList.width
                    height: 32
                    radius: Metrics.radius.normal
                    activeFocusOnTab: true
                    color: optionHover.hovered ? Colors.alpha(Colors.primary, 0.16) : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.right: check.left
                        anchors.leftMargin: Metrics.spacing.large
                        anchors.rightMargin: Metrics.spacing.normal
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: option.modelData.option.label
                        color: option.optionIndex === select.currentIndex ? Colors.primary : Colors.secondary
                        font.family: Metrics.font
                        font.pixelSize: Metrics.text.emphasis
                        font.weight: option.optionIndex === select.currentIndex ? Font.Bold : Font.Normal
                    }

                    Text {
                        id: check

                        anchors.right: parent.right
                        anchors.rightMargin: Metrics.spacing.large
                        anchors.verticalCenter: parent.verticalCenter
                        visible: option.optionIndex === select.currentIndex
                        text: ""
                        color: Colors.primary
                        font.family: Metrics.font
                        font.pixelSize: Metrics.text.body
                    }

                    HoverHandler {
                        id: optionHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: option.activate()
                    }

                    ColorFade on color {
                        token: Motion.color.small
                    }

                }

            }

        }

    }

}
