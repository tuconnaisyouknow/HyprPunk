#!/usr/bin/env python3
"""Creates or replaces a Wi-Fi connection for the Quickshell control center: WPA/WPA2/
WPA3 Enterprise (802.1X) or LEAP with the settings of NetworkManager's own Wi-Fi
dialog, or WPA/WPA3 Personal with a password.

Reads one JSON object on stdin (secrets included, so they never show in the
process list) and prints one JSON line: {"ok": true} or {"ok": false, "error": ...}.

    {"ssid": "home", "keyMgmt": "wpa-psk" | "sae", "psk": "..."}

    {"ssid": "eduroam", "keyMgmt": "wpa-eap", "eap": "peap",
     "identity": "...", "password": "...", "anonymousIdentity": "...",
     "domain": "...", "caCert": "/path", "caCertPassword": "...",
     "peapVersion": "" | "0" | "1", "phase2Auth": "mschapv2", "phase2AuthEap": "",
     "clientCert": "/path", "clientCertPassword": "...", "privateKey": "/path",
     "privateKeyPassword": "...", "pacFile": "/path", "fastProvisioning": "0".."3"}

keyMgmt "ieee8021x" with eap "leap" is Cisco LEAP (identity and password only).
The new profile replaces the other profiles of the same network once it works,
and is removed again when it fails, so a wrong password leaves nothing behind.

`wifi-connection.py --read SSID` prints the saved enterprise settings of a network
in the same form (secrets included), to fill the form when it is modified.
"""

import json
import sys
import uuid

import dbus
import dbus.mainloop.glib
from gi.repository import GLib

NM = "org.freedesktop.NetworkManager"
NM_PATH = "/org/freedesktop/NetworkManager"
SETTINGS_PATH = "/org/freedesktop/NetworkManager/Settings"
PROPERTIES = "org.freedesktop.DBus.Properties"

DEVICE_TYPE_WIFI = 2
ACTIVE_ACTIVATED = 2
ACTIVE_DEACTIVATED = 4
DEVICE_FAILED = 120
TIMEOUT = 90

# NMDeviceStateReason values worth a sentence.
DEVICE_REASONS = {
    7: "The network asked for credentials that are missing",
    8: "The network closed the authentication (wrong credentials?)",
    9: "The authentication settings were rejected",
    10: "Authentication failed: check the credentials and certificates",
    11: "The authentication timed out",
    53: "The network was not found",
}


def reply(ok, error=""):
    print(json.dumps({"ok": True} if ok else {"ok": False, "error": error}), flush=True)


def cert(path):
    # The path scheme: a NUL-terminated file:// URI.
    return dbus.ByteArray(b"file://" + path.encode() + b"\0")


def build(request):
    ssid = request["ssid"]
    eap = request.get("eap", "")
    key_mgmt = request.get("keyMgmt", "wpa-eap")
    security = {"key-mgmt": key_mgmt}
    settings = {
        "connection": {"id": ssid, "uuid": str(uuid.uuid4()), "type": "802-11-wireless"},
        "802-11-wireless": {
            "ssid": dbus.ByteArray(ssid.encode()),
            "mode": "infrastructure",
            "security": "802-11-wireless-security",
        },
        "802-11-wireless-security": security,
        "ipv4": {"method": "auto"},
        "ipv6": {"method": "auto"},
    }
    if key_mgmt in ("wpa-psk", "sae"):
        security["psk"] = request.get("psk", "")
        return settings
    if key_mgmt == "ieee8021x" and eap == "leap":
        # Cisco LEAP: the credentials live in the security setting.
        security["auth-alg"] = "leap"
        security["leap-username"] = request.get("identity", "")
        security["leap-password"] = request.get("password", "")
        return settings

    x = {"eap": dbus.Array([eap], signature="s")}
    text = {
        "identity": "identity",
        "password": "password",
        "anonymousIdentity": "anonymous-identity",
        "domain": "domain-suffix-match",
        "caCertPassword": "ca-cert-password",
        "phase2Auth": "phase2-auth",
        "phase2AuthEap": "phase2-autheap",
        "clientCertPassword": "client-cert-password",
        "privateKeyPassword": "private-key-password",
        "fastProvisioning": "phase1-fast-provisioning",
        "pacFile": "pac-file",
    }
    for key, name in text.items():
        if request.get(key):
            x[name] = request[key]
    if request.get("peapVersion") in ("0", "1"):
        x["phase1-peapver"] = request["peapVersion"]
    for key, name in (("caCert", "ca-cert"), ("clientCert", "client-cert"), ("privateKey", "private-key")):
        if request.get(key):
            x[name] = cert(request[key])
    settings["802-1x"] = x
    return settings


def wifi_device(bus):
    manager = dbus.Interface(bus.get_object(NM, NM_PATH), NM)
    for path in manager.GetDevices():
        device = bus.get_object(NM, path)
        if device.Get(NM + ".Device", "DeviceType", dbus_interface=PROPERTIES) == DEVICE_TYPE_WIFI:
            return path
    return None


def same_network(bus, ssid):
    settings = dbus.Interface(bus.get_object(NM, SETTINGS_PATH), NM + ".Settings")
    found = []
    for path in settings.ListConnections():
        connection = dbus.Interface(bus.get_object(NM, path), NM + ".Settings.Connection")
        try:
            values = connection.GetSettings()
        except dbus.DBusException:
            continue
        wireless = values.get("802-11-wireless", {})
        if bytes(wireless.get("ssid", b"")) == ssid.encode():
            found.append(path)
    return found


def delete(bus, path):
    try:
        dbus.Interface(bus.get_object(NM, path), NM + ".Settings.Connection").Delete()
    except dbus.DBusException:
        pass


def path_of(value):
    # Back from the path scheme; certificates stored as data have no path to show.
    raw = bytes(value).rstrip(b"\0")
    return raw[len(b"file://"):].decode() if raw.startswith(b"file://") else ""


def read(ssid):
    bus = dbus.SystemBus()
    found = same_network(bus, ssid)
    if not found:
        print(json.dumps({}), flush=True)
        return
    connection = dbus.Interface(bus.get_object(NM, found[0]), NM + ".Settings.Connection")
    settings = connection.GetSettings()
    security = settings.get("802-11-wireless-security", {})
    values = {"keyMgmt": str(security.get("key-mgmt", ""))}
    if security.get("auth-alg") == "leap":
        values.update(eap="leap", identity=str(security.get("leap-username", "")))
        try:
            secrets = connection.GetSecrets("802-11-wireless-security").get("802-11-wireless-security", {})
            values["password"] = str(secrets.get("leap-password", ""))
        except dbus.DBusException:
            pass
        print(json.dumps(values), flush=True)
        return
    x = dict(settings.get("802-1x", {}))
    try:
        x.update(connection.GetSecrets("802-1x").get("802-1x", {}))
    except dbus.DBusException:
        pass
    methods = x.get("eap", [])
    values["eap"] = str(methods[0]) if methods else ""
    text = {
        "identity": "identity",
        "password": "password",
        "anonymous-identity": "anonymousIdentity",
        "domain-suffix-match": "domain",
        "ca-cert-password": "caCertPassword",
        "phase1-peapver": "peapVersion",
        "phase2-auth": "phase2Auth",
        "phase2-autheap": "phase2AuthEap",
        "client-cert-password": "clientCertPassword",
        "private-key-password": "privateKeyPassword",
        "phase1-fast-provisioning": "fastProvisioning",
        "pac-file": "pacFile",
    }
    for name, key in text.items():
        if name in x:
            values[key] = str(x[name])
    for name, key in (("ca-cert", "caCert"), ("client-cert", "clientCert"), ("private-key", "privateKey")):
        if name in x:
            values[key] = path_of(x[name])
    print(json.dumps(values), flush=True)


def main():
    if len(sys.argv) == 3 and sys.argv[1] == "--read":
        read(sys.argv[2])
        return
    try:
        request = json.loads(sys.stdin.readline())
    except ValueError:
        reply(False, "Invalid request")
        return

    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    device = wifi_device(bus)
    if device is None:
        reply(False, "No Wi-Fi device")
        return

    previous = same_network(bus, request["ssid"])
    manager = dbus.Interface(bus.get_object(NM, NM_PATH), NM)
    try:
        connection, active = manager.AddAndActivateConnection(build(request), device, "/")
    except dbus.DBusException as error:
        reply(False, error.get_dbus_message() or str(error))
        return

    loop = GLib.MainLoop()
    state = {"reason": 0, "done": False}

    def finish(ok, error=""):
        if state["done"]:
            return
        state["done"] = True
        if ok:
            for path in previous:
                if path != connection:
                    delete(bus, path)
        else:
            delete(bus, connection)
        reply(ok, error)
        loop.quit()

    def on_device(new, old, reason):
        if new == DEVICE_FAILED:
            state["reason"] = int(reason)

    def on_active(new, reason):
        if new == ACTIVE_ACTIVATED:
            finish(True)
        elif new == ACTIVE_DEACTIVATED:
            finish(False, DEVICE_REASONS.get(state["reason"], "Connection failed"))

    bus.add_signal_receiver(on_device, "StateChanged", NM + ".Device", NM, device)
    bus.add_signal_receiver(on_active, "StateChanged", NM + ".Connection.Active", NM, active)
    GLib.timeout_add_seconds(TIMEOUT, lambda: finish(False, "The connection timed out"))
    # It may have got there before the receivers were in place.
    try:
        current = bus.get_object(NM, active).Get(NM + ".Connection.Active", "State", dbus_interface=PROPERTIES)
        if current == ACTIVE_ACTIVATED:
            finish(True)
    except dbus.DBusException:
        pass
    if not state["done"]:
        loop.run()


if __name__ == "__main__":
    main()
