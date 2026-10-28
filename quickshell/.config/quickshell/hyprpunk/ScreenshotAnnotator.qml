import QtQuick
import QtQuick.Layouts

// Drawing on a screenshot right where it was taken, over the frozen screen: pen,
// highlighter, arrow, rectangle, ellipse (outlined or filled) and text, in the theme's
// colors and three sizes, with a toolbar beside the region.
// Enter (or ✓) saves it at full resolution, Escape cancels, Ctrl+Z undoes.
Item {
    id: annotator

    // {x, y, width, height}: the region on the screen.
    required property var region
    required property string frozenFile
    required property real scale
    // Where the annotated screenshot is written.
    required property string outputFile
    property string tool: "pen"
    property color color: Theme.red
    // 0, 1 or 2: small, medium, large.
    property int size: 1
    // Rectangles and ellipses filled rather than outlined.
    property bool filled: false
    // What's been drawn, in the region's coordinates: {tool, color, size, points}
    // (two points for arrows, rectangles and ellipses, plus filled), or for text
    // {tool: "text", color, size, points, text}.
    property var shapes: []
    // The one being drawn.
    property var current: null
    // The text being typed: {x, y} in the region, null otherwise.
    property var textAt: null
    property bool saving: false
    readonly property var tools: [{
        "value": "pen",
        "icon": "󰏫"
    }, {
        "value": "highlight",
        "icon": "󰸱"
    }, {
        "value": "arrow",
        "icon": "󰁔"
    }, {
        "value": "rect",
        "icon": "󰝣"
    }, {
        "value": "ellipse",
        "icon": "󰝦"
    }, {
        "value": "text",
        "icon": "󰊄"
    }]
    readonly property var colors: [Theme.red, Theme.peach, Theme.yellow, Theme.green, Theme.blue, Theme.mauve]

    signal finished(string file)
    signal cancelled()

    // Drawn from where it is pressed to where it is released.
    function twoPoints(tool) {
        return tool === "arrow" || tool === "rect" || tool === "ellipse";
    }

    // Drawn in the box from one point to the other.
    function boxed(tool) {
        return tool === "rect" || tool === "ellipse";
    }

    function lineWidth(shape) {
        const width = [3, 6, 10][shape.size];
        return shape.tool === "highlight" ? width * 3 : width;
    }

    function fontSize(shape) {
        return [16, 24, 34][shape.size];
    }

    function drawShape(context, shape) {
        const points = shape.points;
        context.save();
        context.strokeStyle = shape.color;
        context.fillStyle = shape.color;
        context.lineWidth = lineWidth(shape);
        context.lineCap = shape.tool === "highlight" ? "butt" : "round";
        context.lineJoin = "round";
        context.globalAlpha = shape.tool === "highlight" ? 0.4 : 1;
        if (shape.tool === "text") {
            context.font = "bold " + fontSize(shape) + "px '" + Theme.font + "'";
            context.textBaseline = "top";
            shape.text.split("\n").forEach((line, index) => {
                context.fillText(line, points[0].x, points[0].y + index * fontSize(shape) * 1.25);
            });
        } else if (boxed(shape.tool)) {
            const x = Math.min(points[0].x, points[1].x);
            const y = Math.min(points[0].y, points[1].y);
            const width = Math.abs(points[1].x - points[0].x);
            const height = Math.abs(points[1].y - points[0].y);
            context.beginPath();
            if (shape.tool === "rect")
                context.roundedRect(x, y, width, height, 6, 6);
            else
                context.ellipse(x, y, width, height);
            if (shape.filled)
                context.fill();
            else
                context.stroke();
        } else if (shape.tool === "arrow") {
            const angle = Math.atan2(points[1].y - points[0].y, points[1].x - points[0].x);
            const head = Math.max(14, lineWidth(shape) * 4);
            context.beginPath();
            context.moveTo(points[0].x, points[0].y);
            context.lineTo(points[1].x, points[1].y);
            context.moveTo(points[1].x - head * Math.cos(angle - Math.PI / 6), points[1].y - head * Math.sin(angle - Math.PI / 6));
            context.lineTo(points[1].x, points[1].y);
            context.lineTo(points[1].x - head * Math.cos(angle + Math.PI / 6), points[1].y - head * Math.sin(angle + Math.PI / 6));
            context.stroke();
        } else {
            context.beginPath();
            context.moveTo(points[0].x, points[0].y);
            for (let index = 1; index < points.length; index++)
                context.lineTo(points[index].x, points[index].y);
            // A dot for a click.
            if (points.length === 1)
                context.lineTo(points[0].x + 0.1, points[0].y);

            context.stroke();
        }
        context.restore();
    }

    function commitText() {
        if (textAt !== null && textInput.text.trim() !== "")
            shapes = shapes.concat([{
            "tool": "text",
            "color": color.toString(),
            "size": size,
            "points": [textAt],
            "text": textInput.text
        }]);

        textAt = null;
        textInput.text = "";
        annotator.forceActiveFocus();
        canvas.requestPaint();
    }

    function undo() {
        if (textAt !== null) {
            textAt = null;
            textInput.text = "";
            annotator.forceActiveFocus();
            return ;
        }
        shapes = shapes.slice(0, -1);
        canvas.requestPaint();
    }

    // Once the last text is drawn, the region and its annotations as one picture.
    function save() {
        commitText();
        saving = true;
        canvas.requestPaint();
    }

    anchors.fill: parent
    focus: true
    Keys.onEscapePressed: cancelled()
    Keys.onReturnPressed: save()
    Keys.onEnterPressed: save()
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier)) {
            undo();
            event.accepted = true;
        }
    }
    Component.onCompleted: forceActiveFocus()

    // What is saved: the region of the frozen screen and the annotations over it.
    Item {
        id: picture

        x: annotator.region.x
        y: annotator.region.y
        width: annotator.region.width
        height: annotator.region.height

        Image {
            anchors.fill: parent
            source: "file://" + annotator.frozenFile
            sourceClipRect: Qt.rect(annotator.region.x * annotator.scale, annotator.region.y * annotator.scale, annotator.region.width * annotator.scale, annotator.region.height * annotator.scale)
            cache: false
            smooth: true
        }

        Canvas {
            id: canvas

            anchors.fill: parent
            onPaint: {
                const context = getContext("2d");
                context.reset();
                for (const shape of annotator.shapes)
                    annotator.drawShape(context, shape);
                if (annotator.current !== null)
                    annotator.drawShape(context, annotator.current);

            }
            onPainted: {
                if (!annotator.saving)
                    return ;

                annotator.saving = false;
                picture.grabToImage((result) => {
                    result.saveToFile(annotator.outputFile);
                    annotator.finished(annotator.outputFile);
                }, Qt.size(Math.round(picture.width * annotator.scale), Math.round(picture.height * annotator.scale)));
            }
        }

    }

    // Drawing, in the region only.
    MouseArea {
        anchors.fill: picture
        cursorShape: annotator.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor
        preventStealing: true
        onPressed: (mouse) => {
            const point = {
                "x": mouse.x,
                "y": mouse.y
            };
            if (annotator.tool === "text") {
                annotator.commitText();
                annotator.textAt = point;
                textInput.forceActiveFocus();
                return ;
            }
            annotator.commitText();
            annotator.current = {
                "tool": annotator.tool,
                "color": annotator.color.toString(),
                "size": annotator.size,
                "filled": annotator.filled,
                "points": annotator.twoPoints(annotator.tool) ? [point, point] : [point]
            };
            canvas.requestPaint();
        }
        onPositionChanged: (mouse) => {
            const shape = annotator.current;
            if (shape === null)
                return ;

            const point = {
                "x": Math.max(0, Math.min(width, mouse.x)),
                "y": Math.max(0, Math.min(height, mouse.y))
            };
            if (annotator.twoPoints(shape.tool))
                shape.points = [shape.points[0], point];
            else
                shape.points = shape.points.concat([point]);
            annotator.current = shape;
            canvas.requestPaint();
        }
        onReleased: {
            const shape = annotator.current;
            annotator.current = null;
            if (shape === null)
                return ;

            const moved = shape.points.length > 1 && (Math.abs(shape.points[1].x - shape.points[0].x) + Math.abs(shape.points[1].y - shape.points[0].y) > 3);
            if (shape.tool === "pen" || shape.tool === "highlight" || moved)
                annotator.shapes = annotator.shapes.concat([shape]);

            canvas.requestPaint();
        }
    }

    // The text being typed, where it was clicked, as it will be drawn.
    TextEdit {
        id: textInput

        x: picture.x + (annotator.textAt !== null ? annotator.textAt.x : 0)
        y: picture.y + (annotator.textAt !== null ? annotator.textAt.y : 0)
        visible: annotator.textAt !== null
        color: annotator.color
        font.family: Theme.font
        font.pixelSize: [16, 24, 34][annotator.size]
        font.weight: Font.Bold
        cursorVisible: visible
        // Enter keeps the text, Shift+Enter goes to the next line, Escape drops it.
        Keys.onReturnPressed: (event) => {
            if (event.modifiers & Qt.ShiftModifier)
                event.accepted = false;
            else
                annotator.commitText();
        }
        Keys.onEscapePressed: annotator.undo()
    }

    // The toolbar sits under the region, above it when there's no room below,
    // and inside it when the region fills the screen.
    Rectangle {
        id: toolbar

        readonly property real below: annotator.region.y + annotator.region.height + 12
        readonly property real above: annotator.region.y - height - 12

        x: Math.max(12, Math.min(annotator.width - width - 12, annotator.region.x + annotator.region.width / 2 - width / 2))
        y: below + height <= annotator.height - 12 ? below : above >= 12 ? above : annotator.region.y + annotator.region.height - height - 12
        width: toolRow.implicitWidth + 16
        height: 48
        radius: 24
        color: Theme.alpha(Theme.base, 0.92)

        GlassSurface {
            radius: toolbar.radius
            tinted: false
        }

        // The clicks on the toolbar stay on it.
        MouseArea {
            anchors.fill: parent
        }

        RowLayout {
            id: toolRow

            anchors.centerIn: parent
            spacing: 4

            Repeater {
                model: annotator.tools

                ToolButton {
                    required property var modelData

                    icon: modelData.icon
                    chosen: annotator.tool === modelData.value
                    onClicked: {
                        annotator.commitText();
                        annotator.tool = modelData.value;
                    }
                }

            }

            // Filled or outlined, for the rectangles and ellipses.
            ToolButton {
                icon: "󰉦"
                chosen: annotator.filled
                enabled: annotator.boxed(annotator.tool)
                opacity: enabled ? 1 : 0.35
                onClicked: annotator.filled = !annotator.filled
            }

            Separator {
            }

            Repeater {
                model: annotator.colors

                Item {
                    required property string modelData
                    readonly property bool chosen: Qt.colorEqual(annotator.color, modelData)

                    implicitWidth: 26
                    implicitHeight: 34

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.chosen ? 22 : 16
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: parent.chosen ? 2 : 0
                        border.color: Theme.text

                        Behavior on width {
                            NumberAnimation {
                                duration: 140
                                easing.type: Easing.OutBack
                            }

                        }

                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        radius: 7
                        color: parent.modelData
                    }

                    TapHandler {
                        cursorShape: Qt.PointingHandCursor
                        onTapped: annotator.color = parent.modelData
                    }

                }

            }

            Separator {
            }

            Repeater {
                model: 3

                Item {
                    required property int index

                    implicitWidth: 26
                    implicitHeight: 34

                    Rectangle {
                        anchors.centerIn: parent
                        width: [6, 10, 15][parent.index]
                        height: width
                        radius: width / 2
                        color: annotator.size === parent.index ? Theme.mauve : Theme.overlay1

                        Behavior on color {
                            ColorAnimation {
                                duration: 140
                            }

                        }

                    }

                    TapHandler {
                        cursorShape: Qt.PointingHandCursor
                        onTapped: annotator.size = parent.index
                    }

                }

            }

            Separator {
            }

            ToolButton {
                icon: "󰕌"
                onClicked: annotator.undo()
            }

            ToolButton {
                icon: "󰅖"
                onClicked: annotator.cancelled()
            }

            ToolButton {
                icon: "󰄬"
                chosen: true
                onClicked: annotator.save()
            }

        }

    }

    component Separator: Rectangle {
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        implicitWidth: 1
        implicitHeight: 22
        color: Theme.alpha(Theme.text, 0.15)
    }

    component ToolButton: Rectangle {
        id: button

        property string icon
        property bool chosen: false

        signal clicked()

        implicitWidth: 34
        implicitHeight: 34
        radius: 17
        color: chosen ? Theme.mauve : buttonHover.hovered ? Theme.alpha(Theme.text, 0.12) : "transparent"

        Text {
            anchors.centerIn: parent
            text: button.icon
            color: button.chosen ? Theme.base : Theme.mauve
            font.family: Theme.font
            font.pixelSize: 17
        }

        HoverHandler {
            id: buttonHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: {
                buttonBounce.restart();
                button.clicked();
            }
        }

        BounceAnimation {
            id: buttonBounce

            target: button
        }

        Behavior on color {
            ColorAnimation {
                duration: 140
            }

        }

    }

}
