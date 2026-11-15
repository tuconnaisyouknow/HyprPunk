import QtQuick
import qs.components
import qs.theme

// Why a try at the password failed, in red in the lock screen's island (IslandView). The
// words open and close beside what's left in it, and new words fade in over the old ones.
IslandPart {
    id: words

    // What it says, "" for nothing.
    property string label: ""
    // The words shown: kept while they close, swapped once faded out.
    property string shownLabel: label

    shown: label !== ""
    openWidth: wordsText.implicitWidth
    openHeight: wordsText.implicitHeight
    onLabelChanged: {
        if (label === "")
            return ;

        // Nothing to fade out: the words come with their place.
        if (!visible || !animated) {
            swap.stop();
            wordsText.opacity = 1;
            shownLabel = label;
        } else {
            swap.restart();
        }
    }

    Text {
        id: wordsText

        anchors.centerIn: parent
        text: words.shownLabel
        color: Colors.red
        font.family: Metrics.font
        font.pixelSize: 15
        font.weight: Font.Bold
    }

    SequentialAnimation {
        id: swap

        Anim {
            target: wordsText
            property: "opacity"
            to: 0
            token: Motion.leave.small
        }

        ScriptAction {
            script: words.shownLabel = words.label
        }

        Anim {
            target: wordsText
            property: "opacity"
            to: 1
            token: Motion.enter.small
        }

    }

}
