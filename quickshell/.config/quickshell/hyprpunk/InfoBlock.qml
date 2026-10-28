import QtQuick
import QtQuick.Layouts

// The facts on a detail page (status, security, address…), label on the left and
// value on the right, in one glass block.
ControlBlock {
    id: info

    // [{"label": "...", "value": "..."}], the empty values are left out.
    required property var rows

    implicitHeight: column.implicitHeight + 20

    ColumnLayout {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 8

        Repeater {
            model: info.rows.filter((row) => {
                return row.value !== "";
            })

            RowLayout {
                required property var modelData

                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: modelData.label
                    color: "#b4befe"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    text: modelData.value
                    color: "#cba6f7"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                }

            }

        }

    }

}
