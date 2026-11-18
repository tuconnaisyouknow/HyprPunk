import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.theme

// The settings' displays page: your screens drawn to scale, dragged where they go, then
// the settings of the one you pick, applied straight away through displayctl.sh. A new
// resolution, refresh rate or scale asks if you want to keep it once it's applied, and undoes
// itself if you don't answer or close the window.
SettingsPage {
    id: page

    title: "Displays"
    description: "Drag a screen against another to place it, or move the one you're on with Shift and the arrows. Each is remembered as it is, whichever port it's plugged into."

    readonly property var info: Displays.info
    property string selectedName: ""
    property int secondsLeft: 0
    // The screens' names, only replaced when one comes or goes, so the drawing keeps its
    // screens (and the keyboard on one) when the layout changes.
    property var names: []
    readonly property var outputs: info.outputs
    readonly property var selected: outputs.find((output) => {
        return output.name === selectedName;
    }) || outputs[0] || null
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
    // The screen you're on is picked before the screens are shown, or the first one
    // would be, for a moment.
    function follow() {
        if (selectedName === "" || !outputs.some((output) => {
            return output.name === selectedName;
        })) {
            const focused = outputs.find((output) => {
                return output.focused;
            });
            selectedName = focused ? focused.name : outputs.length > 0 ? outputs[0].name : "";
        }
        const list = outputs.map((output) => {
            return output.name;
        });
        if (JSON.stringify(list) !== JSON.stringify(names))
            names = list;

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
        Displays.apply(["workspaces", selected.name, list.length > 0 ? list.join(",") : "none"], false);
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

    // Puts a screen there, unless it's already there. True when it was asked for.
    function place(name, spot) {
        const moved = preview.rectOf(name);
        if (spot === null || Displays.busy || (spot.x === moved.x && spot.y === moved.y))
            return false;

        Displays.apply(["position", name, spot.direction, spot.reference], false);
        return true;
    }

    onOutputsChanged: follow()
    asking: Displays.revertCountdown > 0 && !Displays.busy

    // A change that undoes itself unless you keep it.
    question: SettingRow {
        icon: "󰔛"
        title: "Keep these settings?"
        description: "They go back as they were in " + page.secondsLeft + " s."

        RowLayout {
            width: parent.width
            spacing: Metrics.spacing.normal

            ActionRow {
                Layout.fillWidth: true
                icon: "󰄬"
                label: "Keep"
                onTriggered: Displays.keep()
            }

            ActionRow {
                Layout.fillWidth: true
                icon: "󰕌"
                label: "Revert"
                onTriggered: Displays.revert()
            }

        }

    }

    // Stops at the last second counted, so the question doesn't read 0 as it leaves.
    Binding on secondsLeft {
        when: Displays.revertCountdown > 0
        value: Displays.revertCountdown
        restoreMode: Binding.RestoreNone
    }

    // The screens at their size and place. A click picks one; dragged, it follows the
    // pointer and shows where it will go against the others, and goes there when dropped.
    // Shift and the arrows move the one with the keyboard. At rest the drawing fits the
    // screens; while one is dragged it fits every place it can take. One glide takes the
    // whole drawing from where it is to where it goes, so the screens stay against each
    // other on the way.
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
        // The screen the drawing makes room for, "" while none is dragged, and where it
        // would go.
        property string dragged: ""
        property var target: null
        // The screen in the pointer's hand, the pointer in the preview, and where it
        // caught the screen as a share of its width and height: the same point stays
        // under it as the drawing makes room and the screen shrinks.
        property string carried: ""
        property point pointer: Qt.point(0, 0)
        property point grab: Qt.point(0, 0)
        // The screen just dropped and the place it was dropped on, until the layout comes
        // back with it: the drawing is already the one to come. Hyprland is only asked
        // once the glide is over, as its reload would cut into it, and no other screen
        // moves until then.
        property var dropped: null
        readonly property var held: dropped !== null && dropped.rects === rects ? dropped : null
        // The drawing asked for: the frame's size and middle in the layout's pixels, and
        // every screen's box by name, from that middle. Only its shape counts, so the
        // layout coming back shifted to 0,0 is the same drawing.
        readonly property var asked: {
            const shown = rects.map((rect) => {
                return held !== null && rect.output.name === held.name ? Object.assign({
                }, rect, {
                    "x": held.spot.x,
                    "y": held.spot.y
                }) : rect;
            });
            const moved = rectOf(dragged);
            const frame = bounds(moved === null ? shown : rects.concat(page.placements(dragged).map((spot) => {
                return {
                    "x": spot.x,
                    "y": spot.y,
                    "width": moved.width,
                    "height": moved.height
                };
            })));
            const drawing = {
                "width": frame.width,
                "height": frame.height,
                "middleX": frame.x + frame.width / 2,
                "middleY": frame.y + frame.height / 2,
                "boxes": {
                }
            };
            for (const rect of shown) drawing.boxes[rect.output.name] = {
                "x": rect.x - drawing.middleX,
                "y": rect.y - drawing.middleY,
                "width": rect.width,
                "height": rect.height
            }
            return drawing;
        }
        // The drawing glides from one to the other. In the layout's pixels, so the
        // preview taking its size as the window opens moves nothing.
        property var from: null
        property var to: null
        property real progress: 1
        readonly property real padding: Metrics.spacing.huge
        readonly property real factor: to === null ? 1 : Math.min((width - 2 * padding) / Math.max(1, mix(from.width, to.width)), (height - 2 * padding) / Math.max(1, mix(from.height, to.height)))

        function mix(start, end) {
            return start + (end - start) * progress;
        }

        // A screen's box as the glide has it now, null when it isn't drawn.
        function boxOf(name) {
            const end = to !== null ? to.boxes[name] : undefined;
            if (end === undefined)
                return null;

            const start = from.boxes[name] || end;
            return {
                "x": mix(start.x, end.x),
                "y": mix(start.y, end.y),
                "width": mix(start.width, end.width),
                "height": mix(start.height, end.height)
            };
        }

        // The drawing as it is right now, with the screens of the one to come: a new
        // screen is at its place, the one in the pointer's hand where the pointer has it.
        function current(next) {
            const drawing = {
                "width": mix(from.width, to.width),
                "height": mix(from.height, to.height),
                "boxes": {
                }
            };
            for (const name in next.boxes) {
                const box = boxOf(name) || Object.assign({
                }, next.boxes[name]);
                if (name === carried) {
                    box.x = (pointer.x - width / 2) / factor - grab.x * box.width;
                    box.y = (pointer.y - height / 2) / factor - grab.y * box.height;
                }
                drawing.boxes[name] = box;
            }
            return drawing;
        }

        function same(drawing, other) {
            const near = (a, b) => {
                return Math.abs(a - b) < 0.01;
            };
            const names = Object.keys(drawing.boxes);
            return near(drawing.width, other.width) && near(drawing.height, other.height) && names.length === Object.keys(other.boxes).length && names.every((name) => {
                const box = drawing.boxes[name];
                const match = other.boxes[name];
                return match !== undefined && near(box.x, match.x) && near(box.y, match.y) && near(box.width, match.width) && near(box.height, match.height);
            });
        }

        // Glides to the drawing asked for. The first screens to show are simply there,
        // and the same drawing asked again leaves the glide alone, unless a screen is in
        // the pointer's hand: that one always has its way to go.
        function follow() {
            const arriving = to === null || Object.keys(to.boxes).length === 0;
            if (!arriving && carried === "" && same(to, asked)) {
                to = asked;
                return ;
            }
            const start = arriving ? asked : current(asked);
            glide.stop();
            from = start;
            to = asked;
            progress = arriving ? 1 : 0;
            if (!arriving)
                glide.start();

        }

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

        Layout.fillWidth: true
        clip: true
        // Always as tall: following the screens' shape, it would push every setting
        // under it up or down when a new scale or resolution changes that shape.
        Layout.preferredHeight: 320
        onAskedChanged: follow()
        Component.onCompleted: follow()

        Anim {
            id: glide

            target: preview
            property: "progress"
            from: 0
            to: 1
            token: Motion.place
            easing.overshoot: Motion.place.overshoot
            // Refused, the screen glides back.
            onFinished: {
                const drop = preview.held;
                if (drop === null || drop.asked)
                    return ;

                drop.asked = true;
                if (!page.place(drop.name, drop.spot))
                    preview.dropped = null;

            }
        }

        GlassSurface {
            radius: Metrics.radius.card
        }

        Text {
            anchors.centerIn: parent
            visible: page.outputs.length === 0
            text: Displays.busy ? "Loading…" : "No screen found"
            color: Colors.secondary
            font.family: Metrics.font
            font.pixelSize: Metrics.text.emphasis
        }

        // The place the dragged screen would take.
        Rectangle {
            readonly property var moved: preview.target !== null ? preview.rectOf(preview.dragged) : null

            visible: moved !== null
            x: moved !== null ? preview.width / 2 + (preview.target.x - preview.to.middleX) * preview.factor + 2 : 0
            y: moved !== null ? preview.height / 2 + (preview.target.y - preview.to.middleY) * preview.factor + 2 : 0
            width: moved !== null ? moved.width * preview.factor - 4 : 0
            height: moved !== null ? moved.height * preview.factor - 4 : 0
            radius: Metrics.radius.normal
            color: Colors.alpha(Colors.primary, 0.12)
            border.width: 1.5
            border.color: Colors.alpha(Colors.primary, 0.85)
        }

        Repeater {
            model: page.names

            // Drawn 2 px inside its place.
            Item {
                id: screenRect

                required property string modelData
                readonly property var rect: preview.rectOf(modelData)
                readonly property var box: preview.boxOf(modelData)
                readonly property bool carried: preview.carried === modelData
                readonly property bool chosen: page.selected !== null && page.selected.name === modelData
                readonly property real radius: Metrics.radius.normal

                function activate() {
                    page.selectedName = modelData;
                }

                visible: box !== null
                x: box === null ? 0 : carried ? preview.pointer.x - preview.grab.x * (width + 4) + 2 : preview.width / 2 + box.x * preview.factor + 2
                y: box === null ? 0 : carried ? preview.pointer.y - preview.grab.y * (height + 4) + 2 : preview.height / 2 + box.y * preview.factor + 2
                // The one you picked or dragged passes over the others.
                z: chosen ? 1 : 0
                width: box !== null ? box.width * preview.factor - 4 : 0
                height: box !== null ? box.height * preview.factor - 4 : 0
                activeFocusOnTab: true
                Keys.onPressed: (event) => {
                    const direction = Navigation.direction(event);
                    if (!(event.modifiers & Qt.ShiftModifier) || direction === null || preview.held !== null)
                        return ;

                    page.selectedName = modelData;
                    page.place(modelData, page.step(modelData, direction[0], direction[1]));
                    event.accepted = true;
                }

                GlassSurface {
                    radius: screenRect.radius
                    hovered: screenHover.hovered
                    backgroundColor: screenRect.chosen ? Colors.alpha(Colors.primary, 0.85) : "transparent"
                    lit: true
                }

                Column {
                    anchors.centerIn: parent
                    spacing: Metrics.spacing.hairline

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: screenRect.rect !== null ? screenRect.rect.output.slot || "?" : ""
                        color: screenRect.chosen ? Colors.over(Colors.primary) : Colors.primary
                        font.family: Metrics.font
                        font.pixelSize: Metrics.text.heading
                        font.weight: Font.Bold
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: screenRect.modelData
                        color: screenRect.chosen ? Colors.over(Colors.primary) : Colors.secondary
                        font.family: Metrics.font
                        font.pixelSize: Metrics.text.small
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
                    enabled: page.names.length > 1 && !Displays.busy && preview.held === null
                    onCentroidChanged: {
                        if (!active)
                            return ;

                        preview.pointer = preview.mapFromItem(null, centroid.scenePosition);
                        // Its place where it's drawn, in the layout's pixels.
                        preview.target = page.nearest(screenRect.modelData, (screenRect.x - 2 - preview.width / 2) / preview.factor + preview.to.middleX, (screenRect.y - 2 - preview.height / 2) / preview.factor + preview.to.middleY);
                    }
                    onActiveChanged: {
                        if (active) {
                            preview.grab = Qt.point((centroid.pressPosition.x + 2) / (screenRect.width + 4), (centroid.pressPosition.y + 2) / (screenRect.height + 4));
                            preview.pointer = preview.mapFromItem(null, centroid.scenePressPosition);
                            preview.carried = screenRect.modelData;
                            page.selectedName = screenRect.modelData;
                            preview.dragged = screenRect.modelData;
                            return ;
                        }
                        const spot = preview.target;
                        preview.target = null;
                        if (spot !== null && (spot.x !== screenRect.rect.x || spot.y !== screenRect.rect.y))
                            preview.dropped = {
                            "name": screenRect.modelData,
                            "spot": spot,
                            "asked": false,
                            "rects": preview.rects
                        };

                        // Let go last: the glide to its place sets off from the pointer.
                        preview.dragged = "";
                        preview.carried = "";
                    }
                }

            }

        }

    }

    // The settings of the screen picked in the drawing, named under the first of them.
    SettingRow {
        Layout.fillWidth: true
        visible: page.selected !== null
        icon: "󰹑"
        title: "Resolution"
        description: page.selected ? page.selected.description : ""

        SettingChoices {
            width: parent.width
            values: page.resolutions
            value: page.resolution
            label: (size) => {
                return size === "auto" ? "Auto" : size.replace("x", " × ");
            }
            onSelected: (value) => {
                return Displays.apply(["mode", page.selected.name, value === "auto" ? "preferred" : value], true);
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
                return Displays.apply(["mode", page.selected.name, page.selected.width + "x" + page.selected.height + "@" + value], true);
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
            value: page.selected ? page.selected.scale || "auto" : null
            label: (scale) => {
                return scale === "auto" ? "Auto" : scale + "×";
            }
            onSelected: (value) => {
                return Displays.apply(["scale", page.selected.name, value], true);
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
                return Displays.apply(["slot", page.selected.name, value], false);
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
            spacing: Metrics.spacing.normal

            Repeater {
                model: 10

                // Like SettingChoices, several of them chosen at once. One held by
                // another screen is faded, like anything that isn't yours to use.
                GlassButton {
                    required property int index
                    readonly property string workspace: String(index + 1)
                    readonly property string owner: page.workspaceOwner(workspace)

                    label: workspace
                    accent: page.selected !== null && owner === page.selected.name
                    opacity: !accent && owner !== "" ? 0.5 : 1
                    activeFocusOnTab: true
                    onClicked: page.toggleWorkspace(workspace)
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
            spacing: Metrics.spacing.normal

            ActionRow {
                Layout.fillWidth: true
                icon: "󰕮"
                label: "Lay them out on their own"
                onTriggered: Displays.apply(["auto-layout"], false)
            }

            ActionRow {
                Layout.fillWidth: true
                icon: "󰑓"
                label: "Reset every screen's settings"
                destructive: true
                onTriggered: Displays.apply(["reset"], false)
            }

        }

    }

    ServiceRef {
        service: Displays
        active: true
    }

}
