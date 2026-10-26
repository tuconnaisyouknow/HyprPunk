import QtQuick
import QtQuick.Layouts

// Apple's render of AirPods or their case on the AirPods card, in a fixed box so
// both line up. Without one (a model Apple's renders do not cover, or not yet
// downloaded), the glyph stands in.
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
