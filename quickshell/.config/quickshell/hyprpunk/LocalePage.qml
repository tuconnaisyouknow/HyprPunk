import QtQuick
import QtQuick.Layouts

// The control center's locale page: the interface language and the regional formats,
// each picked on its own.
ColumnLayout {
    id: page

    required property var center

    signal backRequested()

    spacing: 6

    PageHeader {
        Layout.fillWidth: true
        Layout.bottomMargin: 6
        title: "Locale"
        toggleVisible: false
        onBackRequested: page.backRequested()
    }

    Text {
        Layout.topMargin: 0
        text: "Interface language"
        color: Theme.secondary
        font.family: Theme.font
        font.pixelSize: 12
        font.weight: Font.Bold
    }

    Repeater {
        model: page.center.localeProfiles

        ListRow {
            required property var modelData

            Layout.fillWidth: true
            icon: modelData.id.toUpperCase()
            title: modelData.name
            subtitle: modelData.locale
            trailing: page.center.localeLanguage === modelData.id ? "\uf00c" : ""
            highlighted: page.center.localeLanguage === modelData.id
            onClicked: page.center.setLocale("language", modelData.id)
        }

    }

    Text {
        Layout.topMargin: 8
        text: "Regional formats"
        color: Theme.secondary
        font.family: Theme.font
        font.pixelSize: 12
        font.weight: Font.Bold
    }

    Repeater {
        model: page.center.localeProfiles

        ListRow {
            required property var modelData

            Layout.fillWidth: true
            icon: modelData.id.toUpperCase()
            title: modelData.name
            subtitle: modelData.locale
            trailing: page.center.localeRegional === modelData.id ? "\uf00c" : ""
            highlighted: page.center.localeRegional === modelData.id
            onClicked: page.center.setLocale("regional", modelData.id)
        }

    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 6
        wrapMode: Text.WordWrap
        text: "New apps use it right away. Log out and back in to apply it to the apps already open."
        color: Theme.secondary
        font.family: Theme.font
        font.pixelSize: 12
    }

}
