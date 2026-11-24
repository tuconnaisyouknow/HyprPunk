import QtQuick
import QtQuick.Layouts
import qs.theme

// One of the control center's pages, in its PageStack: what you put in it stacks in a
// column, and it only takes the pointer while it's the one shown. Going from a page into
// another is one move towards the door: the outer page grows past you with its door
// heading for the panel's middle, the inner one shows through the door as it opens,
// always the same share smaller than the outer one, like something further away.
// A page with a subject (a network, a device) takes it in its own show().
Item {
    id: page

    property string pageName
    default property alias content: column.data
    property alias spacing: column.spacing
    readonly property Item stack: parent
    readonly property bool current: stack.current === pageName
    // Shown in the open panel: what the page follows while you look (a scan) runs then.
    readonly property bool active: current && stack.opened
    // Of the two pages of a move, the one behind the door.
    readonly property bool inner: current === (stack.direction > 0)
    // The folds in it (Fold), which add themselves. While one moves, the page moves its own
    // height: the panel follows it as it goes rather than easing after it.
    property var folds: []
    readonly property bool resizing: folds.some((fold) => {
        return fold.moving;
    })

    function show() {
        stack.push(pageName);
    }

    function back() {
        stack.back();
    }

    width: stack.width
    implicitHeight: column.implicitHeight
    height: implicitHeight
    // Over the door's glass, the outer page under it.
    z: inner ? 2 : 0
    visible: stack.pageVisible(pageName)
    enabled: current
    opacity: stack.pageOpacity(pageName)

    // What the door shows of the inner page: the page coming up from smaller in the
    // door's middle, cut by its edges, whatever the door's shape. The outer page is whole.
    Item {
        id: opening

        readonly property rect shape: page.inner ? page.stack.opening : Qt.rect(0, 0, page.width, page.height)

        x: shape.x
        y: shape.y
        width: shape.width
        height: shape.height
        clip: page.inner && page.stack.progress < 1

        ColumnLayout {
            id: column

            readonly property real innerSize: Motion.page.into + (1 - Motion.page.into) * page.stack.entered
            readonly property real size: page.inner ? innerSize : innerSize / Motion.page.into
            // The door's middle on the outer page, which follows the opening's.
            readonly property real doorX: page.stack.door.x + page.stack.door.width / 2
            readonly property real doorY: page.stack.door.y + page.stack.door.height / 2

            x: page.inner ? (opening.width - page.width * size) / 2 : 0
            width: page.width
            transform: [
                Scale {
                    origin.x: page.inner ? 0 : column.doorX
                    origin.y: page.inner ? 0 : column.doorY
                    xScale: column.size
                    yScale: column.size
                },
                Translate {
                    x: page.inner ? 0 : page.stack.opening.x + page.stack.opening.width / 2 - column.doorX
                    y: page.inner ? 0 : page.stack.opening.y + page.stack.opening.height / 2 - column.doorY
                }
            ]

        }

    }

}
