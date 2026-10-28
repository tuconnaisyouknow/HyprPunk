import QtQuick
import QtQuick.Layouts

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

    Text {
        visible: render.status !== Image.Ready
        anchors.centerIn: parent
        text: product.glyph
        color: "#cdd6f4"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 88
    }

}
