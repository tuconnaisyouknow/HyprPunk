import QtQuick
import QtQuick.Layouts
import qs.theme

// An icon and its value, with the same gap between them whatever the icon. Nerd Font
// glyphs all claim one cell but spill out of it by different amounts (the RAM chip,
// the charging bolt…), so the gap is measured from the ink.
Item {
    id: iconText

    property string icon
    property string text
    property color color: Colors.primary
    // The value's font, whose size and weight the icon takes too.
    property alias font: valueLabel.font
    property real iconSize: font.pixelSize
    // The value is a title (Heading): capitals in the display font, smaller than its icon,
    // which stays in the text's font, the only one with the icons.
    property bool heading: false
    property alias elide: valueLabel.elide
    // From the icon's ink to the value's ink, in pixels.
    property real gap: font.pixelSize / 2

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row

        anchors.fill: parent
        // The label is already widened to the icon's ink when it overflows its cell.
        spacing: iconText.gap - (iconLabel.implicitWidth - iconMetrics.tightBoundingRect.right) - valueMetrics.tightBoundingRect.x

        Label {
            id: iconLabel

            text: iconText.icon
            color: iconText.color
            font.pixelSize: iconText.iconSize
            font.weight: valueLabel.font.weight
        }

        Label {
            id: valueLabel

            Layout.fillWidth: true
            text: iconText.text
            color: iconText.color
            font.family: iconText.heading ? Metrics.displayFont : Metrics.font
            font.capitalization: iconText.heading ? Font.AllUppercase : Font.MixedCase
            // Its digits each keep one width, so a value that changes never moves what's
            // next to it.
            font.features: {
                "tnum": 1
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
