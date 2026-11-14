import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs.components
import qs.theme

// One notification, in the island's popups and next to its calendar.
Rectangle {
    id: card

    required property var notification
    readonly property bool alive: notification !== null
    // Transparent by default, the glass shows over the card's blur behind.
    property color backgroundColor: "transparent"
    // The last content seen: if the app closes the notification, the popup still
    // needs its text to leave with.
    property bool critical: false
    property string summary: ""
    property string body: ""
    property string appName: ""
    property string appIcon: ""
    property string image: ""
    property string desktopEntry: ""
    // Plenty of apps (nm-applet, chat clients…) send their icon as image-path or
    // image-data instead of app_icon, so try everything the spec allows.
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
    // The "default" action is what clicking the notification does (kitty uses it to
    // focus its window), so it doesn't get a button of its own.
    property bool hasDefaultAction: false
    property var buttonActions: []

    // Some apps send markup even when we don't ask for it. Keep bold, italic, underline
    // and line breaks, drop every other tag (links, images that would be fetched), and
    // escape stray angle brackets in plain text.
    function styledBody(text) {
        return text.replace(/<(\/?)([a-zA-Z][a-zA-Z0-9]*)\b[^>]*>|[<>]/g, (match, slash, tag) => {
            if (!tag)
                return match === "<" ? "&lt;" : "&gt;";

            const name = tag.toLowerCase();
            if (name === "br")
                return "<br>";

            return ["b", "i", "u"].includes(name) ? "<" + slash + name + ">" : "";
        }).replace(/\n/g, "<br>");
    }

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
    radius: Metrics.cardRadius
    color: "transparent"

    GlassSurface {
        radius: card.radius
        hovered: cardHover.hovered
        backgroundColor: card.backgroundColor
    }

    // Lit wherever the pointer is on the card, the close cross and the buttons included.
    // A MouseArea would lose it to the ones on top, and it would never light up on cards
    // you can't click.
    HoverHandler {
        id: cardHover

        enabled: card.alive
        cursorShape: card.hasDefaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
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

    MouseArea {
        id: cardArea

        anchors.fill: parent
        enabled: card.alive && card.hasDefaultAction
        onClicked: card.invokeAction("default")
    }

    RowLayout {
        id: content

        anchors.fill: parent
        anchors.margins: Metrics.spacing.large
        spacing: Metrics.spacing.large

        IconImage {
            Layout.alignment: Qt.AlignTop
            implicitSize: 42
            source: card.iconSource
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacing.small

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    // Clear of the close cross.
                    Layout.rightMargin: Metrics.spacing.huge
                    text: card.summary || card.appName
                    color: card.critical ? Colors.red : Colors.primary
                    font.family: Metrics.font
                    font.pixelSize: Metrics.text.title
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

            }

            Text {
                visible: text !== ""
                Layout.fillWidth: true
                text: card.styledBody(card.body)
                textFormat: Text.StyledText
                color: card.critical ? Colors.red : Colors.secondary
                font.family: Metrics.font
                font.pixelSize: Metrics.text.emphasis
                wrapMode: Text.Wrap
            }

            RowLayout {
                visible: card.buttonActions.length > 0
                Layout.fillWidth: true
                spacing: Metrics.spacing.normal

                Repeater {
                    model: card.buttonActions

                    GlassButton {
                        required property var modelData

                        Layout.fillWidth: true
                        label: modelData.text
                        accent: true
                        onClicked: card.invokeAction(modelData.identifier)
                    }

                }

            }

        }

    }

    // Closes the card.
    IconButton {
        icon: ""
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Metrics.spacing.normal
        // Not faded as the card leaves: a card already gone just ignores the click.
        onClicked: {
            if (card.alive)
                card.notification.dismiss();

        }
    }

}
