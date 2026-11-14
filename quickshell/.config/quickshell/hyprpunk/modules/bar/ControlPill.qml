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

    // Where it rests in its row, and its zoom apart.
    function publishGeometry() {
        const origin = parent.mapToItem(null, x, y);
        controlPill.bar.controlPill = {
            "right": controlPill.bar.width - origin.x - width,
            "top": origin.y,
            "width": width,
            "height": height,
            "spreadX": spreadX,
            "spreadY": spreadY
        };
    }

    onSpreadXChanged: publishGeometry()
    onSpreadYChanged: publishGeometry()
    onXChanged: publishGeometry()
    onYChanged: publishGeometry()
    onWidthChanged: publishGeometry()
    onHeightChanged: publishGeometry()
    Component.onCompleted: publishGeometry()
    onClicked: controlPill.bar.screenState.toggle("controlcenter")

    ControlStatus {
        badgeColor: controlPill.baseColor
        showsTrayAttention: true
    }

}
