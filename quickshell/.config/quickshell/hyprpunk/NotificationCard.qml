import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets

Rectangle {
    id: card

    required property var notification
    readonly property bool alive: notification !== null
    // Translucent by default, over the blurred notification center panel.
    // Liquid glass over the blurred notification center panel by default.
    property color backgroundColor: "transparent"
    // Horizontal offset while the card is dragged; the parent adds it to its x.
    property real swipeOffset: 0

    // Emitted right before a swipe dismisses the notification: the parent takes
    // over swipeOffset so its exit animation continues from where the card is.
    signal swipedAway()
    // Last known content: when the notification object is destroyed (closed by
    // its app), a popup still has to slide out with its text on it.
    property bool critical: false
    property string summary: ""
    property string body: ""
    property string appName: ""
    property string appIcon: ""
    property string image: ""
    property string desktopEntry: ""
    // Many apps (nm-applet, chat clients...) send their icon as image-path or
    // image-data instead of app_icon, so try every source the spec allows.
    readonly property string iconSource: {
        if (image !== "")
            return image;

        const appIconPath = appIcon !== "" ? Quickshell.iconPath(appIcon, true) : "";
        if (appIconPath !== "")
            return appIconPath;

        const entry = desktopEntry !== "" ? DesktopEntries.byId(desktopEntry) : null;
        const entryIconPath = entry ? Quickshell.iconPath(entry.icon, true) : "";
        if (entryIconPath !== "")
            return entryIconPath;

        return Quickshell.iconPath("dialog-information");
    }
    // Per the spec, "default" is triggered by clicking the notification itself
    // (kitty uses it to focus the emitting window), so it never gets a button.
    property bool hasDefaultAction: false
    property var buttonActions: []

    function invokeAction(identifier) {
        if (!alive)
            return ;

        const action = notification.actions.find((item) => {
            return item.identifier === identifier;
        });
        if (action)
            action.invoke();

    }

    implicitHeight: content.implicitHeight + 24
    radius: 18
    color: "transparent"

    GlassSurface {
        radius: card.radius
        hovered: cardArea.containsMouse
        backgroundColor: card.backgroundColor
    }

    Binding {
        target: card
        property: "critical"
        value: card.notification?.urgency === NotificationUrgency.Critical
        when: card.alive
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: card
        property: "summary"
        value: card.notification?.summary ?? ""
        when: card.alive
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: card
        property: "body"
        value: card.notification?.body ?? ""
        when: card.alive
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: card
        property: "appName"
        value: card.notification?.appName ?? ""
        when: card.alive
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: card
        property: "image"
        value: card.notification?.image ?? ""
        when: card.alive
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: card
        property: "desktopEntry"
        value: card.notification?.desktopEntry ?? ""
        when: card.alive
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: card
        property: "appIcon"
        value: card.notification?.appIcon ?? ""
        when: card.alive
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: card
        property: "hasDefaultAction"
        value: (card.notification?.actions ?? []).some((action) => {
            return action.identifier === "default";
        })
        when: card.alive
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: card
        property: "buttonActions"
        // Plain copies, the action objects die with their notification.
        value: (card.notification?.actions ?? []).filter((action) => {
            return action.identifier !== "default";
        }).map((action) => {
            return {
                "identifier": action.identifier,
                "text": action.text
            };
        })
        when: card.alive
        restoreMode: Binding.RestoreNone
    }

    // Swipe to the right to dismiss.
    DragHandler {
        id: swipeHandler

        target: null
        enabled: card.alive
        yAxis.enabled: false
        onTranslationChanged: {
            // Resists when pulled to the left.
            card.swipeOffset = translation.x > 0 ? translation.x : translation.x * 0.2;
        }
        onActiveChanged: {
            if (active) {
                swipeBack.stop();
            } else if (card.swipeOffset > card.width * 0.35 || (card.swipeOffset > 20 && centroid.velocity.x > 600)) {
                card.swipedAway();
                card.notification.dismiss();
            } else {
                swipeBack.start();
            }
        }
    }

    NumberAnimation {
        id: swipeBack

        target: card
        property: "swipeOffset"
        to: 0
        duration: 220
        easing.type: Easing.OutCubic
    }

    MouseArea {
        id: cardArea

        anchors.fill: parent
        enabled: card.alive && card.hasDefaultAction
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.invokeAction("default")
    }

    RowLayout {
        id: content

        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        IconImage {
            Layout.alignment: Qt.AlignTop
            implicitSize: 42
            source: card.iconSource
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    Layout.rightMargin: 16
                    text: card.summary || card.appName
                    color: card.critical ? "#f38ba8" : "#cba6f7"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

            }

            Text {
                visible: text !== ""
                Layout.fillWidth: true
                text: card.body
                textFormat: Text.PlainText
                color: card.critical ? "#f38ba8" : "#cba6f7"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                wrapMode: Text.Wrap
            }

            RowLayout {
                visible: card.buttonActions.length > 0
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: card.buttonActions

                    Rectangle {
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: 12
                        color: "transparent"

                        // Mauve glass, like the clear button of the notification center.
                        GlassSurface {
                            radius: parent.radius
                            hovered: actionArea.containsMouse
                            backgroundColor: Qt.rgba(203 / 255, 166 / 255, 247 / 255, actionArea.containsMouse ? 0.95 : 0.8)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData.text
                            color: "#1e1e2e"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            id: actionArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: card.alive
                            onClicked: card.invokeAction(parent.modelData.identifier)
                        }

                    }

                }

            }

        }

    }

    // Small neutral close cross in the top-right corner.
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        width: 22
        height: 22
        radius: 11
        color: "transparent"

        // Glass halo on hover only, so the cross stays discreet.
        GlassSurface {
            radius: parent.radius
            hovered: true
            opacity: closeArea.containsMouse ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                }

            }

        }

        Text {
            anchors.centerIn: parent
            text: ""
            color: closeArea.containsMouse ? "#cba6f7" : "#7f849c"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
        }

        MouseArea {
            id: closeArea

            anchors.fill: parent
            enabled: card.alive
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.notification.dismiss()
        }

    }

}
