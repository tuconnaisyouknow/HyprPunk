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
    readonly property string passwordFont: themeFontLoader.status === FontLoader.Ready ? themeFontLoader.name : Theme.font

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
        passwordField.text = "";
        focusCard();
    }

    panelName: "sddm"
    // Shrinks around the password field while it is asked.
    cardWidth: askingPassword ? passwordField.width + 2 * cardPadding : 820
    cardHeight: askingPassword ? passwordField.height + 2 * cardPadding : carousel.thumbHeight + 2 * cardPadding
    keyTargets: [keys]
    onOpening: {
        askingPassword = false;
        passwordField.text = "";
        listProcess.running = true;
        currentFile.reload();
        carousel.centreOn(carousel.currentId);
    }
    onOpenedChanged: {
        if (!opened) {
            askingPassword = false;
            passwordField.text = "";
        }
    }
    onAskingPasswordChanged: {
        if (askingPassword)
            passwordField.input.forceActiveFocus();

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
                passwordField.text = "";
                currentFile.reload();
                picker.close();
            } else if (picker.askingPassword && /incorrect password|try again|password is required/i.test(errors)) {
                passwordField.text = "";
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

    CarouselKeys {
        id: keys

        panel: picker
        carousel: carousel
        onPicked: picker.apply()
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

    // Password for sudo, alone in the shrunk card, its hidden letters like on the login
    // screen, in the theme's own font.
    GlassField {
        id: passwordField

        property real shakeOffset: 0

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: shakeOffset
        width: 300
        visible: opacity > 0
        opacity: picker.askingPassword ? 1 : 0
        scale: picker.askingPassword ? 1 : 0.92
        enabled: !picker.applying
        icon: picker.applying ? "󰔟" : "󰌾"
        secret: true
        textColor: Theme.mauve
        fontFamily: picker.passwordFont
        placeholder: picker.applying ? "Applying…" : "Password for sudo"
        onAccepted: {
            if (text !== "")
                picker.run(text);

        }
        onKeyPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                picker.cancelPassword();
                event.accepted = true;
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
