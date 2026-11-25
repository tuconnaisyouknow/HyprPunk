import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services
import qs.theme

// The settings' launcher page: the apps pinned first in the launcher, and the ones it
// never shows. Every app is listed, narrowed down by what you type.
SettingsPage {
    id: page

    // Your apps by name, from the launcher's own list: it only moves when your apps do,
    // not each time Quickshell lists them again (at every command in a terminal).
    readonly property var apps: Apps.installed.filter((entry) => {
        return !entry.noDisplay;
    }).sort((a, b) => {
        return a.name.localeCompare(b.name);
    })
    readonly property var byId: {
        const map = {};
        for (const entry of apps)
            map[entry.id] = entry;
        return map;
    }
    readonly property string needle: filter.text.trim().toLowerCase()
    readonly property int matching: apps.filter(matches).length

    function matches(entry) {
        return needle === "" || entry.name.toLowerCase().includes(needle) || entry.id.toLowerCase().includes(needle);
    }

    title: "Launcher"
    description: "Super+Space opens it. Pinned apps come first, in the order you pinned them, then the ones you use most. Hidden ones never show, even when you search."

    SettingRow {
        Layout.fillWidth: true
        icon: "apps"
        title: "Apps"
        description: LauncherSettings.pinned.length + " pinned, " + LauncherSettings.hidden.length + " hidden."

        ColumnLayout {
            width: parent.width
            spacing: Metrics.spacing.small

            FormField {
                id: filter

                Layout.fillWidth: true
                Layout.bottomMargin: Metrics.spacing.normal
                placeholder: "Find an app"
            }

            // A row per app, kept by its id: typing only hides the ones that don't match,
            // and pinning or hiding leaves the list as it is, so the row you're on keeps
            // the keyboard.
            Repeater {
                model: ScriptModel {
                    values: page.apps.map((entry) => {
                        return entry.id;
                    })
                }

                // Built between frames, the top ones first: all at once, the rows held the
                // window still for a fifth of a second as the page opened. Each keeps its
                // place meanwhile, and fades in as it comes.
                Loader {
                    id: app

                    required property string modelData
                    readonly property var entry: page.byId[modelData]
                    readonly property bool pinned: LauncherSettings.pinned.includes(modelData)
                    readonly property bool hidden: LauncherSettings.hidden.includes(modelData)

                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    visible: page.matches(entry)
                    asynchronous: true
                    opacity: status === Loader.Ready ? 1 : 0

                    Behavior on opacity {
                        Anim {
                            token: Motion.color.small
                        }

                    }

                    sourceComponent: RowLayout {
                        id: row

                        readonly property string iconPath: Quickshell.iconPath(app.entry.icon, true)

                        spacing: Metrics.spacing.large

                        Item {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24

                            IconImage {
                                anchors.fill: parent
                                visible: row.iconPath !== ""
                                source: row.iconPath
                                asynchronous: true
                                opacity: app.hidden ? 0.5 : 1
                            }

                            Icon {
                                anchors.centerIn: parent
                                visible: row.iconPath === ""
                                text: "apps"
                                color: Colors.secondary
                                size: Metrics.text.title
                            }

                        }

                        Text {
                            Layout.fillWidth: true
                            text: app.entry.name
                            color: app.pinned ? Colors.primary : Colors.alpha(Colors.secondary, app.hidden ? 0.5 : 1)
                            elide: Text.ElideRight
                            font.family: Metrics.font
                            font.pixelSize: Metrics.text.emphasis
                            font.weight: app.pinned ? Font.Bold : Font.Normal
                        }

                        GlassButton {
                            icon: "keep"
                            label: "Pin"
                            accent: app.pinned
                            activeFocusOnTab: true
                            onClicked: LauncherSettings.setPinned(app.modelData, !app.pinned)
                        }

                        GlassButton {
                            icon: "visibility_off"
                            label: "Hide"
                            accent: app.hidden
                            activeFocusOnTab: true
                            onClicked: LauncherSettings.setHidden(app.modelData, !app.hidden)
                        }

                    }

                }

            }

            Text {
                visible: page.matching === 0
                text: "No app matches."
                color: Colors.secondary
                font.family: Metrics.font
                font.pixelSize: Metrics.text.body
            }

        }

    }

}
