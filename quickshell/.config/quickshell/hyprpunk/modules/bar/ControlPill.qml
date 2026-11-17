import QtQuick

// The control pill: network, sound, battery and what waits for you, opening the control
// center, which grows out of it.
Pill {
    id: controlPill

    required property var bar

    covered: controlPill.bar.pillHidden("control")
    clickable: true
    spotHovered: controlPill.bar.controlSpotHovered

    onClicked: controlPill.bar.screenState.toggle("controlcenter")

    ControlStatus {
        badgeColor: controlPill.baseColor
        showsTrayAttention: true
    }

}
