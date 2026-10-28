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
    // The panels' card: base at 0.9, blurred by the bar's layer rule. Drawn by the glass
    // rather than the pill, so the liquid style can make it see-through.
    readonly property color baseColor: Qt.rgba(30 / 255, 30 / 255, 46 / 255, 0.9)

    implicitWidth: contentRow.implicitWidth + horizontalPadding
    implicitHeight: 38
    radius: height / 2
    color: "transparent"

    GlassSurface {
        radius: pill.radius
        tinted: false
        backgroundColor: pill.baseColor
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
