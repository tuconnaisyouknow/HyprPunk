import QtQuick
import QtQuick.Layouts
import qs.services
import qs.theme

// The control center's charge limit page: where the battery stops charging, read only
// until battery-limit is installed.
ControlPage {
    id: page

    pageName: "chargeLimit"
    spacing: Metrics.spacing.normal

    PageHeader {
        Layout.fillWidth: true
        title: "Charge limit"
        checked: ChargeLimit.current < 100
        toggleVisible: ChargeLimit.writable
        onToggled: ChargeLimit.toggle()
        onBackRequested: page.back()
    }

    Text {
        Layout.fillWidth: true
        Layout.bottomMargin: Metrics.spacing.normal
        text: !ChargeLimit.writable ? "Read only: install battery-limit (battery/ in the dotfiles) to change it." : ChargeLimit.error !== "" ? ChargeLimit.error : "Stops charging at the limit, easier on the battery over the years. Kept after a restart."
        color: !ChargeLimit.writable || ChargeLimit.error !== "" ? Colors.peach : Colors.secondary
        wrapMode: Text.Wrap
        font.family: Metrics.font
        font.pixelSize: Metrics.text.body
    }

    Repeater {
        model: ChargeLimit.choices

        ListRow {
            required property int modelData
            readonly property bool chosen: ChargeLimit.current === modelData

            Layout.fillWidth: true
            icon: Icons.chargeLimit(modelData)
            title: modelData + " %"
            subtitle: modelData === 80 ? "Recommended" : ""
            trailing: chosen ? "\uf00c" : ""
            highlighted: chosen
            enabled: ChargeLimit.writable
            onClicked: ChargeLimit.set(modelData)
        }

    }

}
