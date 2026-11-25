import QtQuick
import QtQuick.Layouts
import qs.config
import qs.theme
import qs.state

// The control center's caffeine page: how long the screen stays on, from half an
// hour to until you turn it off.
ControlPage {
    id: page

    readonly property var durations: [{
        "minutes": 0,
        "label": "Until turned off"
    }, {
        "minutes": 30,
        "label": "30 minutes"
    }, {
        "minutes": 60,
        "label": "1 hour"
    }, {
        "minutes": 120,
        "label": "2 hours"
    }, {
        "minutes": 240,
        "label": "4 hours"
    }]

    pageName: "caffeine"
    spacing: Metrics.spacing.normal

    PageHeader {
        Layout.fillWidth: true
        title: "Caffeine"
        checked: ShellState.caffeine
        onToggled: ShellState.toggleCaffeine()
        onBackRequested: page.back()
    }

    Text {
        Layout.fillWidth: true
        Layout.bottomMargin: Metrics.spacing.normal
        text: "Keeps the screen on: no dimming, locking or sleep."
        color: Colors.secondary
        wrapMode: Text.Wrap
        font.family: Metrics.font
        font.pixelSize: Metrics.text.body
    }

    Repeater {
        model: page.durations

        ListRow {
            required property var modelData
            readonly property bool chosen: ShellState.caffeine && ShellState.caffeineMinutes === modelData.minutes

            Layout.fillWidth: true
            icon: modelData.minutes === 0 ? "coffee" : "timer"
            title: modelData.label
            // The chosen duration ends at: "Until 22:10".
            subtitle: chosen && ShellState.caffeineUntil > 0 ? "Until " + Session.shortTime(new Date(ShellState.caffeineUntil)) : ""
            trailing: chosen ? "\uf00c" : ""
            highlighted: chosen
            onClicked: ShellState.setCaffeine(modelData.minutes)
        }

    }

}
