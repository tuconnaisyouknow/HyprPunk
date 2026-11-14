import QtQuick
import QtQuick.Layouts

// One of the control center's pages, in its PageStack: it slides in and out as you go
// through them, and only takes the pointer while it's the one shown. A page with a
// subject (a network, a device) takes it in its own show().
ColumnLayout {
    id: page

    property string pageName
    readonly property Item stack: parent
    readonly property bool current: stack.current === pageName
    // Shown in the open panel: what the page follows while you look (a scan) runs then.
    readonly property bool active: current && stack.opened

    function show() {
        stack.push(pageName);
    }

    function back() {
        stack.back();
    }

    width: stack.width
    x: stack.pageX(pageName)
    visible: stack.pageVisible(pageName)
    enabled: current
    opacity: stack.pageOpacity(pageName)
}
