import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// The settings' displays page: your screens drawn to scale, dragged where they go, then
// the settings of the one you pick, applied straight away through displayctl.sh. A new
// resolution, refresh rate or scale asks if you want to keep it, and undoes itself if
// you don't answer; closing the window keeps it.
ColumnLayout {
    id: page

    readonly property string displayctl: Session.scripts + "/displayctl.sh"
    readonly property string stateFile: Session.stateDir + "/monitor-state.conf"
    readonly property string backupFile: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/hyprpunk/monitor-state.backup"
    readonly property int revertSeconds: 15
    // From displayctl info: { layout, default_scale, outputs: [...] }.
    property var info: ({
        "layout": "auto",
        "default_scale": "auto",
        "outputs": []
    })
    property string selectedName: ""
    // The screens' names, only replaced when one comes or goes, so the drawing keeps its
    // screens (and the keyboard on one) when the layout changes.
    property var names: []
    // Seconds left before the last resolution, refresh rate or scale change reverts, 0 when none.
    property int revertCountdown: 0
    readonly property var outputs: info.outputs
    readonly property var selected: outputs.find((output) => {
        return output.name === selectedName;
    }) || outputs[0] || null
    readonly property bool busy: applyProcess.running || infoProcess.running
    // Largest first.
    readonly property var resolutions: {
        if (!selected)
            return [];

        const sizes = [];
        for (const mode of selected.modes) {
            const size = mode.split("@")[0];
            if (!sizes.includes(size))
                sizes.push(size);

        }
        return ["auto"].concat(sizes.sort((a, b) => {
            const [aw, ah] = a.split("x").map(Number);
            const [bw, bh] = b.split("x").map(Number);
            return bw * bh - aw * ah;
        }));
    }
    readonly property string resolution: !selected ? "" : selected.mode === "" || selected.mode === "preferred" ? "auto" : selected.mode.split("@")[0]
    // The current resolution's, fastest first.
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
    readonly property string frequency: selected ? frequencies.find((rate) => {
        return Math.abs(Number(rate) - selected.refresh_rate) < 0.01;
    }) || "" : ""
    function refresh() {
        infoProcess.running = true;
    }

    // guarded: a resolution, refresh rate or scale change, which can undo itself.
    function apply(args, guarded) {
        if (busy)
            return ;

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
        Quickshell.execDetached(["bash", "-c", "flock -w 10 \"$0.lock\" bash -c 'if [[ -f $1 ]]; then cp -f \"$1\" \"$0\"; else rm -f \"$0\"; fi' \"$0\" \"$1\" && \"$2\" reload", stateFile, backupFile, displayctl]);
        revertRefresh.restart();
    }

    function rateLabel(rate) {
        return Number(rate).toFixed(2).replace(/\.?0+$/, "") + " Hz";
    }

    function workspaces(output) {
        return output && output.workspaces !== "" && output.workspaces !== "none" ? output.workspaces.split(",") : [];
    }

    // The screen holding a workspace, "" when none.
    function workspaceOwner(workspace) {
        const owner = outputs.find((output) => {
            return workspaces(output).includes(workspace);
        });
        return owner ? owner.name : "";
    }

    function toggleWorkspace(workspace) {
        const current = workspaces(selected);
        const list = current.includes(workspace) ? current.filter((item) => {
            return item !== workspace;
        }) : current.concat([workspace]).sort((a, b) => {
            return Number(a) - Number(b);
        });
        apply(["workspace-set", selected.name, list.length > 0 ? list.join(",") : "none"], false);
    }

    // Where a screen can go, as displayctl.sh places it: against a side of another,
    // lined up on its top or left edge, over none of the others. In the layout's pixels.
    function placements(name) {
        const moved = preview.rectOf(name);
        const others = preview.rects.filter((rect) => {
            return rect.output.name !== name;
        });
        const overlaps = (x, y, rect) => {
            return x < rect.x + rect.width && x + moved.width > rect.x && y < rect.y + rect.height && y + moved.height > rect.y;
        };
        const found = [];
        for (const other of others) {
            for (const [direction, x, y] of [["left", other.x - moved.width, other.y], ["right", other.x + other.width, other.y], ["above", other.x, other.y - moved.height], ["below", other.x, other.y + other.height]]) {
                if (!others.some((rect) => {
                    return overlaps(x, y, rect);
                }))
                    found.push({
                        "direction": direction,
                        "reference": other.output.name,
                        "x": x,
                        "y": y
                    });

            }
        }
        return found;
    }

    // The place nearest to where the screen was dropped.
    function nearest(name, x, y) {
        let best = null;
        for (const place of placements(name)) {
            if (best === null || Math.hypot(place.x - x, place.y - y) < Math.hypot(best.x - x, best.y - y))
                best = place;

        }
        return best;
    }

    // The next place that way, for Shift and the arrows.
    function step(name, dx, dy) {
        const from = preview.rectOf(name);
        let best = null;
        let bestDistance = Infinity;
        for (const place of placements(name)) {
            const along = (place.x - from.x) * dx + (place.y - from.y) * dy;
            const distance = Math.hypot(place.x - from.x, place.y - from.y);
            if (along > 0 && distance < bestDistance) {
                best = place;
                bestDistance = distance;
            }
        }
        return best;
    }

    // Puts a screen there, unless it's already there.
    function place(name, spot) {
        const moved = preview.rectOf(name);
        if (spot !== null && (spot.x !== moved.x || spot.y !== moved.y))
            apply(["position", name, spot.direction, spot.reference], false);

    }

    spacing: 12
    Component.onCompleted: refresh()

    Text {
        text: "Displays"
        color: Theme.primary
        font.family: Theme.font
        font.pixelSize: 20
        font.weight: Font.Bold
    }

    Text {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        text: "Drag a screen against another to place it, or move the one you're on with Shift and the arrows. Each is remembered as it is, whichever port it's plugged into."
        color: Theme.secondary
        wrapMode: Text.Wrap
        font.family: Theme.font
        font.pixelSize: 12
    }

    // The screens at their size and place. A click picks one; dragged, it follows the
    // pointer and shows where it will go against the others, and goes there when dropped.
    // Shift and the arrows move the one with the keyboard. At rest the drawing fits the
    // screens; while one is dragged it eases out to fit every place it can take.
    Item {
        id: preview

        readonly property var rects: page.outputs.map((output) => {
            const rotated = output.transform % 2 === 1;
            return {
                "output": output,
                "x": output.x,
                "y": output.y,
                "width": (rotated ? output.height : output.width) / output.current_scale,
                "height": (rotated ? output.width : output.height) / output.current_scale
            };
        })
        // The screens' outline, in the layout's pixels.
        readonly property var layout: bounds(rects)
        // The screen being dragged, "" while none is, and where it would go.
        property string dragged: ""
        property var target: null
        // Every place the dragged screen can take, with the screens. Kept after the
        // drop so the drawing eases back from it.
        property var reach: layout
        // How far the drawing has eased out to the reach: 0 at rest, 1 while dragging.
        // Only a drag moves it, so the screens arriving when the page opens don't.
        property real spread: dragged !== "" ? 1 : 0
        readonly property real frameX: layout.x + (reach.x - layout.x) * spread
        readonly property real frameY: layout.y + (reach.y - layout.y) * spread
        readonly property real frameWidth: layout.width + (reach.width - layout.width) * spread
        readonly property real frameHeight: layout.height + (reach.height - layout.height) * spread
        readonly property real padding: 16
        readonly property real factor: Math.min((width - 2 * padding) / Math.max(1, frameWidth), (height - 2 * padding) / Math.max(1, frameHeight))
        // The layout's point drawn at the preview's (0, 0), the frame in the middle.
        readonly property real originX: frameX - (width / factor - frameWidth) / 2
        readonly property real originY: frameY - (height / factor - frameHeight) / 2

        function bounds(list) {
            if (list.length === 0)
                return {
                "x": 0,
                "y": 0,
                "width": 16,
                "height": 9
            };

            const left = Math.min(...list.map((rect) => {
                return rect.x;
            }));
            const top = Math.min(...list.map((rect) => {
                return rect.y;
            }));
            return {
                "x": left,
                "y": top,
                "width": Math.max(...list.map((rect) => {
                    return rect.x + rect.width;
                })) - left,
                "height": Math.max(...list.map((rect) => {
                    return rect.y + rect.height;
                })) - top
            };
        }

        function rectOf(name) {
            return rects.find((rect) => {
                return rect.output.name === name;
            }) || null;
        }

        // A point of the preview in the layout's pixels, and back.
        function toLayout(x, y) {
            return Qt.point(x / factor + originX, y / factor + originY);
        }

        function toPreview(x, y) {
            return Qt.point((x - originX) * factor, (y - originY) * factor);
        }

        Layout.fillWidth: true
        clip: true
        // As tall as the screens' shape asks, within reason.
        Layout.preferredHeight: Math.max(160, Math.min(320, (width - 2 * padding) * layout.height / layout.width + 2 * padding))

        onDraggedChanged: {
            if (dragged === "")
                return ;

            const moved = rectOf(dragged);
            reach = bounds(rects.concat(page.placements(dragged).map((spot) => {
                return {
                    "x": spot.x,
                    "y": spot.y,
                    "width": moved.width,
                    "height": moved.height
                };
            })));
        }

        Behavior on spread {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }

        }

        GlassSurface {
            radius: 18
        }

        Text {
            anchors.centerIn: parent
            visible: page.outputs.length === 0
            text: page.busy ? "Loading…" : "No screen found"
            color: Theme.secondary
            font.family: Theme.font
            font.pixelSize: 14
        }

        // The place the dragged screen would take.
        Rectangle {
            readonly property var moved: preview.target !== null ? preview.rectOf(preview.dragged) : null

            visible: moved !== null
            x: moved !== null ? preview.toPreview(preview.target.x, preview.target.y).x + 2 : 0
            y: moved !== null ? preview.toPreview(preview.target.x, preview.target.y).y + 2 : 0
            width: moved !== null ? moved.width * preview.factor - 4 : 0
            height: moved !== null ? moved.height * preview.factor - 4 : 0
            radius: 10
            color: Theme.alpha(Theme.primary, 0.12)
            border.width: 1.5
            border.color: Theme.alpha(Theme.primary, 0.85)
        }

        Repeater {
            model: page.names

            Item {
                id: screenRect

                required property string modelData
                readonly property var rect: preview.rectOf(modelData)
                readonly property bool chosen: page.selected !== null && page.selected.name === modelData
                readonly property real radius: 10
                // Where it's drawn in the layout: its place, the pointer's while dragged,
                // and the place it was dropped on until the layout comes back with it.
                property var held: null
                // Where it was caught, as a share of its width and height, so the same
                // point stays under the pointer as the drawing eases out and it shrinks.
                property point grab: Qt.point(0, 0)
                property point pointer: Qt.point(0, 0)
                readonly property point topLeft: drag.active ? caughtAt(pointer) : held !== null ? Qt.point(held.x, held.y) : rect !== null ? Qt.point(rect.x, rect.y) : Qt.point(0, 0)

                function activate() {
                    page.selectedName = modelData;
                }

                // Its top left in the layout with the pointer at a point of the preview.
                function caughtAt(point) {
                    const at = preview.toLayout(point.x, point.y);
                    return Qt.point(at.x - grab.x * rect.width, at.y - grab.y * rect.height);
                }

                visible: rect !== null
                x: preview.toPreview(topLeft.x, topLeft.y).x + 2
                y: preview.toPreview(topLeft.x, topLeft.y).y + 2
                z: drag.active ? 1 : 0
                width: rect !== null ? rect.width * preview.factor - 4 : 0
                height: rect !== null ? rect.height * preview.factor - 4 : 0
                activeFocusOnTab: true
                onRectChanged: held = null
                Keys.onPressed: (event) => {
                    const direction = Navigation.direction(event);
                    if (!(event.modifiers & Qt.ShiftModifier) || direction === null)
                        return ;

                    page.selectedName = modelData;
                    page.place(modelData, page.step(modelData, direction[0], direction[1]));
                    event.accepted = true;
                }

                GlassSurface {
                    radius: screenRect.radius
                    hovered: screenHover.hovered
                    backgroundColor: screenRect.chosen ? Theme.alpha(Theme.primary, 0.85) : "transparent"
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: screenRect.rect !== null ? screenRect.rect.output.slot || "?" : ""
                        color: screenRect.chosen ? Theme.base : Theme.primary
                        font.family: Theme.font
                        font.pixelSize: 22
                        font.weight: Font.Bold
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: screenRect.modelData
                        color: screenRect.chosen ? Theme.base : Theme.secondary
                        font.family: Theme.font
                        font.pixelSize: 11
                    }

                }

                HoverHandler {
                    id: screenHover

                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: screenRect.activate()
                }

                // Alone, a screen has nowhere else to go.
                DragHandler {
                    id: drag

                    target: null
                    enabled: page.names.length > 1 && !page.busy
                    onCentroidChanged: {
                        if (!active)
                            return ;

                        screenRect.pointer = preview.mapFromItem(null, centroid.scenePosition);
                        const at = screenRect.caughtAt(screenRect.pointer);
                        preview.target = page.nearest(screenRect.modelData, at.x, at.y);
                    }
                    onActiveChanged: {
                        if (active) {
                            // Its drawn edge is 2 px inside its place.
                            screenRect.grab = Qt.point((centroid.pressPosition.x + 2) / (screenRect.width + 4), (centroid.pressPosition.y + 2) / (screenRect.height + 4));
                            screenRect.pointer = preview.mapFromItem(null, centroid.scenePressPosition);
                            page.selectedName = screenRect.modelData;
                            preview.dragged = screenRect.modelData;
                            return ;
                        }
                        const spot = preview.target;
                        preview.target = null;
                        preview.dragged = "";
                        if (spot !== null && (spot.x !== screenRect.rect.x || spot.y !== screenRect.rect.y)) {
                            screenRect.held = spot;
                            page.place(screenRect.modelData, spot);
                        }
                    }
                }

            }

        }

    }

    // A change that undoes itself unless you keep it.
    SettingRow {
        Layout.fillWidth: true
        visible: page.revertCountdown > 0
        icon: "󰔛"
        title: "Keep these settings?"
        description: "They go back as they were in " + page.revertCountdown + " s."

        RowLayout {
            width: parent.width
            spacing: 8

            ActionRow {
                Layout.fillWidth: true
                icon: "󰄬"
                label: "Keep"
                onTriggered: page.keep()
            }

            ActionRow {
                Layout.fillWidth: true
                icon: "󰕌"
                label: "Revert"
                onTriggered: page.revert()
            }

        }

    }

    // The screens by name, for the keys; the drawing above does the same.
    SettingRow {
        Layout.fillWidth: true
        visible: page.outputs.length > 1
        icon: "󰍹"
        title: "Screen"
        description: page.selected ? page.selected.description : ""

        SettingChoices {
            width: parent.width
            values: page.outputs.map((output) => {
                return output.name;
            })
            value: page.selected ? page.selected.name : null
            onSelected: (value) => {
                return page.selectedName = value;
            }
        }

    }

    SettingRow {
        Layout.fillWidth: true
        visible: page.selected !== null
        icon: "󰹑"
        title: "Resolution"
        description: page.outputs.length > 1 || !page.selected ? "" : page.selected.description

        SettingChoices {
            width: parent.width
            values: page.resolutions
            value: page.resolution
            label: (size) => {
                return size === "auto" ? "Auto" : size.replace("x", " × ");
            }
            onSelected: (value) => {
                return page.apply(value === "auto" ? ["auto", page.selected.name] : ["resolution", page.selected.name, value], true);
            }
        }

    }

    SettingRow {
        Layout.fillWidth: true
        visible: page.selected !== null
        icon: "󰑓"
        title: "Refresh rate"

        SettingChoices {
            width: parent.width
            values: page.frequencies
            value: page.frequency
            label: page.rateLabel
            onSelected: (value) => {
                return page.apply(["refresh", page.selected.name, value], true);
            }
        }

    }

    SettingRow {
        Layout.fillWidth: true
        visible: page.selected !== null
        icon: "󰁌"
        title: "Scale"
        description: "How big everything is drawn. Auto picks one from the screen's size."

        SettingChoices {
            width: parent.width
            // None until the screens are read, so the chips are built with the screen's own.
            values: page.selected ? ["auto", "1", "1.25", "1.5", "1.75", "2"] : []
            value: page.selected ? page.selected.scale || page.info.default_scale : null
            label: (scale) => {
                return scale === "auto" ? "Auto" : scale + "×";
            }
            onSelected: (value) => {
                return page.apply(["scale", page.selected.name, value], true);
            }
        }

    }

    SettingRow {
        Layout.fillWidth: true
        visible: page.selected !== null
        icon: "󰎤"
        title: "Number"
        description: "Its number in the bar, and the workspace it starts with."

        SettingChoices {
            width: parent.width
            values: page.selected ? ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"] : []
            value: page.selected ? page.selected.slot : null
            onSelected: (value) => {
                return page.apply(["slot", page.selected.name, value], false);
            }
        }

    }

    // Picking a workspace of another screen moves it here.
    SettingRow {
        Layout.fillWidth: true
        visible: page.selected !== null
        icon: "󰕰"
        title: "Workspaces"
        description: "The ones this screen holds. One held by another screen is faint, and moves here when you pick it."

        Flow {
            width: parent.width
            spacing: 6

            Repeater {
                model: 10

                // Like SettingChoices' chips, several of them chosen at once.
                Item {
                    id: workspaceChip

                    required property int index
                    readonly property string workspace: String(index + 1)
                    readonly property string owner: page.workspaceOwner(workspace)
                    readonly property bool chosen: page.selected !== null && owner === page.selected.name
                    readonly property real radius: height / 2

                    function activate() {
                        workspaceBounce.restart();
                        page.toggleWorkspace(workspace);
                    }

                    implicitWidth: Math.max(implicitHeight, workspaceText.implicitWidth + 28)
                    implicitHeight: 32
                    activeFocusOnTab: true

                    GlassSurface {
                        radius: workspaceChip.radius
                        hovered: workspaceHover.hovered
                        backgroundColor: workspaceChip.chosen ? Theme.alpha(Theme.primary, 0.85) : "transparent"
                    }

                    Text {
                        id: workspaceText

                        anchors.centerIn: parent
                        text: workspaceChip.workspace
                        color: workspaceChip.chosen ? Theme.base : Theme.alpha(Theme.secondary, workspaceChip.owner !== "" ? 0.5 : 1)
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.weight: workspaceChip.chosen ? Font.Bold : Font.Medium
                    }

                    HoverHandler {
                        id: workspaceHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: workspaceChip.activate()
                    }

                    BounceAnimation {
                        id: workspaceBounce

                        target: workspaceChip
                    }

                }

            }

        }

    }

    SettingRow {
        Layout.fillWidth: true
        visible: page.outputs.length > 0
        icon: "󰕮"
        title: "Layout"
        description: page.info.layout === "auto" ? "Laid out on their own, side by side by number." : "Placed as you set them."

        ColumnLayout {
            width: parent.width
            spacing: 6

            ActionRow {
                Layout.fillWidth: true
                icon: "󰕮"
                label: "Lay them out on their own"
                onTriggered: page.apply(["auto-layout"], false)
            }

            ActionRow {
                Layout.fillWidth: true
                icon: "󰑓"
                label: "Reset every screen's settings"
                destructive: true
                onTriggered: page.apply(["reset"], false)
            }

        }

    }

    Process {
        id: infoProcess

        command: [page.displayctl, "info"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const info = JSON.parse(text);
                    // The screen you're on is picked before the screens are shown, or
                    // the first one would be, for a moment.
                    if (page.selectedName === "" || !info.outputs.some((output) => {
                        return output.name === page.selectedName;
                    })) {
                        const focused = info.outputs.find((output) => {
                            return output.focused;
                        });
                        page.selectedName = focused ? focused.name : info.outputs.length > 0 ? info.outputs[0].name : "";
                    }
                    page.info = info;
                    const names = info.outputs.map((output) => {
                        return output.name;
                    });
                    if (JSON.stringify(names) !== JSON.stringify(page.names))
                        page.names = names;
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
                page.keep();
                Quickshell.execDetached(["notify-send", "-u", "normal", "Unable to change the display settings", applyErrors.text.trim().split("\n").pop() || ""]);
            }
            page.refresh();
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
            page.revertCountdown -= 1;
            if (page.revertCountdown <= 0)
                page.revert();

        }
    }

    // Hyprland takes a moment to apply the restored state.
    Timer {
        id: revertRefresh

        interval: 600
        onTriggered: page.refresh()
    }

}
