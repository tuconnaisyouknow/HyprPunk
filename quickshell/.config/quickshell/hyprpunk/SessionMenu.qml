import QtQuick
import Quickshell

// The session menu: lock, log out, reboot, shut down. Arrows or Tab to choose,
// Enter or a click to go.
IslandPanel {
    id: session

    property string armedAction: ""
    property int selectedIndex: -1
    readonly property int cardPadding: 14
    readonly property int actionSize: 64
    readonly property int actionSpacing: 10
    // Destructive actions ask for a second click (or Enter).
    readonly property var actions: [{
        "id": "lock",
        "icon": "󰌾",
        "confirm": false,
        "command": ["qs", "-c", "hyprpunk", "ipc", "call", "lock", "lock"]
    }, {
        "id": "logout",
        "icon": "",
        "confirm": true,
        "command": ["hyprctl", "dispatch", "hl.dsp.exit()"]
    }, {
        "id": "reboot",
        "icon": "󰑓",
        "confirm": true,
        "command": ["systemctl", "reboot"]
    }, {
        "id": "shutdown",
        "icon": "",
        "confirm": true,
        "command": ["systemctl", "poweroff"]
    }]

    function run(action) {
        if (action.confirm && armedAction !== action.id) {
            armedAction = action.id;
            disarmDelay.restart();
            return ;
        }
        close();
        Quickshell.execDetached(action.command);
    }

    function select(delta) {
        selectedIndex = selectedIndex < 0 ? (delta > 0 ? 0 : actions.length - 1) : (selectedIndex + delta + actions.length) % actions.length;
        // Moving away from an armed action disarms it.
        if (armedAction !== "" && armedAction !== actions[selectedIndex].id)
            armedAction = "";

    }

    panelName: "session"
    cardWidth: actions.length * actionSize + (actions.length - 1) * actionSpacing + 2 * cardPadding
    cardHeight: actionSize + 2 * cardPadding
    keyTargets: [keys]
    onOpening: {
        armedAction = "";
        selectedIndex = -1;
    }
    onOpenedChanged: {
        if (!opened)
            armedAction = "";

    }

    Item {
        id: keys

        Keys.onPressed: (event) => {
            const direction = session.horizontalKey(event);
            if (direction !== 0) {
                session.select(direction);
                event.accepted = true;
            }
        }
        Keys.onLeftPressed: session.select(-1)
        Keys.onRightPressed: session.select(1)
        Keys.onTabPressed: session.select(1)
        Keys.onBacktabPressed: session.select(-1)
        Keys.onReturnPressed: {
            if (session.selectedIndex >= 0)
                session.run(session.actions[session.selectedIndex]);

        }
        Keys.onEnterPressed: {
            if (session.selectedIndex >= 0)
                session.run(session.actions[session.selectedIndex]);

        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: session.cardPadding
        spacing: session.actionSpacing

        Repeater {
            model: session.actions

            Rectangle {
                id: actionCard

                required property var modelData
                required property int index
                readonly property bool armed: session.armedAction === modelData.id
                readonly property bool selected: session.selectedIndex === index

                width: session.actionSize
                height: session.actionSize
                radius: 18
                color: "transparent"
                scale: actionTap.pressed ? 0.92 : 1

                // Plain glass, mauve when hovered or selected, red once armed
                // (click again or press Enter to confirm).
                GlassSurface {
                    radius: parent.radius
                    hovered: actionCard.selected
                    backgroundColor: actionCard.armed ? Qt.rgba(243 / 255, 139 / 255, 168 / 255, 0.9) : actionCard.selected ? Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.9) : "transparent"

                    Behavior on backgroundColor {
                        ColorAnimation {
                            duration: 140
                        }

                    }

                }

                Text {
                    anchors.centerIn: parent
                    text: actionCard.modelData.icon
                    color: actionCard.armed || actionCard.selected ? "#1e1e2e" : "#cba6f7"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 24
                    font.weight: Font.Bold

                    Behavior on color {
                        ColorAnimation {
                            duration: 140
                        }

                    }
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: {
                        if (hovered)
                            session.selectedIndex = actionCard.index;
                        else if (session.selectedIndex === actionCard.index)
                            session.selectedIndex = -1;
                    }
                }

                TapHandler {
                    id: actionTap

                    onTapped: session.run(actionCard.modelData)
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutBack
                    }

                }

            }

        }

    }

    Timer {
        id: disarmDelay

        interval: 3000
        onTriggered: session.armedAction = ""
    }

}
