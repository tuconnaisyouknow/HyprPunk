import QtQuick

// Keeps a service working while a surface shows its values: hold one, active while the
// surface is shown, and the service runs while anything holds it (its refCount is above
// zero). How every service that only works while someone looks is woken up.
QtObject {
    required property QtObject service
    property bool active: true
    // The service this counts in right now, so a change of service or of active never
    // counts twice or forgets to give back.
    property QtObject held: null

    function hold() {
        const wanted = active ? service : null;
        if (wanted === held)
            return ;

        if (held !== null)
            held.refCount -= 1;

        if (wanted !== null)
            wanted.refCount += 1;

        held = wanted;
    }

    onActiveChanged: hold()
    onServiceChanged: hold()
    Component.onCompleted: hold()
    Component.onDestruction: {
        if (held !== null)
            held.refCount -= 1;

    }
}
