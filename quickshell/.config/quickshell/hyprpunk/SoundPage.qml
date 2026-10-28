import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Widgets

// The control center's sound page, in tabs: where the sound goes, the microphone
// (volume, level and which one), a mixer for the apps playing, and Bluetooth audio
// (the AirPods with their batteries and settings). Tabs slide in from the side and
// scroll when they're taller than the panel.
ColumnLayout {
    id: page

    required property var airPods
    // Shown in the open panel: the outputs' availability is followed only then.
    property bool active: false
    // The most the page can take: past it, everything under the header scrolls.
    property real maxHeight: Infinity
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
        return node.type === PwNodeType.AudioSink && (portInfo[node.name] === undefined || portInfo[node.name].available);
    })
    readonly property var inputs: Pipewire.nodes.values.filter((node) => {
        return node.type === PwNodeType.AudioSource && (portInfo[node.name] === undefined || portInfo[node.name].available);
    })
    readonly property var streams: Pipewire.nodes.values.filter((node) => {
        return node.type === PwNodeType.AudioOutStream && node.audio !== null;
    })
    readonly property var bluetoothAudio: {
        const adapter = Bluetooth.defaultAdapter;
        if (adapter === null)
            return [];

        return adapter.devices.values.filter((device) => {
            return device.connected && device.icon.startsWith("audio");
        });
    }
    // AirPods connected or only nearby: their batteries come either way.
    readonly property var airPodsShown: airPods.devices.filter((device) => {
        return device.connected || device.nearby;
    })
    // The other audio devices connected.
    readonly property var otherAudio: bluetoothAudio.filter((device) => {
        return airPods.device(device.address) === null;
    })
    // From pactl, by sink and source name: {label (the port's name, for a sound card),
    // available (false for an HDMI output with nothing plugged in)}.
    property var portInfo: ({
    })

    signal backRequested()
    signal bluetoothDetailsRequested(var device)

    function volumeIcon(volume, muted) {
        if (muted || volume === 0)
            return "󰖁";

        return volume < 0.34 ? "󰕿" : volume < 0.67 ? "󰖀" : "󰕾";
    }

    function outputLabel(node) {
        const info = portInfo[node.name];
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

    // Adds the ports of pactl's sinks or sources to portInfo.
    function readPorts(text) {
        let devices;
        try {
            devices = JSON.parse(text);
        } catch (error) {
            return ;
        }
        const info = Object.assign({
        }, portInfo);
        for (const device of devices) {
            const port = (device.ports || []).find((item) => {
                return item.name === device.active_port;
            });
            info[device.name] = {
                "label": port !== undefined && device.properties["device.bus"] !== "bluetooth" ? port.description : "",
                "available": port === undefined || port.availability !== "not available"
            };
        }
        portInfo = info;
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

    spacing: 12
    onActiveChanged: {
        if (active) {
            portProbe.running = true;
            sourceProbe.running = true;
        }

    }

    // One tab, side by side with the others: only the one shown is opaque and clickable,
    // the others fade as they slide away.
    component TabColumn: ColumnLayout {
        required property int index
        readonly property bool current: index === page.tabIndex

        x: index * (page.width + page.tabGap)
        width: page.width
        spacing: 12
        enabled: current
        opacity: current ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }

        }

    }

    component EmptyText: Text {
        color: "#7f849c"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
    }

    // A list at full height (the page scrolls, not the list). Rows fade in as they come,
    // fade out as they go, and the rest slide into place.
    component AnimatedList: ListView {
        implicitHeight: contentHeight
        interactive: false
        spacing: 6

        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 220
            }

            NumberAnimation {
                property: "scale"
                from: 0.92
                to: 1
                duration: 260
                easing.type: Easing.OutBack
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
            spacing: 10

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
                    color: "#cba6f7"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                }

            }

            HorizontalSlider {
                Layout.fillWidth: true
                label: page.appName(app.modelData)
                value: app.audio !== null ? app.audio.volume : 0
                accent: app.audio !== null && app.audio.muted ? "#b4befe" : "#cba6f7"
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
        onBackRequested: page.backRequested()
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
        Layout.preferredHeight: Math.min(page.currentTab.implicitHeight, page.maxHeight - header.implicitHeight - tabBar.implicitHeight - 2 * page.spacing)

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
                    NumberAnimation {
                        duration: 340
                        easing.type: Easing.OutCubic
                    }

                }

                TabColumn {
                    id: outputTab

                    index: 0

                    AnimatedList {
                        Layout.fillWidth: true
                        model: page.outputs

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
                            anchors.margins: 12
                            spacing: 10

                            HorizontalSlider {
                                Layout.fillWidth: true
                                label: page.source !== null ? page.outputLabel(page.source) : "No microphone"
                                value: page.sourceAudio !== null ? page.sourceAudio.volume : 0
                                accent: page.sourceAudio !== null && page.sourceAudio.muted ? "#b4befe" : "#cba6f7"
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
                                Layout.leftMargin: 4
                                Layout.rightMargin: 4
                                implicitHeight: 6
                                radius: 3
                                color: Qt.rgba(205 / 255, 214 / 255, 244 / 255, 0.12)

                                Rectangle {
                                    height: parent.height
                                    width: Math.max(parent.height, parent.width * level)
                                    radius: parent.radius
                                    color: page.sourceAudio !== null && page.sourceAudio.muted ? "#7f849c" : "#a6e3a1"
                                    opacity: level > 0.01 ? 1 : 0.4
                                    property real level: {
                                        const peak = page.sourceAudio !== null && page.sourceAudio.muted ? 0 : sourcePeak.peak;
                                        // From -60 dB (empty) to 0 dB (full).
                                        return peak > 0 ? Math.max(0, Math.min(1, (20 * Math.log10(peak) + 60) / 60)) : 0;
                                    }

                                    Behavior on level {
                                        NumberAnimation {
                                            duration: 160
                                            easing.type: Easing.OutCubic
                                        }

                                    }

                                }

                            }

                        }

                    }

                    AnimatedList {
                        Layout.fillWidth: true
                        model: page.inputs

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
                            anchors.margins: 12
                            spacing: 10

                            EmptyText {
                                visible: page.streams.length === 0
                                text: "No app is playing sound"
                            }

                            AnimatedList {
                                Layout.fillWidth: true
                                spacing: 10
                                model: page.streams

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
                            anchors.leftMargin: 12
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
                            airPods: page.airPods
                            device: page.airPods.device(modelData) || {}
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

    // Names and availability of the outputs, which PipeWire's nodes do not tell.
    Process {
        id: portProbe

        command: ["pactl", "-f", "json", "list", "sinks"]

        stdout: StdioCollector {
            onStreamFinished: page.readPorts(text)
        }

    }

    Process {
        id: sourceProbe

        command: ["pactl", "-f", "json", "list", "sources"]

        stdout: StdioCollector {
            onStreamFinished: page.readPorts(text)
        }

    }

    // A screen, headphones or a microphone plugged in while the page is open.
    Process {
        running: page.active
        command: ["pactl", "subscribe"]

        stdout: SplitParser {
            onRead: (line) => {
                if (/ on (sink|source|card) /.test(line))
                    portRefresh.restart();

            }
        }

    }

    Timer {
        id: portRefresh

        interval: 300
        onTriggered: {
            portProbe.running = true;
            sourceProbe.running = true;
        }
    }

}
