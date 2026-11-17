import QtQuick
import QtQuick.Layouts
import qs.theme

// A page of the settings window: its title and what it's about, then its settings
// (SettingRow) one under the other. A question that can't wait is held by the window
// over the page's foot while it's asked, and nothing else answers until it is.
ColumnLayout {
    id: page

    required property string title
    property string description: ""
    property Component question: null
    property bool asking: false

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
