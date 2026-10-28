import QtQuick
import Quickshell
import Quickshell.Io

// Pick the login screen's theme, in the same carousel as the wallpapers. Applying it
// runs ~/Scripts/sddm.sh through sudo, and if sudo wants your password, the card
// asks for it right there.
IslandPanel {
    id: picker

    readonly property string home: Quickshell.env("HOME")
    readonly property string themesDir: home + "/.dotfiles/sddm/themes"
    readonly property string previewDir: home + "/.dotfiles/sddm/previews"
    readonly property string sddmScript: home + "/Scripts/sddm.sh"
    readonly property int cardPadding: 14
    property bool askingPassword: false
    property bool applying: false
    property string pendingTheme: ""
    property string pendingPassword: ""
    // Font of the active theme (its font/ folder), used by the password field like on its login screen.
    property string themeFont: ""
    readonly property string passwordFont: themeFontLoader.status === FontLoader.Ready ? themeFontLoader.name : "JetBrainsMono Nerd Font"

    function apply() {
        const theme = carousel.centreId;
        if (theme === "" || applying)
            return ;

        if (theme === carousel.currentId) {
            close();
            return ;
        }
        pendingTheme = theme;
        sudoCheck.running = true;
    }

    // Empty password: sudo already has valid credentials.
    function run(password) {
        applying = true;
        pendingPassword = password;
        applyProcess.stdinEnabled = true;
        applyProcess.command = password === "" ? ["sudo", "-n", "env", "HOME=" + home, sddmScript, pendingTheme] : ["sudo", "-S", "-p", "", "env", "HOME=" + home, sddmScript, pendingTheme];
        applyProcess.running = true;
    }

    function cancelPassword() {
        askingPassword = false;
        passwordInput.text = "";
        focusCard();
    }

    panelName: "sddm"
    // Shrinks around the password field while it is asked.
    cardWidth: askingPassword ? passwordField.width + 2 * cardPadding : 820
    cardHeight: askingPassword ? passwordField.height + 2 * cardPadding : carousel.thumbHeight + 2 * cardPadding
    keyTargets: [keys]
    onOpening: {
        askingPassword = false;
        passwordInput.text = "";
        listProcess.running = true;
        currentFile.reload();
        carousel.centreOn(carousel.currentId);
    }
    onOpenedChanged: {
        if (!opened) {
            askingPassword = false;
            passwordInput.text = "";
        }
    }
    onAskingPasswordChanged: {
        if (askingPassword)
            passwordInput.forceActiveFocus();

    }

    // One "name<TAB>preview" line per theme, the preview being empty when there is none.
    Process {
        id: listProcess

        command: ["sh", "-c", "for theme in \"$0\"/*/; do name=$(basename \"$theme\"); preview=''; for ext in png jpg jpeg webp; do [ -f \"$1/$name.$ext\" ] && { preview=\"$1/$name.$ext\"; break; }; done; printf '%s\\t%s\\n' \"$name\" \"$preview\"; done", picker.themesDir, picker.previewDir]
        running: true

        stdout: StdioCollector {
            onStreamFinished: carousel.setItems(text.split("\n").filter((line) => {
                return line !== "";
            }).map((line) => {
                const fields = line.split("\t");
                return {
                    "id": fields[0],
                    "image": fields[1] || ""
                };
            }))
        }

    }

    Process {
        id: fontProcess

        command: ["sh", "-c", "find \"$0/$1/font\" -maxdepth 1 -type f \\( -iname '*.ttf' -o -iname '*.otf' \\) 2>/dev/null | sort | head -n 1", picker.themesDir, carousel.currentId]

        stdout: StdioCollector {
            onStreamFinished: picker.themeFont = text.trim()
        }

    }

    FontLoader {
        id: themeFontLoader

        source: picker.themeFont !== "" ? "file://" + picker.themeFont : ""
    }

    FileView {
        id: currentFile

        path: "/etc/sddm.conf.d/theme.conf"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const match = text().match(/^Current=(.*)$/m);
            carousel.currentId = match ? match[1].trim() : "";
            fontProcess.running = carousel.currentId !== "";
        }
    }

    Behavior on cardWidth {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }

    }

    Behavior on cardHeight {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }

    }

    Process {
        id: sudoCheck

        command: ["sudo", "-n", "true"]
        onExited: (exitCode) => {
            if (exitCode === 0)
                picker.run("");
            else
                picker.askingPassword = true;
        }
    }

    Process {
        id: applyProcess

        stdinEnabled: true
        // The password only goes through stdin, which is then closed, so a wrong one
        // fails straight away instead of sudo waiting for another try.
        onStarted: {
            if (picker.pendingPassword !== "")
                write(picker.pendingPassword + "\n");

            picker.pendingPassword = "";
            stdinEnabled = false;
        }
        onExited: (exitCode) => {
            picker.applying = false;
            const errors = applyErrors.text.trim();
            if (exitCode === 0) {
                picker.askingPassword = false;
                passwordInput.text = "";
                currentFile.reload();
                picker.close();
            } else if (picker.askingPassword && /incorrect password|try again|password is required/i.test(errors)) {
                passwordInput.text = "";
                shake.restart();
            } else {
                Quickshell.execDetached(["notify-send", "-u", "critical", "Failed to apply SDDM theme", errors.split("\n").pop() || picker.pendingTheme]);
                picker.close();
            }
        }

        stderr: StdioCollector {
            id: applyErrors
        }

    }

    Item {
        id: keys

        Keys.onPressed: (event) => {
            const direction = picker.horizontalKey(event);
            if (direction !== 0) {
                carousel.step(direction);
                event.accepted = true;
            }
        }
        Keys.onLeftPressed: carousel.step(-1)
        Keys.onRightPressed: carousel.step(1)
        Keys.onTabPressed: carousel.step(1)
        Keys.onBacktabPressed: carousel.step(-1)
        Keys.onReturnPressed: picker.apply()
        Keys.onEnterPressed: picker.apply()
    }

    // Kept at full width and centred, so it does not reflow while the card shrinks.
    ImageCarousel {
        id: carousel

        anchors.centerIn: parent
        width: 820
        enabled: !picker.askingPassword
        opacity: picker.askingPassword ? 0 : 1
        onActivated: picker.apply()

        Behavior on opacity {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }

        }

    }

    // Password for sudo, alone in the shrunk card.
    Rectangle {
        id: passwordField

        property real shakeOffset: 0

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: shakeOffset
        width: 300
        height: 44
        radius: 22
        color: "transparent"
        visible: opacity > 0
        opacity: picker.askingPassword ? 1 : 0
        scale: picker.askingPassword ? 1 : 0.92

        GlassSurface {
            radius: parent.radius
            backgroundColor: Qt.rgba(30 / 255, 30 / 255, 46 / 255, 0.6)
            focused: passwordInput.activeFocus
        }

        Text {
            id: lockIcon

            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: picker.applying ? "󰔟" : "󰌾"
            color: "#cba6f7"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
        }

        TextInput {
            id: passwordInput

            anchors.left: lockIcon.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            enabled: !picker.applying
            // Hidden letters as little squares, with the blinking block cursor,
            // just like the high-above-the-noise login screen.
            echoMode: TextInput.Password
            passwordCharacter: "■"
            color: "#cba6f7"
            selectionColor: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.35)
            font.family: picker.passwordFont
            font.pixelSize: 14
            font.letterSpacing: 3
            clip: true
            cursorDelegate: Item {
            }
            onAccepted: {
                if (text !== "")
                    picker.run(text);

            }
            Keys.onEscapePressed: (event) => {
                picker.cancelPassword();
                event.accepted = true;
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: parent.text === ""
                text: picker.applying ? "Applying…" : "Password for sudo"
                color: "#7f849c"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: parent.font.pixelSize
            }

            BlockCursor {
                input: passwordInput
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutBack
            }

        }

    }

    // Wrong password: the field shakes like on macOS.
    SequentialAnimation {
        id: shake

        loops: 1

        NumberAnimation {
            target: passwordField
            property: "shakeOffset"
            to: -12
            duration: 50
        }

        NumberAnimation {
            target: passwordField
            property: "shakeOffset"
            to: 10
            duration: 70
        }

        NumberAnimation {
            target: passwordField
            property: "shakeOffset"
            to: -6
            duration: 60
        }

        NumberAnimation {
            target: passwordField
            property: "shakeOffset"
            to: 0
            duration: 60
        }

    }

}
