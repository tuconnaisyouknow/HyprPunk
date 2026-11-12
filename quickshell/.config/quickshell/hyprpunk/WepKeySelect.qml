import QtQuick

// What a WEP password is, for the fields that ask one: the key itself, or the
// passphrase some routers make it from. The two can't be told apart by looking.
// value is wifi-connection.py's wepKeyType.
FormSelect {
    readonly property string value: current !== null ? current.value : "1"

    function reset() {
        currentIndex = 0;
        expanded = false;
    }

    label: "WEP key type"
    options: [{
        "label": "Key (5 or 13 characters, 10 or 26 hex digits)",
        "value": "1"
    }, {
        "label": "Passphrase",
        "value": "2"
    }]
}
