import QtQuick

// The control pill: network, sound, battery and what waits for you, opening the control
// center, which grows out of it.
Pill {
    id: controlPill

    required property var bar

    // Hidden under the control center's glass, which lets it through.
    opacity: controlPill.bar.pillHidden("control") ? 0 : 1
    clickable: true
    spotHovered: controlPill.bar.controlSpotHovered

    onClicked: controlPill.bar.screenState.toggle("controlcenter")

    ControlStatus {
        badgeColor: controlPill.baseColor
        showsTrayAttention: true
    }

}
