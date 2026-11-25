import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

// Apple's picture of the AirPods or their case, in a fixed box so both line up.
// Until it's downloaded, or for a model Apple has no picture of, a glyph stands in.
Item {
    id: product

    property alias source: render.source
    property string glyph: ""

    Layout.alignment: Qt.AlignHCenter
    Layout.preferredWidth: 160
    Layout.preferredHeight: 120

    Image {
        id: render

        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        sourceSize.height: 240
        smooth: true
        mipmap: true
        asynchronous: true
    }

    Icon {
        visible: render.status !== Image.Ready
        anchors.centerIn: parent
        text: product.glyph
        color: Colors.secondary
        size: 88
    }

}
