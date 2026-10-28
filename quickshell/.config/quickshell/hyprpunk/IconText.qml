import QtQuick
import QtQuick.Layouts

// An icon and its value, with the same gap between them whatever the icon. Nerd Font
// glyphs all claim one cell but spill out of it by different amounts (the RAM chip,
// the charging bolt…), so the gap is measured from the ink.
Item {
    id: iconText

    property string icon
    property string text
    property color color: Theme.mauve
    // The icon is drawn with the value's font.
    property alias font: valueLabel.font
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
            font: valueLabel.font
        }

        Label {
            id: valueLabel

            Layout.fillWidth: true
            text: iconText.text
            color: iconText.color
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
