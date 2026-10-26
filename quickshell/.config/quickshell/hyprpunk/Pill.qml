import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

// Clips to its rounded shape so content never sticks out while the pill resizes.
ClippingRectangle {
    id: pill

    default property alias content: contentRow.data
    property alias contentOpacity: contentRow.opacity
    readonly property alias hovered: pillHover.hovered
    property int spacing: 10
    property int horizontalPadding: 20

    implicitWidth: contentRow.implicitWidth + horizontalPadding
    implicitHeight: 38
    radius: height / 2
    // The panels' card: base at 0.9, blurred by the bar's layer rule, with the glass rim.
    color: Qt.rgba(30 / 255, 30 / 255, 46 / 255, 0.9)

    GlassSurface {
        radius: pill.radius
        tinted: false
    }

    HoverHandler {
        id: pillHover
    }

    RowLayout {
        id: contentRow

        anchors.centerIn: parent
        spacing: pill.spacing
    }

}
