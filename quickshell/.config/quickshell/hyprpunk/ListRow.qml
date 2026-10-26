import QtQuick
import QtQuick.Layouts

ControlBlock {
    id: row

    required property string icon
    required property string title
    property string subtitle: ""
    property string trailing: ""
    property bool highlighted: false

    signal clicked()

    implicitHeight: 48
    radius: 14

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 14
        spacing: 12

        Text {
            text: row.icon
            color: row.highlighted ? "#cba6f7" : "#b4befe"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 18
        }

        Column {
            Layout.fillWidth: true
            spacing: 1

            Text {
                width: parent.width
                text: row.title
                color: "#cba6f7"
                elide: Text.ElideRight
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                font.weight: row.highlighted ? Font.Bold : Font.Medium
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: row.subtitle
                color: "#b4befe"
                elide: Text.ElideRight
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
            }

        }

        Text {
            visible: text !== ""
            text: row.trailing
            color: "#b4befe"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
        }

    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: {
            row.bounce();
            row.clicked();
        }
    }

}
