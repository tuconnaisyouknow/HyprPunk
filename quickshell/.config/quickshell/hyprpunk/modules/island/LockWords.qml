import QtQuick
import qs.components
import qs.theme

// Why a try at the password failed, in red in the lock screen's island (IslandView). The
// words open and close beside what's left in it, and new words decode over the old ones.
IslandPart {
    id: words

    // What it says, "" for nothing.
    property string label: ""
    // The words shown: kept while they close.
    property string shownLabel: label

    shown: label !== ""
    // Even, like every part's place.
    openWidth: 2 * Math.ceil(wordsText.implicitWidth / 2)
    openHeight: wordsText.implicitHeight
    onLabelChanged: {
        if (label !== "")
            shownLabel = label;

    }

    Readout {
        id: wordsText

        anchors.centerIn: parent
        text: words.shownLabel
        ink: Colors.red
        // The refusal first (the shake, the glitch behind), then what it says.
        wait: Motion.shake.swings.length * Motion.shake.swingDuration
        font.pixelSize: Metrics.pill.chipLabel
        font.weight: Font.Bold
    }

}
