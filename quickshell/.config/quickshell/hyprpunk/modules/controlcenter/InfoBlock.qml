import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

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
        anchors.leftMargin: Metrics.spacing.large
        anchors.rightMargin: Metrics.spacing.large
        spacing: Metrics.spacing.normal

        Repeater {
            model: info.rows.filter((row) => {
                return row.value !== "";
            })

            RowLayout {
                required property var modelData

                Layout.fillWidth: true
                spacing: Metrics.spacing.large

                Text {
                    text: modelData.label
                    color: Colors.secondary
                    font.family: Metrics.font
                    font.pixelSize: Metrics.text.emphasis
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    text: modelData.value
                    color: Colors.primary
                    font.family: Metrics.font
                    font.pixelSize: Metrics.text.emphasis
                    font.weight: Font.Bold
                }

            }

        }

    }

}
