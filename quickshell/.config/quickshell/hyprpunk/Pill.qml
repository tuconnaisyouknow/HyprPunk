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
    color: "#313244"

    HoverHandler {
        id: pillHover
    }

    RowLayout {
        id: contentRow

        anchors.centerIn: parent
        spacing: pill.spacing
    }

}
