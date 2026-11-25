import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services
import qs.theme

// The control center's night light page: on or off, whether it follows the hours, and
// how warm. The switch goes against the schedule like the tile does; only the row
// below leaves the schedule.
ControlPage {
    id: page

    readonly property bool scheduled: NightLightSettings.mode === "schedule"

    pageName: "nightlight"
    spacing: Metrics.spacing.normal

    PageHeader {
        Layout.fillWidth: true
        title: "Night light"
        checked: NightLight.active
        onToggled: NightLight.toggle()
        onBackRequested: page.back()
    }

    Text {
        Layout.fillWidth: true
        Layout.bottomMargin: Metrics.spacing.normal
        text: "Warms the screens' colors, easier on the eyes in the evening."
        color: Colors.secondary
        wrapMode: Text.Wrap
        font.family: Metrics.font
        font.pixelSize: Metrics.text.body
    }

    ListRow {
        Layout.fillWidth: true
        icon: "timer"
        title: "Scheduled"
        subtitle: NightLightSettings.hourText(NightLightSettings.from) + " to " + NightLightSettings.hourText(NightLightSettings.to)
        trailing: page.scheduled ? "check" : ""
        highlighted: page.scheduled
        onClicked: NightLight.setScheduled(!page.scheduled)
    }

    // The hours only matter on a schedule.
    ControlBlock {
        Layout.fillWidth: true
        enabled: page.scheduled
        opacity: enabled ? 1 : 0.5
        implicitHeight: hoursColumn.implicitHeight + 2 * Metrics.spacing.large

        ColumnLayout {
            id: hoursColumn

            anchors.fill: parent
            anchors.margins: Metrics.spacing.large
            spacing: Metrics.spacing.normal

            Heading {
                text: "From"
            }

            SettingChoices {
                Layout.fillWidth: true
                values: [18, 19, 20, 21, 22]
                value: NightLightSettings.from
                label: NightLightSettings.hourText
                onSelected: (value) => {
                    return NightLightSettings.set("from", value);
                }
            }

            Heading {
                Layout.topMargin: Metrics.spacing.small
                text: "To"
            }

            SettingChoices {
                Layout.fillWidth: true
                values: [5, 6, 7, 8, 9]
                value: NightLightSettings.to
                label: NightLightSettings.hourText
                onSelected: (value) => {
                    return NightLightSettings.set("to", value);
                }
            }

        }

    }

    ControlBlock {
        Layout.fillWidth: true
        implicitHeight: warmthColumn.implicitHeight + 2 * Metrics.spacing.large

        ColumnLayout {
            id: warmthColumn

            anchors.fill: parent
            anchors.margins: Metrics.spacing.large
            spacing: Metrics.spacing.normal

            Heading {
                text: "Warmth"
            }

            SettingChoices {
                Layout.fillWidth: true
                values: [2500, 3500, 4500, 5500]
                value: NightLightSettings.temperature
                label: (kelvin) => {
                    return kelvin + " K";
                }
                onSelected: (value) => {
                    return NightLightSettings.set("temperature", value);
                }
            }

        }

    }

}
