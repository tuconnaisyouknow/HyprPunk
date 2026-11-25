import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs.components
import qs.config
import qs.services
import qs.theme

// The settings' music page: the players the shell follows, and whether the island's
// equalizer and the desktop's wave move with the music.
SettingsPage {
    id: page

    // The players to choose from, by the name the settings keep: the ones running, and
    // the ones followed even while they're closed. Only rebuilt when they really change:
    // that would take the keyboard away from the one you're on.
    readonly property var known: {
        const names = Mpris.players.values.map((player) => {
            return Players.sourceOf(player);
        }).concat(MusicSettings.sources);
        return names.filter((name, index) => {
            return names.indexOf(name) === index;
        }).sort();
    }
    property var shown: []

    // As its app calls itself, or as the player does while its app isn't found.
    function sourceName(name) {
        const entry = DesktopEntries.byId(name) ?? DesktopEntries.heuristicLookup(name);
        if (entry !== null)
            return entry.name;

        const running = Mpris.players.values.find((player) => {
            return Players.sourceOf(player) === name;
        });
        return running ? running.identity : name;
    }

    // Followed or not. With none left, every player is.
    function toggle(name) {
        const followed = MusicSettings.sources;
        MusicSettings.set("sources", (followed.includes(name) ? followed.filter((other) => {
            return other !== name;
        }) : followed.concat([name])).join(","));
    }

    title: "Music"
    description: "What plays shows in the island, in its player card and on the lock screen, and answers the media keys."
    onKnownChanged: {
        if (JSON.stringify(known) !== JSON.stringify(shown))
            shown = known;

    }
    Component.onCompleted: shown = known

    SettingRow {
        Layout.fillWidth: true
        icon: "radio"
        title: "Players"
        description: "Any player, or only the ones you choose: a player has to be open to show up here. With several open, the shell follows the one that played last, unless you turn to one's page in the player card."

        Flow {
            width: parent.width
            spacing: Metrics.spacing.normal

            GlassButton {
                label: "Any"
                accent: MusicSettings.sources.length === 0
                activeFocusOnTab: true
                onClicked: {
                    if (!accent)
                        MusicSettings.set("sources", "");

                }
            }

            Repeater {
                model: page.shown

                GlassButton {
                    required property string modelData

                    label: page.sourceName(modelData)
                    accent: MusicSettings.sources.includes(modelData)
                    activeFocusOnTab: true
                    onClicked: page.toggle(modelData)
                }

            }

        }

    }

    SettingRow {
        Layout.fillWidth: true
        icon: "equalizer"
        title: "Equalizer"
        description: "The bars at the island's end, dancing while the music plays. Moving, they keep the screen redrawing, which costs a laptop's battery and smoothness. Off, they stand still."
        checkable: true
        checked: MusicSettings.equalizer
        onToggled: MusicSettings.set("equalizer", !checked)
    }

    SettingRow {
        Layout.fillWidth: true
        icon: "waves"
        title: "Wave"
        description: "The wave at the bottom of the desktop and the lock screen, moving with the music. Like the equalizer, it keeps the screen redrawing."
        checkable: true
        checked: MusicSettings.wave
        onToggled: MusicSettings.set("wave", !checked)
    }

}
