pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking
import qs.config

// How you're connected, from NetworkManager: the device in use, the Wi-Fi around, and
// whether a VPN is in the way. Always on, like the bar's icon. A network that wants you
// to sign in first gets a notification that takes you to its page, and asks to set a VPN
// aside when it hides that page (captive-portal.sh).
Singleton {
    id: network

    // The connected device first, else one NetworkManager is bringing up.
    readonly property var device: {
        let connecting = null;
        for (const device of Networking.devices.values) {
            if (device.connected)
                return device;

            if (connecting === null && device.state === ConnectionState.Connecting)
                connecting = device;

        }
        return connecting;
    }
    // What carries you once it's up, a new one each time you join a network.
    readonly property var link: device !== null && device.connected ? device : null
    readonly property bool connecting: (device !== null && !device.connected) || Vpn.connecting
    // Wired with a VPN up: the cable's icon gets a padlock.
    readonly property bool wiredLocked: device !== null && device.connected && device.type === DeviceType.Wired && Vpn.connection !== null
    readonly property bool wiredConnected: {
        for (const device of Networking.devices.values) {
            if (device.type === DeviceType.Wired && device.connected)
                return true;

        }
        return false;
    }
    readonly property var wifiDevice: {
        for (const device of Networking.devices.values) {
            if (device.type === DeviceType.Wifi)
                return device;

        }
        return null;
    }
    // Connected first, then the known ones, then the strongest.
    readonly property var wifiNetworks: {
        if (wifiDevice === null || !Networking.wifiEnabled)
            return [];

        return wifiDevice.networks.values.slice().sort((a, b) => {
            return (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength);
        });
    }
    readonly property var activeWifi: wifiNetworks.length > 0 && wifiNetworks[0].connected ? wifiNetworks[0] : null

    // A VPN that was online keeps NetworkManager's word for five minutes, whatever network
    // it now crosses: joining one asks again, so a sign-in page it hides is found at once.
    onLinkChanged: {
        if (link !== null)
            Networking.checkConnectivity();

    }

    Connections {
        function onConnectivityChanged() {
            const step = {
                [NetworkConnectivity.Portal]: "portal",
                [NetworkConnectivity.Limited]: "limited",
                [NetworkConnectivity.Full]: "online"
            }[Networking.connectivity];
            if (step)
                Quickshell.execDetached([Session.scripts + "/captive-portal.sh", step]);

        }

        target: Networking
    }

}
