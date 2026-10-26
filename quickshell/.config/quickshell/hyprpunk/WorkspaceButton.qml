import QtQuick

Rectangle {
    id: button

    required property int workspaceId
    required property string icon
    required property bool active
    required property bool occupied
    property bool drawActiveBackground: true
    property bool activeForeground: false
    readonly property alias hovered: mouse.containsMouse
    readonly property bool brandIcon: workspaceId === 2 || workspaceId === 3 || workspaceId === 5
    readonly property bool legacyNerdIcon: workspaceId === 7 || workspaceId === 10
    readonly property string iconFont: legacyNerdIcon ? "Font Awesome 7 Free Solid" : brandIcon ? "Font Awesome 7 Brands" : "Font Awesome 7 Free"

    signal activated()

    onActiveChanged: {
        if (active) {
            activeForegroundDelay.restart();
        } else {
            activeForegroundDelay.stop();
            activeForeground = false;
        }
    }
    Component.onCompleted: activeForeground = active
    implicitWidth: active ? 44 : 31
    implicitHeight: 31
    radius: height / 2
    color: active && drawActiveBackground ? "#cba6f7" : mouse.containsMouse && !active ? "#45475a" : Qt.rgba(69 / 255, 71 / 255, 90 / 255, 0)
    opacity: occupied || active ? 1 : 0.55
    scale: active ? 1 : 0.94

    Text {
        anchors.centerIn: parent
        text: button.icon
        color: button.activeForeground ? "#1e1e2e" : "#cba6f7"
        font.family: button.iconFont
        font.weight: Font.Normal
        font.pixelSize: 16

        Behavior on color {
            ColorAnimation {
                duration: 60
                easing.type: Easing.OutCubic
            }

        }

    }

    Timer {
        id: activeForegroundDelay

        interval: 110
        onTriggered: {
            if (button.active)
                button.activeForeground = true;

        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.activated()
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }

    }

    Behavior on color {
        ColorAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }

    }

    Behavior on scale {
        NumberAnimation {
            duration: 190
            easing.type: Easing.OutBack
        }

    }

}
