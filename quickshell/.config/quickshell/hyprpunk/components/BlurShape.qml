import QtQuick
import qs.state

// The blur behind a glass drawn straight on the desktop (a pill, the privacy dots): put
// in the glass, it fills it and tells its screen where it is (ScreenShell blurs there).
// Its place is read at each frame of the window: nothing tells when a parent moves an
// item or a zoom draws it bigger. The cards' glass doesn't need one (Card.cardRect).
Item {
    id: shape

    property real radius: 0
    // The glass is there to blur behind, not faded away.
    property bool shown: true
    // Where it's drawn in the window, zoom included.
    property rect place: Qt.rect(0, 0, 0, 0)
    readonly property real placeRadius: height > 0 ? radius * place.height / height : 0
    readonly property var screenState: ShellState.forScreen(Screen.name)
    // Only in the shell's window: the lock screen's pills have nothing to blur behind.
    readonly property bool blurred: shown && visible && screenState !== null && screenState.bar !== null && Window.window === screenState.bar.Window.window
    property var listedOn: null

    function locate() {
        const drawn = mapToItem(null, 0, 0, width, height);
        place = Qt.rect(Math.round(drawn.x), Math.round(drawn.y), Math.round(drawn.width), Math.round(drawn.height));
    }

    function list() {
        if (listedOn !== null)
            listedOn.removeBlurShape(shape);

        listedOn = blurred ? screenState : null;
        if (listedOn === null)
            return ;

        locate();
        listedOn.addBlurShape(shape);
    }

    anchors.fill: parent
    onBlurredChanged: list()
    Component.onCompleted: list()
    Component.onDestruction: {
        if (listedOn !== null)
            listedOn.removeBlurShape(shape);

    }

    Connections {
        function onAfterAnimating() {
            shape.locate();
        }

        target: shape.Window.window
        enabled: shape.blurred
    }

}
