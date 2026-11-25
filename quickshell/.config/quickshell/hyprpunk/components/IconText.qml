import QtQuick
import QtQuick.Layouts
import qs.theme

// An icon and its value, with the same gap between them whatever the icon. Icons all
// take a square but leave it more or less empty (the Bluetooth rune, the wide RAM
// stick…), so the gap is measured from the ink. Either can be left out: the other then
// stands alone, centred in its own box.
Item {
    id: iconText

    property string icon
    // The icon fills in while what it stands for is on.
    property alias filled: iconLabel.filled
    property string text
    property color color: Colors.primary
    // The value's font, whose size the icon takes too.
    property alias font: valueLabel.font
    property real iconSize: font.pixelSize
    // The value is a title (Heading): capitals in the display font, smaller than its icon.
    property bool heading: false
    property alias elide: valueLabel.elide
    // The value is a count that moves a step at a time (a level, a percentage): its digits
    // roll as it changes, the way it goes.
    property bool counts: false
    // From the icon's ink to the value's ink, in pixels.
    property real gap: font.pixelSize / 2

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row

        anchors.fill: parent
        spacing: iconText.gap - (iconLabel.implicitWidth - iconMetrics.tightBoundingRect.right) - valueMetrics.tightBoundingRect.x

        Icon {
            id: iconLabel

            visible: iconText.icon !== ""
            text: iconText.icon
            color: iconText.color
            size: iconText.iconSize
        }

        Label {
            id: valueLabel

            Layout.fillWidth: true
            // A count's width eases with its roll, so what's beside it slides along.
            Layout.preferredWidth: iconText.counts ? count.implicitWidth : -1
            visible: iconText.text !== ""
            text: iconText.text
            color: decode.running || iconText.counts ? "transparent" : iconText.color
            font.family: iconText.heading ? Metrics.displayFont : Metrics.font
            font.capitalization: iconText.heading ? Font.AllUppercase : Font.MixedCase
            // Its digits each keep one width, so a value that changes never moves what's
            // next to it.
            font.features: {
                "tnum": 1
            }

            Decode {
                id: decode

                live: iconText.heading
                color: iconText.color
            }

            // The label keeps the value's look and place, and this draws it.
            RollingText {
                id: count

                anchors.baseline: parent.baseline
                visible: iconText.counts
                bothWays: true
                text: iconText.text
                font: valueLabel.font
                color: iconText.color
            }

        }

    }

    TextMetrics {
        id: iconMetrics

        font: iconLabel.font
        text: iconText.icon
    }

    TextMetrics {
        id: valueMetrics

        font: valueLabel.font
        text: iconText.text
    }

}
