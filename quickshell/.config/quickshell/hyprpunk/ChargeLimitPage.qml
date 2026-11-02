import QtQuick
import QtQuick.Layouts

// The control center's charge limit page: where the battery stops charging, read only
// until battery-limit is installed.
ColumnLayout {
    id: page

    required property var center

    signal backRequested()

    spacing: 6

    PageHeader {
        Layout.fillWidth: true
        title: "Charge limit"
        checked: page.center.chargeLimit < 100
        toggleVisible: page.center.chargeLimitWritable
        onToggled: page.center.toggleChargeLimit()
        onBackRequested: page.backRequested()
    }

    Text {
        Layout.fillWidth: true
        Layout.bottomMargin: 6
        text: !page.center.chargeLimitWritable ? "Read only: install battery-limit (battery/ in the dotfiles) to change it." : page.center.chargeLimitError !== "" ? page.center.chargeLimitError : "Stops charging at the limit, easier on the battery over the years. Kept after a restart."
        color: !page.center.chargeLimitWritable || page.center.chargeLimitError !== "" ? Theme.peach : Theme.lavender
        wrapMode: Text.Wrap
        font.family: Theme.font
        font.pixelSize: 12
    }

    Repeater {
        model: page.center.chargeLimits

        ListRow {
            required property int modelData
            readonly property bool chosen: page.center.chargeLimit === modelData

            Layout.fillWidth: true
            icon: page.center.chargeLimitIcon(modelData)
            title: modelData + " %"
            subtitle: modelData === 80 ? "Recommended" : ""
            trailing: chosen ? "\uf00c" : ""
            highlighted: chosen
            enabled: page.center.chargeLimitWritable
            onClicked: page.center.setChargeLimit(modelData)
        }

    }

}
