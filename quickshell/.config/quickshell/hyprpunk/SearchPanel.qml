import QtQuick

// An island card with a search field over a list or grid of results, shared by the
// clipboard, emoji and keybindings panels. You keep typing in the field while the
// arrows, Tab or Ctrl + the Vim keys move the selection; Enter picks (activated).
IslandPanel {
    id: panel

    property string searchIcon: ""
    property string placeholder: "Search"
    // Shown at the right of the field, e.g. the name of the selected item.
    property string hint: ""
    property string query: ""
    // Number of results and how they are laid out (1 for a list).
    property int count: 0
    property int columns: 1
    property int selectedIndex: 0
    // ListView or GridView of the results, kept scrolled to the selection.
    property var view: null
    property real bodyHeight: 0
    readonly property int cardPadding: 14
    readonly property int fieldHeight: 44
    readonly property int sectionSpacing: 12
    readonly property real bodyWidth: cardWidth - 2 * cardPadding
    default property alias body: bodyArea.data

    signal activated(int index, bool shift)

    function move(dx, dy) {
        if (count > 0)
            selectedIndex = Math.max(0, Math.min(count - 1, selectedIndex + dx + dy * columns));

    }

    cardHeight: 2 * cardPadding + fieldHeight + (bodyHeight > 0 ? sectionSpacing + bodyHeight : 0)
    onOpening: {
        field.text = "";
        selectedIndex = 0;
        if (view)
            view.positionViewAtBeginning();

    }
    onOpenedChanged: {
        if (opened)
            field.input.forceActiveFocus();

    }
    onQueryChanged: {
        selectedIndex = 0;
        if (view)
            view.positionViewAtBeginning();

    }
    onSelectedIndexChanged: {
        if (view && selectedIndex >= 0 && selectedIndex < count)
            view.positionViewAtIndex(selectedIndex, ListView.Contain);

    }

    Behavior on cardHeight {
        enabled: panel.opened

        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }

    }

    GlassField {
        id: field

        anchors.top: parent.top
        anchors.topMargin: panel.cardPadding
        anchors.horizontalCenter: parent.horizontalCenter
        width: panel.bodyWidth
        icon: panel.searchIcon
        placeholder: panel.placeholder
        hint: panel.hint
        onTextChanged: panel.query = text
        onKeyPressed: (event) => {
            const move = panel.controlMove(event);
            const grid = panel.columns > 1;
            if (move)
                panel.move(move[0], move[1]);
            else if (event.key === Qt.Key_Escape)
                panel.back();
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                panel.count > 0 && panel.activated(panel.selectedIndex, (event.modifiers & Qt.ShiftModifier) !== 0);
            else if (event.key === Qt.Key_Down)
                panel.move(0, 1);
            else if (event.key === Qt.Key_Up)
                panel.move(0, -1);
            else if (event.key === Qt.Key_Tab)
                panel.move(1, 0);
            else if (event.key === Qt.Key_Backtab)
                panel.move(-1, 0);
            else if (grid && event.key === Qt.Key_Left)
                panel.move(-1, 0);
            else if (grid && event.key === Qt.Key_Right)
                panel.move(1, 0);
            else
                return ;
            event.accepted = true;
        }
    }

    Item {
        id: bodyArea

        anchors.top: field.bottom
        anchors.topMargin: panel.sectionSpacing
        anchors.horizontalCenter: parent.horizontalCenter
        width: panel.bodyWidth
        height: panel.bodyHeight
    }

}
