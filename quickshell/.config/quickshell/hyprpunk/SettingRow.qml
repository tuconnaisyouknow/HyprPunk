import QtQuick
import QtQuick.Layouts

// A setting in the settings window: its icon, its name and what it does, on glass. The
// control that changes it goes under them (a list of choices), or it's a switch beside
// them when checkable.
Item {
    id: row

    required property string icon
    required property string title
    property string description: ""
    property bool checkable: false
    property bool checked: false
    // The control under the text.
    default property alias content: under.data

    signal toggled()

    implicitHeight: layout.implicitHeight + 32

    GlassSurface {
        radius: 18
    }

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            // As wide for every icon, so the titles line up.
            Text {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 24
                horizontalAlignment: Text.AlignHCenter
                text: row.icon
                color: Theme.secondary
                font.family: Theme.font
                font.pixelSize: 20
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: row.title
                    color: Theme.primary
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: row.description
                    color: Theme.secondary
                    wrapMode: Text.Wrap
                    font.family: Theme.font
                    font.pixelSize: 12
                }

            }

            ToggleSwitch {
                visible: row.checkable
                checked: row.checked
                onToggled: row.toggled()
            }

        }

        Item {
            id: under

            Layout.fillWidth: true
            implicitHeight: childrenRect.height
            visible: children.length > 0
        }

    }

}
