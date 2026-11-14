import QtQuick
import QtQuick.Layouts
import qs.config
import qs.theme
import qs.state

// The control center's caffeine page: how long the screen stays on, from half an
// hour to until you turn it off.
ColumnLayout {
    id: page

    required property var center

    signal backRequested()

    spacing: 6

    PageHeader {
        Layout.fillWidth: true
        title: "Caffeine"
        checked: ShellState.caffeine
        onToggled: page.center.toggleCaffeine()
        onBackRequested: page.backRequested()
    }

    Text {
        Layout.fillWidth: true
        Layout.bottomMargin: 6
        text: "Keeps the screen on: no dimming, locking or sleep."
        color: Colors.secondary
        wrapMode: Text.Wrap
        font.family: Metrics.font
        font.pixelSize: 12
    }

    Repeater {
        model: page.center.caffeineDurations

        ListRow {
            required property var modelData
            readonly property bool chosen: ShellState.caffeine && ShellState.caffeineMinutes === modelData.minutes

            Layout.fillWidth: true
            icon: modelData.minutes === 0 ? "󰅶" : "󰔛"
            title: modelData.label
            // The chosen duration ends at: "Until 22:10".
            subtitle: chosen && ShellState.caffeineUntil > 0 ? "Until " + Session.shortTime(new Date(ShellState.caffeineUntil)) : ""
            trailing: chosen ? "\uf00c" : ""
            highlighted: chosen
            onClicked: page.center.chooseCaffeine(modelData.minutes)
        }

    }

}
