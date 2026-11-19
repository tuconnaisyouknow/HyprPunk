import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import qs.components
import qs.modules.airpods
import qs.services
import qs.theme

// The control center's sound page, in tabs: output, input, the apps playing and
// Bluetooth audio. A tab taller than the panel scrolls.
ControlPage {
    id: page

    // Kept while the shell runs: the page opens on the last tab seen.
    property string tab: "output"
    readonly property var tabs: [{
        "value": "output",
        "icon": "󰓃",
        "label": "Output"
    }, {
        "value": "input",
        "icon": "󰍬",
        "label": "Input"
    }, {
        "value": "apps",
        "icon": "󰎆",
        "label": "Apps"
    }, {
        "value": "devices",
        "icon": "󰂯",
        "label": "Devices"
    }]
    readonly property int tabIndex: tabs.findIndex((item) => {
        return item.value === tab;
    })
    // Between the tabs side by side, enough to hide the neighbours of the one shown.
    readonly property int tabGap: 24
    readonly property Item currentTab: [outputTab, inputTab, appsTab, devicesTab][Math.max(0, tabIndex)]
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sourceAudio: source !== null ? source.audio : null
    readonly property var outputs: Pipewire.nodes.values.filter((node) => {
        return node.type === PwNodeType.AudioSink && (AudioPorts.info[node.name] === undefined || AudioPorts.info[node.name].available);
    })
    readonly property var inputs: Pipewire.nodes.values.filter((node) => {
        return node.type === PwNodeType.AudioSource && (AudioPorts.info[node.name] === undefined || AudioPorts.info[node.name].available);
    })
    readonly property var streams: Pipewire.nodes.values.filter((node) => {
        return node.type === PwNodeType.AudioOutStream && node.audio !== null;
    })
    readonly property var bluetoothAudio: {
        return BluetoothStatus.connected.filter((device) => {
            return device.icon.startsWith("audio");
        });
    }
    // AirPods connected or only nearby: their batteries come either way.
    readonly property var airPodsShown: AirPods.devices.filter((device) => {
        return device.connected || device.nearby;
    })
    // The other audio devices connected.
    readonly property var otherAudio: bluetoothAudio.filter((device) => {
        return AirPods.device(device.address) === null;
    })
    signal bluetoothDetailsRequested(var device)

    function volumeIcon(volume, muted) {
        if (muted || volume === 0)
            return "󰖁";

        return volume < 0.34 ? "󰕿" : volume < 0.67 ? "󰖀" : "󰕾";
    }

    function outputLabel(node) {
        const info = AudioPorts.info[node.name];
        return info !== undefined && info.label !== "" ? info.label : (node.description || node.nickname || node.name);
    }

    function inputIcon(node) {
        return node.name.startsWith("bluez") ? "󰋋" : /head/i.test(outputLabel(node)) ? "󰋎" : "󰍬";
    }

    function outputIcon(node) {
        const name = node.name;
        if (name.startsWith("bluez"))
            return "󰋋";

        if (/hdmi|displayport/i.test(outputLabel(node)))
            return "󰍹";

        return /head/i.test(outputLabel(node)) ? "󰋋" : "󰓃";
    }

    function outputKind(node) {
        if (node.name.startsWith("bluez"))
            return "Bluetooth";

        if (node.properties["device.bus"] === "usb")
            return "USB";

        return /hdmi|displayport/i.test(outputLabel(node)) ? "Display" : "Built-in";
    }

    function appName(node) {
        const properties = node.properties;
        return properties["application.name"] || node.description || node.name;
    }

    function appIcon(node) {
        const properties = node.properties;
        const entry = DesktopEntries.heuristicLookup(properties["application.process.binary"] || properties["application.name"] || "");
        return Quickshell.iconPath(properties["application.icon-name"] || (entry !== null ? entry.icon : ""), true);
    }

    pageName: "sound"
    spacing: Metrics.spacing.large

    // One tab, side by side with the others: only the one shown is opaque and clickable,
    // the others fade as they slide away.
    component TabColumn: ColumnLayout {
        required property int index
        readonly property bool current: index === page.tabIndex

        x: index * (page.width + page.tabGap)
        width: page.width
        spacing: Metrics.spacing.large
        enabled: current
        opacity: current ? 1 : 0

        Behavior on opacity {
            Anim {
                token: Motion.color.normal
            }

        }

    }

    component EmptyText: Text {
        color: Colors.secondary
        font.family: Metrics.font
        font.pixelSize: Metrics.text.body
    }

    // A list at full height (the page scrolls, not the list). Rows fade in as they come,
    // fade out as they go, and the rest slide into place.
    component AnimatedList: ListView {
        // Its rows, which keep living as others come and go: a plain list would build
        // them all again each time.
        required property var rows

        model: ScriptModel {
            values: rows
        }

        implicitHeight: contentHeight
        // Out of its column while empty: it would still take the gap to its neighbour,
        // and push a message alone with it off its block's middle.
        visible: count > 0
        interactive: false
        spacing: Metrics.spacing.normal

        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 220
            }

            Anim {
                property: "scale"
                from: 0.92
                to: 1
                token: Motion.pop
            }

        }

        remove: Transition {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: 160
            }

        }

        displaced: Transition {
            NumberAnimation {
                property: "y"
                duration: 220
                easing.type: Easing.OutCubic
            }

        }

    }

    component OutputRow: ListRow {
        required property var modelData

        width: ListView.view.width
        icon: page.outputIcon(modelData)
        title: page.outputLabel(modelData)
        subtitle: page.outputKind(modelData)
        highlighted: page.sink === modelData
        trailing: highlighted ? "󰄬" : ""
        onClicked: Pipewire.preferredDefaultAudioSink = modelData
    }

    component InputRow: ListRow {
        required property var modelData

        width: ListView.view.width
        icon: page.inputIcon(modelData)
        title: page.outputLabel(modelData)
        subtitle: page.outputKind(modelData)
        highlighted: page.source === modelData
        trailing: highlighted ? "󰄬" : ""
        onClicked: Pipewire.preferredDefaultAudioSource = modelData
    }

    component AppRow: Item {
        id: app

        required property var modelData
        readonly property var audio: modelData.audio

        width: ListView.view.width
        implicitHeight: 30

        RowLayout {
            anchors.fill: parent
            spacing: Metrics.spacing.normal

            Item {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26

                IconImage {
                    id: appIcon

                    anchors.fill: parent
                    source: page.appIcon(app.modelData)
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: !appIcon.visible
                    text: "󰎆"
                    color: Colors.primary
                    font.family: Metrics.font
                    font.pixelSize: Metrics.text.title
                }

            }

            HorizontalSlider {
                Layout.fillWidth: true
                label: page.appName(app.modelData)
                value: app.audio !== null ? app.audio.volume : 0
                accent: app.audio !== null && app.audio.muted ? Colors.secondary : Colors.primary
                iconButton: true
                icon: app.audio !== null ? page.volumeIcon(app.audio.volume, app.audio.muted) : "󰖁"
                onValueRequested: (value) => {
                    if (app.audio !== null) {
                        app.audio.muted = false;
                        app.audio.volume = value;
                    }
                }
                onIconClicked: {
                    if (app.audio !== null)
                        app.audio.muted = !app.audio.muted;

                }
            }

        }

    }

    PageHeader {
        id: header

        Layout.fillWidth: true
        title: "Sound"
        toggleVisible: false
        onBackRequested: page.back()
    }

    SegmentedControl {
        id: tabBar

        Layout.fillWidth: true
        compact: true
        options: page.tabs
        value: page.tab
        onSelected: (value) => {
            return page.tab = value;
        }
    }

    // As tall as the tab, up to the panel's height. It spills a few pixels over the
    // margins on every side so a hovered block's zoom and bounce aren't clipped.
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(page.currentTab.implicitHeight, page.stack.maxHeight - header.implicitHeight - tabBar.implicitHeight - 2 * page.spacing)

        Flickable {
            id: flickable

            anchors.fill: parent
            anchors.leftMargin: -6
            anchors.rightMargin: -6
            anchors.topMargin: -6
            anchors.bottomMargin: -6
            contentHeight: page.currentTab.implicitHeight + 12
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Connections {
                function onTabChanged() {
                    flickable.contentY = 0;
                }

                target: page
            }

            Item {
                x: 6 - page.tabIndex * (page.width + page.tabGap)
                y: 6
                width: page.width

                Behavior on x {
                    Anim {
                        token: Motion.move.large
                    }

                }

                TabColumn {
                    id: outputTab

                    index: 0

                    AnimatedList {
                        Layout.fillWidth: true
                        rows: page.outputs

                        delegate: OutputRow {
                        }

                    }

                }

                TabColumn {
                    id: inputTab

                    index: 1

                    ControlBlock {
                        Layout.fillWidth: true
                        implicitHeight: microphoneColumn.implicitHeight + 24

                        ColumnLayout {
                            id: microphoneColumn

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Metrics.spacing.large
                            spacing: Metrics.spacing.normal

                            HorizontalSlider {
                                Layout.fillWidth: true
                                label: page.source !== null ? page.outputLabel(page.source) : "No microphone"
                                value: page.sourceAudio !== null ? page.sourceAudio.volume : 0
                                accent: page.sourceAudio !== null && page.sourceAudio.muted ? Colors.secondary : Colors.primary
                                iconButton: true
                                icon: page.sourceAudio === null || page.sourceAudio.muted ? "󰍭" : "󰍬"
                                onValueRequested: (value) => {
                                    if (page.sourceAudio !== null) {
                                        page.sourceAudio.muted = false;
                                        page.sourceAudio.volume = value;
                                    }
                                }
                                onIconClicked: {
                                    if (page.sourceAudio !== null)
                                        page.sourceAudio.muted = !page.sourceAudio.muted;

                                }
                            }

                            // What the microphone hears, while the tab is shown: rises at
                            // once, falls back slowly.
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.leftMargin: Metrics.spacing.small
                                Layout.rightMargin: Metrics.spacing.small
                                implicitHeight: 6
                                radius: 3
                                color: Colors.alpha(Colors.light, 0.12)

                                Rectangle {
                                    height: parent.height
                                    width: Math.max(parent.height, parent.width * level)
                                    radius: parent.radius
                                    color: page.sourceAudio !== null && page.sourceAudio.muted ? Colors.alpha(Colors.secondary, 0.5) : Colors.green
                                    opacity: level > 0.01 ? 1 : 0.4
                                    property real level: {
                                        const peak = page.sourceAudio !== null && page.sourceAudio.muted ? 0 : sourcePeak.peak;
                                        // From -60 dB (empty) to 0 dB (full).
                                        return peak > 0 ? Math.max(0, Math.min(1, (20 * Math.log10(peak) + 60) / 60)) : 0;
                                    }

                                    Behavior on level {
                                        Anim {
                                            token: Motion.move.small
                                        }

                                    }

                                }

                            }

                        }

                    }

                    AnimatedList {
                        Layout.fillWidth: true
                        rows: page.inputs

                        delegate: InputRow {
                        }

                    }

                }

                TabColumn {
                    id: appsTab

                    index: 2

                    ControlBlock {
                        Layout.fillWidth: true
                        implicitHeight: mixerColumn.implicitHeight + 24

                        ColumnLayout {
                            id: mixerColumn

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Metrics.spacing.large
                            spacing: Metrics.spacing.normal

                            EmptyText {
                                visible: page.streams.length === 0
                                text: "No app is playing sound"
                            }

                            AnimatedList {
                                Layout.fillWidth: true
                                spacing: Metrics.spacing.normal
                                rows: page.streams

                                delegate: AppRow {
                                }

                            }

                        }

                    }

                }

                TabColumn {
                    id: devicesTab

                    index: 3

                    ControlBlock {
                        Layout.fillWidth: true
                        visible: page.airPodsShown.length === 0 && page.otherAudio.length === 0
                        implicitHeight: 44

                        EmptyText {
                            anchors.left: parent.left
                            anchors.leftMargin: Metrics.spacing.large
                            anchors.verticalCenter: parent.verticalCenter
                            text: "No audio device connected"
                        }

                    }

                    // Keyed by address: the daemon sends a new list every time, and the panels would
                    // otherwise be rebuilt (forgetting the mode you just picked).
                    Repeater {
                        model: ScriptModel {
                            values: page.airPodsShown.map((device) => {
                                return device.address;
                            })
                        }

                        AirPodsPanel {
                            required property var modelData

                            Layout.fillWidth: true
                            device: AirPods.device(modelData) || {}
                        }

                    }

                    Repeater {
                        model: page.otherAudio

                        ListRow {
                            required property var modelData

                            Layout.fillWidth: true
                            icon: "󰋋"
                            title: modelData.deviceName
                            subtitle: modelData.batteryAvailable ? "Connected · " + Math.round(modelData.battery * 100) + "%" : "Connected"
                            highlighted: true
                            detailsAvailable: true
                            onClicked: page.bluetoothDetailsRequested(modelData)
                            onDetailsRequested: page.bluetoothDetailsRequested(modelData)
                        }

                    }

                }

            }

        }

    }

    PwObjectTracker {
        objects: page.source !== null ? page.streams.concat([page.source]) : page.streams
    }

    PwNodePeakMonitor {
        id: sourcePeak

        node: page.source
        enabled: page.active && page.tab === "input"
    }

    ServiceRef {
        service: AudioPorts
        active: page.active
    }

}
