import QtQuick
import qs.theme

// A workspace's icon in the bar. A few come from Font Awesome's brands or older sets,
// hence the font juggling.
Text {
    required property int workspaceId
    readonly property bool brandIcon: workspaceId === 2 || workspaceId === 3 || workspaceId === 5
    readonly property bool legacyNerdIcon: workspaceId === 7 || workspaceId === 10

    font.family: legacyNerdIcon ? "Font Awesome 7 Free Solid" : brandIcon ? "Font Awesome 7 Brands" : "Font Awesome 7 Free"
    font.weight: Font.Normal
    font.pixelSize: Metrics.text.title
}
