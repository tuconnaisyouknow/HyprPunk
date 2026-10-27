import QtQuick
import Quickshell
import Quickshell.Io

// Monitor settings in the dynamic island: the outputs drawn to scale (a click
// selects one), then the settings of the selected output, applied right away
// through ~/Scripts/displayctl.sh. A resolution, refresh rate or scale change asks
// to be kept and reverts on its own otherwise.
IslandPanel {
    id: monitors

    readonly property string displayctl: Quickshell.env("HOME") + "/Scripts/displayctl.sh"
    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/hyprpunk/monitor-state.conf"
    readonly property string backupFile: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/hyprpunk/monitor-state.backup"
    readonly property int cardPadding: 14
    readonly property int previewHeight: 150
    readonly property int revertSeconds: 15
    readonly property var scales: ["auto", "1", "1.25", "1.5", "1.75", "2"]
    // From displayctl info: { layout, default_scale, outputs: [...] }.
    property var info: ({
        "layout": "auto",
        "default_scale": "auto",
        "outputs": []
    })
    property string selectedName: ""
    // Output the selected one is positioned against.
    property string referenceName: ""
    property bool resetArmed: false
    // Seconds left before the last resolution, refresh rate or scale change reverts, 0 when none.
    property int revertCountdown: 0
    readonly property var outputs: info.outputs
    readonly property var selected: outputs.find((output) => {
        return output.name === selectedName;
    }) || outputs[0] || null
    readonly property var others: selected ? outputs.filter((output) => {
        return output.name !== selected.name;
    }) : []
    readonly property bool busy: applyProcess.running || infoProcess.running
    readonly property var resolutions: {
        if (!selected)
            return [];

        const sizes = [];
        for (const mode of selected.modes) {
            const size = mode.split("@")[0];
            if (!sizes.includes(size))
                sizes.push(size);

        }
        return sizes.sort((a, b) => {
            const [aw, ah] = a.split("x").map(Number);
            const [bw, bh] = b.split("x").map(Number);
            return bw * bh - aw * ah;
        });
    }
    readonly property var frequencies: {
        if (!selected)
            return [];

        const size = selected.width + "x" + selected.height + "@";
        const rates = [];
        for (const mode of selected.modes) {
            if (mode.startsWith(size)) {
                const rate = mode.slice(size.length).replace(/Hz$/, "");
                if (!rates.includes(rate))
                    rates.push(rate);

            }
        }
        return rates.sort((a, b) => {
            return Number(b) - Number(a);
        });
    }
    // "above:<id>" -> { "direction": "above", "reference": output name }.
    readonly property var relative: {
        if (!selected || selected.relative === "")
            return null;

        const [direction, id] = selected.relative.split(":");
        const reference = outputs.find((output) => {
            return output.id === id;
        });
        return reference ? {
            "direction": direction,
            "reference": reference.name
        } : null;
    }

    function refresh() {
        infoProcess.running = true;
    }

    // guarded: a resolution, refresh rate or scale change, which can be reverted.
    function apply(args, guarded) {
        if (busy)
            return ;

        resetArmed = false;
        if (guarded) {
            applyProcess.command = ["bash", "-c", "mkdir -p \"$(dirname \"$1\")\"; if [[ -f $0 ]]; then cp -f \"$0\" \"$1\"; else rm -f \"$1\"; fi; shift; exec \"$@\"", stateFile, backupFile, displayctl].concat(args);
            revertCountdown = revertSeconds;
            revertTimer.restart();
        } else {
            applyProcess.command = [displayctl].concat(args);
        }
        applyProcess.running = true;
    }

    function keep() {
        revertCountdown = 0;
        revertTimer.stop();
    }

    function revert() {
        keep();
        Quickshell.execDetached(["bash", "-c", "flock -w 10 \"$0.lock\" bash -c 'if [[ -f $1 ]]; then cp -f \"$1\" \"$0\"; else rm -f \"$0\"; fi' \"$0\" \"$1\" && hyprctl reload >/dev/null", stateFile, backupFile]);
        revertRefresh.restart();
    }

    function rateLabel(rate) {
        return Number(rate).toFixed(2).replace(/\.?0+$/, "") + " Hz";
    }

    function scaleLabel(scale) {
        return scale === "auto" ? "Auto" : scale + "×";
    }

    function outputWorkspaces(output) {
        return output && output.workspaces !== "" && output.workspaces !== "none" ? output.workspaces.split(",") : [];
    }

    // Output owning a workspace, "" when none.
    function workspaceOwner(workspace) {
        const owner = outputs.find((output) => {
            return outputWorkspaces(output).includes(workspace);
        });
        return owner ? owner.name : "";
    }

    function toggleWorkspace(workspace) {
        const current = outputWorkspaces(selected);
        const list = current.includes(workspace) ? current.filter((item) => {
            return item !== workspace;
        }) : current.concat([workspace]).sort((a, b) => {
            return Number(a) - Number(b);
        });
        apply(["workspace-set", selected.name, list.length > 0 ? list.join(",") : "none"], false);
    }

    function reset() {
        if (!resetArmed) {
            resetArmed = true;
            disarmDelay.restart();
            return ;
        }
        apply(["reset"], false);
    }

    function selectOutput(delta) {
        if (outputs.length < 2)
            return ;

        const index = outputs.findIndex((output) => {
            return output.name === selected.name;
        });
        selectedName = outputs[(index + delta + outputs.length) % outputs.length].name;
    }

    panelName: "monitor"
    cardWidth: 640
    cardHeight: content.implicitHeight + 2 * cardPadding
    keyTargets: [keys]
    onOpening: {
        resetArmed = false;
        selectedName = "";
        refresh();
    }
    // Closing keeps a change waiting to be confirmed.
    onOpenedChanged: {
        if (!opened && revertCountdown > 0)
            keep();

    }
    onSelectedChanged: {
        if (selected && !others.some((output) => {
            return output.name === referenceName;
        }))
            referenceName = relative ? relative.reference : others.length > 0 ? others[0].name : "";

    }

    Behavior on cardHeight {
        enabled: monitors.opened

        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }

    }

    Process {
        id: infoProcess

        command: [monitors.displayctl, "info"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const info = JSON.parse(text);
                    monitors.info = info;
                    if (monitors.selectedName === "" || !info.outputs.some((output) => {
                        return output.name === monitors.selectedName;
                    })) {
                        const focused = info.outputs.find((output) => {
                            return output.focused;
                        });
                        monitors.selectedName = focused ? focused.name : info.outputs.length > 0 ? info.outputs[0].name : "";
                    }
                } catch (error) {
                    console.warn("displayctl info:", error);
                }
            }
        }

    }

    Process {
        id: applyProcess

        onExited: (exitCode) => {
            if (exitCode !== 0) {
                monitors.keep();
                Quickshell.execDetached(["notify-send", "-u", "normal", "Unable to change the monitor settings", applyErrors.text.trim().split("\n").pop() || ""]);
            }
            monitors.refresh();
        }

        stderr: StdioCollector {
            id: applyErrors
        }

    }

    Timer {
        id: revertTimer

        interval: 1000
        repeat: true
        onTriggered: {
            monitors.revertCountdown -= 1;
            if (monitors.revertCountdown <= 0)
                monitors.revert();

        }
    }

    // Hyprland takes a moment to apply the restored state.
    Timer {
        id: revertRefresh

        interval: 600
        onTriggered: monitors.refresh()
    }

    Timer {
        id: disarmDelay

        interval: 3000
        onTriggered: monitors.resetArmed = false
    }

    Item {
        id: keys

        Keys.onTabPressed: monitors.selectOutput(1)
        Keys.onBacktabPressed: monitors.selectOutput(-1)
        Keys.onReturnPressed: {
            if (monitors.revertCountdown > 0)
                monitors.keep();

        }
        Keys.onEnterPressed: {
            if (monitors.revertCountdown > 0)
                monitors.keep();

        }
    }

    // Glass pill, mauve when selected.
    component Chip: Rectangle {
        id: chip

        property string text
        property bool selected: false
        property bool dimmed: false
        property color selectedColor: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.9)

        signal clicked()

        width: Math.max(height, label.implicitWidth + 22)
        height: 30
        radius: 10
        color: "transparent"
        // Disabled through the panel while displayctl runs.
        opacity: enabled ? 1 : 0.6
        scale: chipTap.pressed ? 0.94 : 1

        GlassSurface {
            radius: parent.radius
            hovered: chipHover.hovered
            backgroundColor: chip.selected ? chip.selectedColor : "transparent"

            Behavior on backgroundColor {
                ColorAnimation {
                    duration: 140
                }

            }

        }

        Text {
            id: label

            anchors.centerIn: parent
            text: chip.text
            color: chip.selected ? "#1e1e2e" : chip.dimmed ? "#6c7086" : "#cdd6f4"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            font.weight: chip.selected ? Font.Bold : Font.Normal
        }

        HoverHandler {
            id: chipHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: chipTap

            onTapped: chip.clicked()
        }

        Behavior on scale {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutBack
            }

        }

    }

    // Label on the left, chips wrapping on the right.
    component SettingRow: Item {
        id: settingRow

        property string title
        property int labelWidth: 112
        default property alias chips: chipFlow.data

        width: parent ? parent.width : 0
        implicitHeight: Math.max(30, chipFlow.implicitHeight)

        Text {
            anchors.top: parent.top
            anchors.topMargin: 7
            text: settingRow.title
            color: "#cba6f7"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            font.weight: Font.Bold
        }

        Flow {
            id: chipFlow

            x: settingRow.labelWidth
            width: parent.width - settingRow.labelWidth
            spacing: 6
        }

    }

    Column {
        id: content

        anchors.top: parent.top
        anchors.topMargin: monitors.cardPadding
        anchors.horizontalCenter: parent.horizontalCenter
        width: monitors.cardWidth - 2 * monitors.cardPadding
        enabled: !monitors.busy
        spacing: 12

        // The outputs at their logical size and position.
        Item {
            id: preview

            readonly property var rects: monitors.outputs.map((output) => {
                const rotated = output.transform % 2 === 1;
                const width = (rotated ? output.height : output.width) / output.current_scale;
                const height = (rotated ? output.width : output.height) / output.current_scale;
                return {
                    "output": output,
                    "x": output.x,
                    "y": output.y,
                    "width": width,
                    "height": height
                };
            })
            readonly property real minX: Math.min(...rects.map((rect) => {
                return rect.x;
            }))
            readonly property real minY: Math.min(...rects.map((rect) => {
                return rect.y;
            }))
            readonly property real boundsWidth: Math.max(...rects.map((rect) => {
                return rect.x + rect.width;
            })) - minX
            readonly property real boundsHeight: Math.max(...rects.map((rect) => {
                return rect.y + rect.height;
            })) - minY
            readonly property real factor: rects.length > 0 ? Math.min((width - 40) / boundsWidth, (height - 24) / boundsHeight, 0.1) : 1

            width: parent.width
            height: monitors.previewHeight

            Rectangle {
                anchors.fill: parent
                radius: 16
                color: Qt.rgba(17 / 255, 17 / 255, 27 / 255, 0.5)
            }

            Text {
                anchors.centerIn: parent
                visible: monitors.outputs.length === 0
                text: monitors.busy ? "Loading…" : "No output"
                color: "#7f849c"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
            }

            Repeater {
                model: preview.rects

                Rectangle {
                    id: screenRect

                    required property var modelData
                    readonly property bool selected: monitors.selected !== null && monitors.selected.name === modelData.output.name

                    x: (preview.width - preview.boundsWidth * preview.factor) / 2 + (modelData.x - preview.minX) * preview.factor
                    y: (preview.height - preview.boundsHeight * preview.factor) / 2 + (modelData.y - preview.minY) * preview.factor
                    width: modelData.width * preview.factor - 4
                    height: modelData.height * preview.factor - 4
                    radius: 10
                    color: "transparent"

                    GlassSurface {
                        radius: parent.radius
                        hovered: screenHover.hovered
                        backgroundColor: screenRect.selected ? Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.25) : Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.8)
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.width: 2
                        border.color: "#cba6f7"
                        visible: screenRect.selected
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: screenRect.modelData.output.slot || "?"
                            color: "#cba6f7"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 22
                            font.weight: Font.Bold
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: screenRect.modelData.output.name
                            color: "#b4befe"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                        }

                    }

                    HoverHandler {
                        id: screenHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: monitors.selectedName = screenRect.modelData.output.name
                    }

                }

            }

        }

        Text {
            width: parent.width
            visible: monitors.selected !== null
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: monitors.selected ? monitors.selected.description + " · " + monitors.selected.width + "x" + monitors.selected.height + " · " + monitors.rateLabel(monitors.selected.refresh_rate) : ""
            color: "#7f849c"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
        }

        SettingRow {
            title: "Resolution"
            visible: monitors.selected !== null

            Chip {
                text: "Auto"
                selected: monitors.selected !== null && (monitors.selected.mode === "" || monitors.selected.mode === "preferred")
                onClicked: monitors.apply(["auto", monitors.selected.name], true)
            }

            Repeater {
                model: monitors.resolutions

                Chip {
                    required property string modelData

                    text: modelData
                    selected: monitors.selected.mode.split("@")[0] === modelData
                    onClicked: monitors.apply(["resolution", monitors.selected.name, modelData], true)
                }

            }

        }

        SettingRow {
            title: "Refresh rate"
            visible: monitors.selected !== null

            Repeater {
                model: monitors.frequencies

                Chip {
                    required property string modelData

                    text: monitors.rateLabel(modelData)
                    selected: Math.abs(Number(modelData) - monitors.selected.refresh_rate) < 0.01
                    onClicked: monitors.apply(["refresh", monitors.selected.name, modelData], true)
                }

            }

        }

        SettingRow {
            title: "Scale"
            visible: monitors.selected !== null

            Repeater {
                model: monitors.scales

                Chip {
                    required property string modelData

                    text: monitors.scaleLabel(modelData)
                    selected: monitors.selected !== null && (monitors.selected.scale || monitors.info.default_scale) === modelData
                    onClicked: monitors.apply(["scale", monitors.selected.name, modelData], true)
                }

            }

        }

        // Order of the outputs (their workspace and the number on the bar).
        SettingRow {
            title: "Number"
            visible: monitors.selected !== null

            Repeater {
                model: 10

                Chip {
                    required property int index

                    text: String(index + 1)
                    selected: monitors.selected !== null && monitors.selected.slot === String(index + 1)
                    onClicked: monitors.apply(["slot", monitors.selected.name, String(index + 1)], false)
                }

            }

        }

        // Dimmed: assigned to another output (taking it moves it here).
        SettingRow {
            title: "Workspaces"
            visible: monitors.selected !== null

            Repeater {
                model: 10

                Chip {
                    required property int index
                    readonly property string workspace: String(index + 1)
                    readonly property string owner: monitors.workspaceOwner(workspace)

                    text: workspace
                    selected: monitors.selected !== null && owner === monitors.selected.name
                    dimmed: owner !== "" && !selected
                    onClicked: monitors.toggleWorkspace(workspace)
                }

            }

        }

        SettingRow {
            title: "Position"
            visible: monitors.others.length > 0

            Repeater {
                model: ["left", "right", "above", "below"]

                Chip {
                    required property string modelData

                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                    selected: monitors.relative !== null && monitors.relative.direction === modelData && monitors.relative.reference === monitors.referenceName
                    onClicked: monitors.apply(["position", monitors.selected.name, modelData, monitors.referenceName], false)
                }

            }

        }

        SettingRow {
            title: "Relative to"
            visible: monitors.others.length > 1

            Repeater {
                model: monitors.others

                Chip {
                    required property var modelData

                    text: modelData.name
                    selected: monitors.referenceName === modelData.name
                    onClicked: monitors.referenceName = modelData.name
                }

            }

        }

        // Layout actions, or the confirmation of the last change.
        Item {
            width: parent.width
            height: 34

            Row {
                anchors.centerIn: parent
                spacing: 8
                visible: monitors.revertCountdown === 0

                Chip {
                    height: 34
                    text: "Automatic layout"
                    selected: monitors.info.layout === "auto"
                    onClicked: monitors.apply(["auto-layout"], false)
                }

                Chip {
                    height: 34
                    text: monitors.resetArmed ? "Click again to reset" : "Reset all settings"
                    selected: monitors.resetArmed
                    selectedColor: Qt.rgba(243 / 255, 139 / 255, 168 / 255, 0.9)
                    onClicked: monitors.reset()
                }

            }

            Row {
                anchors.centerIn: parent
                spacing: 8
                visible: monitors.revertCountdown > 0

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Keep these settings? Reverting in " + monitors.revertCountdown + " s"
                    color: "#cdd6f4"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                }

                Chip {
                    height: 34
                    text: "Keep"
                    selected: true
                    onClicked: monitors.keep()
                }

                Chip {
                    height: 34
                    text: "Revert"
                    onClicked: monitors.revert()
                }

            }

        }

    }

}
