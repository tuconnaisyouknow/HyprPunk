import QtQuick
import Quickshell
import Quickshell.Services.Polkit

// The password prompt for polkit (pkexec, systemctl, the apps asking for admin rights),
// grown out of the island on the focused screen. shell.qml holds the agent and opens it.
// Enter sends, Tab switches the account when several can say yes, Escape or a click
// outside cancels.
IslandPanel {
    id: prompt

    required property var agent
    readonly property var flow: agent.flow
    // Kept from the request, so the card still reads right while it folds away.
    property string message: ""
    property string actionId: ""
    property string iconSource: ""
    readonly property int cardPadding: 18
    // Polkit is checking the password, or hasn't asked for it yet.
    readonly property bool waiting: flow !== null && !flow.isResponseRequired
    readonly property var identities: flow ? flow.identities : []

    function nextIdentity() {
        if (!flow || identities.length < 2)
            return ;

        const index = identities.indexOf(flow.selectedIdentity);
        flow.selectedIdentity = identities[(index + 1) % identities.length];
    }

    panelName: "polkit"
    cardWidth: 400
    cardHeight: content.implicitHeight + 2 * cardPadding
    onOpening: {
        field.text = "";
        message = flow ? flow.message : "";
        actionId = flow ? flow.actionId : "";
        iconSource = flow && flow.iconName !== "" ? Quickshell.iconPath(flow.iconName, true) : "";
    }
    onOpenedChanged: {
        if (opened)
            field.input.forceActiveFocus();
        else if (flow && !flow.isCompleted)
            flow.cancelAuthenticationRequest();
    }
    // Done one way or another (right password, cancelled by the app, out of tries).
    onFlowChanged: {
        if (!flow && opened)
            close();

    }

    Behavior on cardHeight {
        enabled: prompt.opened

        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }

    }

    Connections {
        function onAuthenticationFailed() {
            field.text = "";
            shake.restart();
        }

        function onIsResponseRequiredChanged() {
            if (prompt.flow.isResponseRequired)
                field.input.forceActiveFocus();

        }

        function onIsCompletedChanged() {
            if (prompt.flow.isCompleted)
                prompt.close();

        }

        target: prompt.opened ? prompt.flow : null
    }

    Column {
        id: content

        x: prompt.cardPadding
        y: prompt.cardPadding
        width: prompt.cardWidth - 2 * prompt.cardPadding
        spacing: 14

        Row {
            width: parent.width
            spacing: 14

            Item {
                width: 36
                height: 36
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.fill: parent
                    visible: prompt.iconSource !== ""
                    source: prompt.iconSource
                    sourceSize: Qt.size(72, 72)
                    smooth: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: prompt.iconSource === ""
                    text: "󰦝"
                    color: Theme.mauve
                    font.family: Theme.font
                    font.pixelSize: 30
                }

            }

            Column {
                width: parent.width - 36 - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text {
                    width: parent.width
                    text: prompt.message
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 13
                    lineHeight: 1.15
                }

                // What exactly is being allowed, for when the message is vague.
                Text {
                    width: parent.width
                    visible: prompt.actionId !== ""
                    text: prompt.actionId
                    elide: Text.ElideMiddle
                    color: Theme.lavender
                    font.family: Theme.font
                    font.pixelSize: 11
                }

            }

        }

        GlassField {
            id: field

            property real shakeOffset: 0

            x: shakeOffset
            width: parent.width
            enabled: !prompt.waiting
            icon: prompt.waiting ? "󰔟" : "󰌾"
            // Some PAM steps ask for a code you should see, not a password.
            secret: !(prompt.flow && prompt.flow.responseVisible)
            textColor: Theme.mauve
            placeholder: prompt.waiting ? "Checking…" : (prompt.flow && prompt.flow.inputPrompt.replace(/:\s*$/, "").trim()) || "Password"
            // The account answering; Tab cycles when there's a choice.
            hint: prompt.flow && prompt.flow.selectedIdentity ? prompt.flow.selectedIdentity.displayName + (prompt.identities.length > 1 ? "  ⇥" : "") : ""
            onAccepted: {
                if (prompt.flow && prompt.flow.isResponseRequired)
                    prompt.flow.submit(text);

            }
            onKeyPressed: (event) => {
                if (event.key === Qt.Key_Escape)
                    prompt.close();
                else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
                    prompt.nextIdentity();
                else
                    return ;
                event.accepted = true;
            }
        }

        // PAM's own words: why a try failed, or what it waits for (a fingerprint…).
        Text {
            width: parent.width
            visible: text !== ""
            text: prompt.flow ? prompt.flow.supplementaryMessage : ""
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            color: prompt.flow && prompt.flow.supplementaryIsError ? Theme.red : Theme.lavender
            font.family: Theme.font
            font.pixelSize: 12
        }

    }

    // Wrong password: the field shakes, like the SDDM picker's.
    SequentialAnimation {
        id: shake

        NumberAnimation {
            target: field
            property: "shakeOffset"
            to: -12
            duration: 50
        }

        NumberAnimation {
            target: field
            property: "shakeOffset"
            to: 10
            duration: 70
        }

        NumberAnimation {
            target: field
            property: "shakeOffset"
            to: -6
            duration: 60
        }

        NumberAnimation {
            target: field
            property: "shakeOffset"
            to: 0
            duration: 60
        }

    }

}
