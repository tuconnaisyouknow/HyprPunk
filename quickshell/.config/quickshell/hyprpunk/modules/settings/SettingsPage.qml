import QtQuick
import QtQuick.Layouts
import qs.theme

// A page of the settings window: its title and what it's about, then its settings
// (SettingRow) one under the other.
ColumnLayout {
    id: page

    required property string title
    property string description: ""

    spacing: Metrics.spacing.large

    Text {
        text: page.title
        color: Colors.primary
        font.family: Metrics.font
        font.pixelSize: Metrics.text.heading
        font.weight: Font.Bold
    }

    Text {
        Layout.fillWidth: true
        Layout.bottomMargin: Metrics.spacing.small
        visible: text !== ""
        text: page.description
        color: Colors.secondary
        wrapMode: Text.Wrap
        font.family: Metrics.font
        font.pixelSize: Metrics.text.body
    }

}
