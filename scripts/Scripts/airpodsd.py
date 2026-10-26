#!/usr/bin/env python3
"""AirPods companion of the HyprPunk shell, started by quickshell.

Reads the Apple "proximity pairing" BLE advertisements (battery, ear detection,
lid state, pairing mode) and talks AAP (Apple's accessory protocol, L2CAP PSM
0x1001) with the connected AirPods for exact battery levels, ear detection and
the proximity keys that tell our AirPods' rotating BLE addresses apart from
anyone else's.

Writes one JSON object per line on stdout:
    {"event": "state", "devices": [...], "pairing": {...} | null}
    {"event": "popup", "address": "...", "reason": "lid" | "connected" | "pairing"}
    {"event": "lidClosed", "address": "..."}
and reads one command per line on stdin:
    connect <address> | disconnect <address> | pair <address> | ignore <address>
    control <address> <setting> <value>   (a setting of CONTROLS, sent over AAP)

The protocol details come from LibrePods (https://github.com/kavishdevar/librepods).
"""

import errno
import json
import os
import re
import socket
import subprocess
import sys
import threading
import time
import urllib.request

import dbus
import dbus.mainloop.glib
import dbus.service
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from gi.repository import GLib

BLUEZ = "org.bluez"
ADAPTER = "org.bluez.Adapter1"
DEVICE = "org.bluez.Device1"
PROPERTIES = "org.freedesktop.DBus.Properties"
AGENT_PATH = "/org/hyprpunk/airpods/agent"
APPLE = 0x004C
AAP_PSM = 0x1001

# Model ids of the proximity pairing message (and of the BR/EDR modalias):
# name and shape, "buds" (two pods and a case) or "headphones" (one battery).
MODELS = {
    0x2002: ("AirPods", "buds"),
    0x200F: ("AirPods (2nd generation)", "buds"),
    0x2013: ("AirPods (3rd generation)", "buds"),
    0x2019: ("AirPods 4", "buds"),
    0x201B: ("AirPods 4 (ANC)", "buds"),
    0x200E: ("AirPods Pro", "buds"),
    0x2014: ("AirPods Pro 2", "buds"),
    0x2024: ("AirPods Pro 2 (USB-C)", "buds"),
    0x2027: ("AirPods Pro 3", "buds"),
    0x200A: ("AirPods Max", "headphones"),
    0x201F: ("AirPods Max (USB-C)", "headphones"),
}
NAME_PATTERN = re.compile(r"airpods", re.IGNORECASE)
HEADPHONES_PATTERN = re.compile(r"max", re.IGNORECASE)

# Connection state byte of the advertisement: busy with another device.
BUSY_STATES = {0x05, 0x06, 0x07}
# Closer than this, an advertisement we cannot resolve still counts as ours
# (until AAP gave us the keys) or as AirPods being set up next to the computer.
NEAR_RSSI = -62
NEARBY_TIMEOUT = 15
LID_TIMEOUT = 10
# A connection we did not ask for this soon after the case opened came from the AirPods.
LID_CONNECT_WINDOW = 90
POPUP_COOLDOWN = 8
AUTO_CONNECT_COOLDOWN = 20
PAIRING_SCAN_SECONDS = 30
PAIRING_IGNORE_SECONDS = 120

AAP_HANDSHAKE = bytes.fromhex("00000400010002000000000000000000")
AAP_SET_FEATURES = bytes.fromhex("040004004d00d700000000000000")
AAP_REQUEST_NOTIFICATIONS = bytes.fromhex("040004000f00ffffffffff")
AAP_REQUEST_KEYS = bytes.fromhex("0400040030000500")
AAP_HANDSHAKE_ACK = bytes.fromhex("01000400")
AAP_FEATURES_ACK = bytes.fromhex("040004002b00")
AAP_BATTERY = bytes.fromhex("040004000400")
AAP_EAR = bytes.fromhex("040004000600")
AAP_KEYS = bytes.fromhex("04000400310002")
# Control commands: the header, then the setting's identifier and its value, padded to
# four value bytes. The AirPods answer with the same packet once applied, and send the
# current values after the notifications are requested.
AAP_CONTROL = bytes.fromhex("040004000900")
# The settings the shell reads and changes, by AAP identifier: their name and how the
# value byte reads. Listening mode: 1 off, 2 noise cancellation, 3 transparency,
# 4 adaptive. Switches: 1 on, 2 off. Adaptive strength: 0 to 100.
CONTROLS = {
    0x0D: ("listeningMode", "byte"),
    0x28: ("conversationAwareness", "switch"),
    0x2E: ("adaptiveStrength", "byte"),
    0x34: ("allowOff", "switch"),
}
CONTROL_IDS = {name: identifier for identifier, (name, _kind) in CONTROLS.items()}
# AAP battery components and pod states.
COMPONENTS = {0x01: "headset", 0x02: "right", 0x04: "left", 0x08: "case"}
IN_EAR, OUT_OF_EAR, IN_CASE = 0x00, 0x01, 0x02


def state_dir():
    base = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    return os.path.join(base, "hyprpunk")


KEYS_FILE = os.path.join(state_dir(), "airpods-keys.json")

# Apple's renders of the pods and their case (from iOS, as LibrePods ships them),
# downloaded on first use rather than kept in the dotfiles.
IMAGE_URL = (
    "https://raw.githubusercontent.com/kavishdevar/librepods/89356c08cea3db0b6b54792d9329d09a87cc85fa"
    "/android/app/src/main/res-apple/drawable/{}.png"
)
IMAGE_NAMES = {
    0x2002: "airpods_1",
    0x200F: "airpods_2",
    0x2013: "airpods_3",
    0x2019: "airpods_4",
    0x201B: "airpods_4_anc",
    0x200E: "airpods_pro_1",
    0x2014: "airpods_pro_2",
    0x2024: "airpods_pro_2",
    0x2027: "airpods_pro_3",
}
IMAGES_DIR = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "hyprpunk", "airpods")


def log(*parts):
    print("airpodsd:", *parts, file=sys.stderr, flush=True)


def emit(message):
    sys.stdout.write(json.dumps(message, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def model_info(model_id, name=""):
    if model_id in MODELS:
        return MODELS[model_id]
    kind = "headphones" if HEADPHONES_PATTERN.search(name or "") else "buds"
    return (name or "AirPods", kind)


# --- Proximity pairing advertisements -----------------------------------------


def aes_ecb(key, block, decrypt=False):
    cipher = Cipher(algorithms.AES(bytes(key)), modes.ECB())
    worker = cipher.decryptor() if decrypt else cipher.encryptor()
    return worker.update(bytes(block)) + worker.finalize()


def resolves(irk, address):
    """Whether the resolvable private address was generated from this IRK."""
    try:
        rpa = bytes(reversed(bytes.fromhex(address.replace(":", ""))))
    except ValueError:
        return False
    if len(rpa) != 6 or len(irk) != 16:
        return False
    # ah() of the Bluetooth core spec, with the byte order the AirPods' IRK uses.
    padded = bytes(reversed(rpa[3:6] + bytes(13)))
    digest = bytes(reversed(aes_ecb(bytes(reversed(irk)), padded)))
    return digest[:3] == rpa[:3]


def battery_nibble(value):
    # 0xF: unknown (e.g. a pod out of range of the case).
    if value == 0x0F:
        return None
    return min(100, value * 10)


def parse_proximity(data):
    """Decodes the 0x07 message of Apple's manufacturer data."""
    if len(data) < 11 or data[0] != 0x07:
        return None
    message = {
        "pairingMode": data[2] == 0x00,
        "model": data[4] << 8 | data[3],
        "connection": data[10],
    }
    if message["pairingMode"]:
        return message

    status = data[5]
    primary_left = bool(status & 0x20)
    this_in_case = bool(status & 0x40)
    flipped = not primary_left
    pods = data[6]
    flags = data[7] >> 4
    left = (pods >> 4) & 0x0F if flipped else pods & 0x0F
    right = pods & 0x0F if flipped else (pods >> 4) & 0x0F
    xor = flipped ^ this_in_case
    message.update(
        {
            "primaryLeft": primary_left,
            "left": {
                "level": battery_nibble(left),
                "charging": bool(flags & (0x02 if flipped else 0x01)),
                "inEar": bool(status & (0x08 if xor else 0x02)),
            },
            "right": {
                "level": battery_nibble(right),
                "charging": bool(flags & (0x01 if flipped else 0x02)),
                "inEar": bool(status & (0x02 if xor else 0x08)),
            },
            "case": {
                "level": battery_nibble(data[7] & 0x0F),
                "charging": bool(flags & 0x04),
            },
            "bothInCase": bool(status & 0x04),
            # The lid bit only means something while the broadcasting pod is in the case.
            "lidOpen": not (data[8] >> 3) & 0x01 if this_in_case else None,
            "payload": bytes(data[-16:]) if len(data) >= 27 else None,
        }
    )
    return message


def apply_precise_battery(message, enc_key):
    """Exact levels from the encrypted part of the advertisement."""
    if not enc_key or not message.get("payload"):
        return
    clear = aes_ecb(enc_key, message["payload"], decrypt=True)
    left_index, right_index = (1, 2) if message["primaryLeft"] else (2, 1)
    for part, index in (("left", left_index), ("right", right_index), ("case", 3)):
        raw = clear[index]
        level = raw & 0x7F
        if raw != 0xFF and level <= 100:
            message[part]["level"] = level
            message[part]["charging"] = bool(raw & 0x80)


# --- AAP session ----------------------------------------------------------------


class AapSession:
    """L2CAP connection to connected AirPods."""

    def __init__(self, daemon, address):
        self.daemon = daemon
        self.address = address
        self.sock = None
        self.watch = None
        self.ready = False
        self.attempts = 0
        self.primary = "left"
        self.ear = None
        self.closed = False
        GLib.timeout_add(1200, self.open)

    def open(self):
        if self.closed:
            return False
        self.attempts += 1
        try:
            self.sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_SEQPACKET, socket.BTPROTO_L2CAP)
            self.sock.setblocking(False)
            result = self.sock.connect_ex((self.address, AAP_PSM))
        except OSError as error:
            log("aap socket", self.address, error)
            return self.retry()
        if result not in (0, errno.EINPROGRESS, errno.EAGAIN):
            log("aap connect", self.address, os.strerror(result))
            return self.retry()
        self.watch = GLib.io_add_watch(self.sock.fileno(), GLib.IO_OUT | GLib.IO_ERR | GLib.IO_HUP, self.on_connected)
        return False

    def retry(self):
        self.drop_socket()
        if self.attempts < 4 and not self.closed:
            GLib.timeout_add(2000, self.open)
        return False

    def on_connected(self, _fd, condition):
        error = self.sock.getsockopt(socket.SOL_SOCKET, socket.SO_ERROR)
        if error or condition & (GLib.IO_ERR | GLib.IO_HUP):
            log("aap connect", self.address, os.strerror(error) if error else "hang up")
            self.watch = None
            self.retry()
            return False
        self.watch = GLib.io_add_watch(self.sock.fileno(), GLib.IO_IN | GLib.IO_ERR | GLib.IO_HUP, self.on_readable)
        self.send(AAP_HANDSHAKE)
        # Not every model acknowledges the features packet.
        GLib.timeout_add(1500, self.request_notifications)
        return False

    def send(self, packet):
        try:
            self.sock.send(packet)
        except OSError as error:
            log("aap send", self.address, error)

    def request_notifications(self):
        if self.ready or self.closed or self.sock is None:
            return False
        self.ready = True
        self.send(AAP_REQUEST_NOTIFICATIONS)
        if not self.daemon.keys.get(self.address, {}).get("irk"):
            self.send(AAP_REQUEST_KEYS)
        return False

    def on_readable(self, _fd, condition):
        try:
            packet = self.sock.recv(1024)
        except BlockingIOError:
            return True
        except OSError:
            packet = b""
        if not packet or condition & (GLib.IO_ERR | GLib.IO_HUP):
            self.watch = None
            self.close()
            return False
        self.handle(packet)
        return True

    def handle(self, packet):
        if packet.startswith(AAP_HANDSHAKE_ACK):
            self.send(AAP_SET_FEATURES)
        elif packet.startswith(AAP_FEATURES_ACK):
            self.request_notifications()
        elif packet.startswith(AAP_BATTERY) and len(packet) > 6:
            self.handle_battery(packet)
        elif packet.startswith(AAP_EAR) and len(packet) >= 8:
            self.handle_ear(packet[6], packet[7])
        elif packet.startswith(AAP_KEYS):
            self.handle_keys(packet)
        elif packet.startswith(AAP_CONTROL) and len(packet) >= 8:
            self.handle_control(packet[6], packet[7])

    def handle_battery(self, packet):
        device = self.daemon.devices.get(self.address)
        if device is None:
            return
        count = packet[6]
        pods = []
        for index in range(count):
            offset = 7 + index * 5
            if offset + 4 > len(packet):
                break
            part = COMPONENTS.get(packet[offset])
            level, status = packet[offset + 2], packet[offset + 3]
            if part is None:
                continue
            if part in ("left", "right", "headset"):
                pods.append(part)
            # 0x04: that part is not connected (e.g. the case while both pods are out).
            if status == 0x04:
                device[part]["level"] = None
                device[part]["charging"] = False
            else:
                device[part]["level"] = min(level, 100)
                device[part]["charging"] = status == 0x01
        # The primary pod comes first, the ear detection packet uses that order.
        if pods and pods[0] in ("left", "right"):
            self.primary = pods[0]
        device["precise"] = True
        self.daemon.changed()

    def handle_ear(self, primary, secondary):
        device = self.daemon.devices.get(self.address)
        if device is None:
            return
        secondary_side = "right" if self.primary == "left" else "left"
        device[self.primary]["inEar"] = primary == IN_EAR
        device[secondary_side]["inEar"] = secondary == IN_EAR
        in_ear = (primary == IN_EAR) + (secondary == IN_EAR)
        previous, self.ear = self.ear, in_ear
        if previous is not None:
            self.daemon.ear_changed(self.address, previous, in_ear)
        self.daemon.changed()

    def handle_control(self, identifier, value):
        device = self.daemon.devices.get(self.address)
        if device is None or identifier not in CONTROLS:
            return
        name, kind = CONTROLS[identifier]
        device["controls"][name] = value == 0x01 if kind == "switch" else value
        self.daemon.changed()

    def set_control(self, name, value):
        identifier = CONTROL_IDS[name]
        kind = CONTROLS[identifier][1]
        byte = (0x01 if value else 0x02) if kind == "switch" else max(0, min(100, int(value)))
        if self.sock is None or not self.ready:
            return
        self.send(AAP_CONTROL + bytes([identifier, byte, 0, 0, 0]))

    def handle_keys(self, packet):
        keys = {}
        index = len(AAP_KEYS)
        while index + 4 <= len(packet):
            kind = packet[index]
            length = packet[index + 1] << 8 | packet[index + 2]
            value = packet[index + 4 : index + 4 + length]
            if len(value) != length:
                break
            if kind == 0x01:
                keys["irk"] = value.hex()
            elif kind == 0x04:
                keys["enc"] = value.hex()
            index += 4 + length
        if keys.get("irk"):
            self.daemon.store_keys(self.address, keys)

    def drop_socket(self):
        if self.watch is not None:
            GLib.source_remove(self.watch)
            self.watch = None
        if self.sock is not None:
            self.sock.close()
            self.sock = None

    def close(self):
        self.closed = True
        self.drop_socket()


# --- Pairing agent ----------------------------------------------------------------


class Agent(dbus.service.Object):
    """Accepts the "just works" confirmation of the AirPods we pair, nothing else."""

    def __init__(self, bus, daemon):
        super().__init__(bus, AGENT_PATH)
        self.daemon = daemon

    def allowed(self, device):
        return device == self.daemon.pairing_target

    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Release(self):
        pass

    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Cancel(self):
        pass

    @dbus.service.method("org.bluez.Agent1", in_signature="ou", out_signature="")
    def RequestConfirmation(self, device, _passkey):
        if not self.allowed(device):
            raise dbus.DBusException("Rejected", name="org.bluez.Error.Rejected")

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="")
    def RequestAuthorization(self, device):
        if not self.allowed(device):
            raise dbus.DBusException("Rejected", name="org.bluez.Error.Rejected")

    @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="")
    def AuthorizeService(self, device, _uuid):
        if not self.allowed(device):
            raise dbus.DBusException("Rejected", name="org.bluez.Error.Rejected")


# --- Daemon -----------------------------------------------------------------------


class Daemon:
    def __init__(self):
        dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
        self.bus = dbus.SystemBus()
        self.manager = dbus.Interface(self.bus.get_object(BLUEZ, "/"), "org.freedesktop.DBus.ObjectManager")
        self.adapter_path = None
        self.adapter_powered = False
        self.scanning = False
        self.pairing_scan_until = 0
        # Device1 properties by object path, kept up to date from the signals.
        self.props = {}
        self.stdin_buffer = b""
        self.keys = self.load_keys()
        # Paired AirPods by BR/EDR address, as sent to the shell.
        self.devices = {}
        self.paths = {}
        self.sessions = {}
        # Per BR/EDR address: last advertisement time, lid state, ear state.
        self.seen = {}
        self.popups = {}
        self.connect_attempts = {}
        # Last connection we asked for, by address.
        self.requested = {}
        self.resolved = {}
        self.pairing = None
        self.pairing_target = None
        self.pairing_model = None
        self.pairing_ignored = {}
        self.paused_by_us = False
        self.emit_pending = False
        self.last_state = ""
        self.downloads = set()

        self.agent = Agent(self.bus, self)
        self.agent_registered = False
        self.bus.add_signal_receiver(self.on_interfaces_added, "InterfacesAdded", "org.freedesktop.DBus.ObjectManager", BLUEZ)
        self.bus.add_signal_receiver(self.on_interfaces_removed, "InterfacesRemoved", "org.freedesktop.DBus.ObjectManager", BLUEZ)
        self.bus.add_signal_receiver(self.on_properties_changed, "PropertiesChanged", PROPERTIES, BLUEZ, path_keyword="path")
        try:
            self.bus.add_signal_receiver(self.on_bluez_owner, "NameOwnerChanged", "org.freedesktop.DBus", arg0=BLUEZ)
        except dbus.DBusException:
            pass
        GLib.io_add_watch(sys.stdin.fileno(), GLib.IO_IN | GLib.IO_HUP, self.on_stdin)
        GLib.timeout_add_seconds(2, self.tick)
        self.reload()

    # Persistence of the proximity keys, by BR/EDR address.

    def load_keys(self):
        try:
            with open(KEYS_FILE) as file:
                stored = json.load(file)
            return {address: {kind: bytes.fromhex(value) for kind, value in keys.items()} for address, keys in stored.items()}
        except (OSError, ValueError):
            return {}

    def store_keys(self, address, keys):
        self.keys[address] = {kind: bytes.fromhex(value) for kind, value in keys.items()}
        os.makedirs(state_dir(), exist_ok=True)
        stored = {addr: {kind: value.hex() for kind, value in entry.items()} for addr, entry in self.keys.items()}
        temporary = KEYS_FILE + ".tmp"
        with open(os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), "w") as file:
            json.dump(stored, file)
        os.replace(temporary, KEYS_FILE)
        log("stored the proximity keys of", address)

    # BlueZ objects.

    def reload(self):
        self.adapter_path = None
        try:
            objects = self.manager.GetManagedObjects()
        except dbus.DBusException as error:
            log("bluez unavailable:", error.get_dbus_message())
            return
        self.props = {}
        for path, interfaces in objects.items():
            if ADAPTER in interfaces and self.adapter_path is None:
                self.adapter_path = str(path)
                self.adapter_powered = bool(interfaces[ADAPTER].get("Powered", False))
            if DEVICE in interfaces:
                self.props[str(path)] = dict(interfaces[DEVICE])
                self.on_device(str(path), self.props[str(path)])
        self.register_agent()
        self.update_scanning()
        self.changed()

    def register_agent(self):
        try:
            agent_manager = dbus.Interface(self.bus.get_object(BLUEZ, "/org/bluez"), "org.bluez.AgentManager1")
            agent_manager.RegisterAgent(AGENT_PATH, "NoInputNoOutput")
        except dbus.DBusException as error:
            if "AlreadyExists" not in error.get_dbus_name():
                log("agent:", error.get_dbus_message())

    def on_bluez_owner(self, _name, _old, new):
        self.scanning = False
        if new:
            GLib.timeout_add(1000, lambda: self.reload() and False)

    def on_interfaces_added(self, path, interfaces):
        if ADAPTER in interfaces and self.adapter_path is None:
            self.reload()
        if DEVICE in interfaces:
            self.props[str(path)] = dict(interfaces[DEVICE])
            self.on_device(str(path), self.props[str(path)])

    def on_interfaces_removed(self, path, interfaces):
        path = str(path)
        if ADAPTER in interfaces and path == self.adapter_path:
            self.adapter_path = None
            self.scanning = False
        if DEVICE in interfaces:
            self.props.pop(path, None)
            self.resolved.pop(path, None)
            if self.pairing and self.pairing["path"] == path:
                self.pairing = None
                self.changed()
            for address, known in list(self.paths.items()):
                if known == path:
                    self.forget(address)

    def on_properties_changed(self, interface, changed, _invalidated, path=None):
        if interface == ADAPTER and path == self.adapter_path:
            if "Powered" in changed:
                self.adapter_powered = bool(changed["Powered"])
                self.scanning = False
                self.update_scanning()
            if "Discovering" in changed and not changed["Discovering"]:
                self.scanning = False
                GLib.timeout_add(1500, lambda: self.update_scanning() and False)
        elif interface == DEVICE and str(path) in self.props:
            props = self.props[str(path)]
            props.update(changed)
            self.on_device(str(path), props, changed)

    def is_airpods(self, props):
        # Apple's vendor id also covers Beats: the product id tells AirPods apart.
        match = re.search(r"v004cp([0-9a-f]{4})", str(props.get("Modalias", "")).lower())
        if match:
            return int(match.group(1), 16) in MODELS
        return bool(NAME_PATTERN.search(str(props.get("Name", props.get("Alias", "")))))

    def on_device(self, path, props, changed=None):
        address = str(props.get("Address", ""))
        manufacturer = props.get("ManufacturerData", {})
        if APPLE in manufacturer and (changed is None or "ManufacturerData" in changed or "RSSI" in changed):
            self.on_advertisement(path, address, bytes(manufacturer[APPLE]), int(props.get("RSSI", -127)))
        if props.get("Paired", False) and self.is_airpods(props):
            self.track(path, address, props, changed)
        elif self.pairing_target is None:
            self.check_pairing_candidate(path, address, props)

    # Paired AirPods.

    def track(self, path, address, props, changed):
        modalias = str(props.get("Modalias", ""))
        match = re.search(r"p([0-9a-fA-F]{4})", modalias)
        model_id = int(match.group(1), 16) if match else None
        name = str(props.get("Alias", props.get("Name", "AirPods")))
        model, kind = model_info(model_id, str(props.get("Name", "")))
        connected = bool(props.get("Connected", False))
        device = self.devices.get(address)
        if device is None:
            device = self.devices[address] = {
                "address": address,
                "left": {"level": None, "charging": False, "inEar": False},
                "right": {"level": None, "charging": False, "inEar": False},
                "case": {"level": None, "charging": False},
                "headset": {"level": None, "charging": False},
                "connected": False,
                "nearby": False,
                "lidOpen": False,
                "precise": False,
                # The CONTROLS the AirPods reported, by name, while connected.
                "controls": {},
            }
        was_connected = device["connected"]
        device.update({"name": name, "model": model, "modelId": model_id, "kind": kind, "connected": connected})
        self.paths[address] = path
        if connected and address not in self.sessions:
            self.sessions[address] = AapSession(self, address)
        elif not connected and address in self.sessions:
            self.sessions.pop(address).close()
            device["precise"] = False
            device["controls"] = {}
            for part in ("left", "right"):
                device[part]["inEar"] = False
        if changed is not None and "Connected" in changed and connected and not was_connected:
            self.on_connected(address)
        if changed is not None and "Connected" in changed:
            self.update_scanning()
        self.changed()

    def on_connected(self, address):
        now = time.monotonic()
        seen = self.seen.get(address, {})
        # The AirPods connect to the last device on their own as their case opens:
        # they wait in the case (or in a hand) until an ear asks for them.
        own = now - self.requested.get(address, 0) > 30 and now - seen.get("lidTime", 0) < LID_CONNECT_WINDOW
        if not own:
            self.popup(address, "connected")
            return
        GLib.timeout_add(3000, self.check_own_connection, address)

    def check_own_connection(self, address):
        device = self.devices.get(address)
        if device is None or not device["connected"]:
            return False
        session = self.sessions.get(address)
        if session is not None and session.ear is not None:
            in_ear = session.ear > 0
        else:
            in_ear = self.seen.get(address, {}).get("inEar", False)
        if in_ear:
            self.popup(address, "connected")
            return False
        log("connected on their own out of the ears, disconnecting", address)
        # The next time a pod goes in an ear connects them right away.
        if address in self.seen:
            self.seen[address]["inEar"] = False
        self.connect_attempts.pop(address, None)
        self.disconnect(address)
        return False

    def forget(self, address):
        self.devices.pop(address, None)
        self.paths.pop(address, None)
        if address in self.sessions:
            self.sessions.pop(address).close()
        self.changed()

    def popup(self, address, reason):
        now = time.monotonic()
        if now - self.popups.get((address, reason), 0) < POPUP_COOLDOWN:
            return
        self.popups[(address, reason)] = now
        self.last_state = ""
        self.flush()
        emit({"event": "popup", "address": address, "reason": reason})

    # Advertisements.

    def owner_of(self, path, address, message, rssi):
        """BR/EDR address of the paired AirPods that sent this advertisement."""
        if path in self.resolved:
            return self.resolved[path]
        for owner, keys in self.keys.items():
            if owner in self.devices and keys.get("irk") and resolves(keys["irk"], address):
                self.resolved[path] = owner
                return owner
        # Without keys (before the first connection), the closest AirPods of a
        # model we know of, when there is only one of that model.
        if rssi < NEAR_RSSI:
            return None
        candidates = [
            known
            for known, device in self.devices.items()
            if device.get("modelId") == message["model"] and not self.keys.get(known, {}).get("irk")
        ]
        return candidates[0] if len(candidates) == 1 else None

    def on_advertisement(self, path, address, data, rssi):
        message = parse_proximity(data)
        if message is None:
            return
        if message["pairingMode"]:
            self.on_pairing_advertisement(message, rssi)
            return
        owner = self.owner_of(path, address, message, rssi)
        if owner is None:
            return
        device = self.devices[owner]
        apply_precise_battery(message, self.keys.get(owner, {}).get("enc"))
        now = time.monotonic()
        seen = self.seen.setdefault(owner, {"time": 0, "lid": False, "inEar": False})
        returning = now - seen["time"] > NEARBY_TIMEOUT
        seen["time"] = now
        device["nearby"] = True

        # The AAP session knows better while connected.
        if not device["precise"] or not device["connected"]:
            if device["kind"] == "headphones":
                side = message["left"] if message["left"]["level"] is not None else message["right"]
                device["headset"] = {"level": side["level"], "charging": side["charging"]}
            else:
                for part in ("left", "right", "case"):
                    device[part].update(message[part])

        lid = message["lidOpen"]
        if lid is not None:
            if lid and (not seen["lid"] or returning):
                seen["lidTime"] = now
                self.popup(owner, "lid")
            elif not lid and seen["lid"]:
                emit({"event": "lidClosed", "address": owner})
            lid_changed = lid != seen["lid"]
            seen["lid"] = lid
            device["lidOpen"] = lid
            if lid_changed:
                self.update_scanning()

        in_ear = message["left"]["inEar"] or message["right"]["inEar"]
        if in_ear and not seen["inEar"] and not device["connected"]:
            self.auto_connect(owner, message["connection"])
        seen["inEar"] = in_ear
        self.changed()

    def auto_connect(self, address, connection):
        # Leaves them to the phone while it plays or calls through them.
        if connection in BUSY_STATES:
            return
        now = time.monotonic()
        if now - self.connect_attempts.get(address, 0) < AUTO_CONNECT_COOLDOWN:
            return
        self.connect_attempts[address] = now
        log("in ear, connecting", address)
        self.connect(address)

    def tick(self):
        now = time.monotonic()
        dirty = False
        for address, seen in self.seen.items():
            device = self.devices.get(address)
            if device is None:
                continue
            if device["nearby"] and now - seen["time"] > NEARBY_TIMEOUT:
                device["nearby"] = False
                dirty = True
            if seen["lid"] and now - seen["time"] > LID_TIMEOUT:
                seen["lid"] = False
                device["lidOpen"] = False
                emit({"event": "lidClosed", "address": address})
                self.update_scanning()
                dirty = True
        if self.pairing_scan_until and now > self.pairing_scan_until and self.pairing_target is None:
            self.pairing_scan_until = 0
            self.pairing = None
            self.update_scanning()
            dirty = True
        if dirty:
            self.changed()
        return True

    # Discovery: LE advertisements all the time (unless our AirPods are
    # connected with their case shut, AAP then says it all), BR/EDR inquiry too
    # while AirPods in pairing mode are near, to find the address to pair with.

    def update_scanning(self):
        if self.adapter_path is None or not self.adapter_powered:
            self.scanning = False
            return
        pairing = self.pairing_scan_until > time.monotonic()
        # An open case still has a lid to watch, connected or not.
        busy = any(device["connected"] for device in self.devices.values()) and not any(
            device["lidOpen"] for device in self.devices.values()
        )
        wanted = pairing or not busy
        adapter = dbus.Interface(self.bus.get_object(BLUEZ, self.adapter_path), ADAPTER)
        try:
            if wanted:
                adapter.SetDiscoveryFilter({"Transport": "auto" if pairing else "le", "DuplicateData": True})
                if not self.scanning:
                    adapter.StartDiscovery()
            elif self.scanning:
                adapter.StopDiscovery()
            self.scanning = wanted
        except dbus.DBusException as error:
            if "InProgress" in error.get_dbus_name():
                self.scanning = wanted
            else:
                log("discovery:", error.get_dbus_message())

    # Pairing new AirPods.

    def on_pairing_advertisement(self, message, rssi):
        if rssi < NEAR_RSSI or self.pairing_target is not None or message["model"] not in MODELS:
            return
        self.pairing_model = message["model"]
        if not self.pairing_scan_until:
            log("AirPods in pairing mode nearby, looking for them")
        starting = not self.pairing_scan_until
        self.pairing_scan_until = time.monotonic() + PAIRING_SCAN_SECONDS
        if starting:
            self.update_scanning()
            for path, props in list(self.props.items()):
                self.check_pairing_candidate(path, str(props.get("Address", "")), props)

    def check_pairing_candidate(self, path, address, props):
        if not self.pairing_scan_until or props.get("Paired", False):
            return
        # A BR/EDR inquiry result: it has a class of device, audio/video major class.
        device_class = int(props.get("Class", 0))
        if (device_class >> 8) & 0x1F != 0x04:
            return
        name = str(props.get("Name", ""))
        if not self.is_airpods(props):
            return
        if time.monotonic() < self.pairing_ignored.get(address, 0):
            return
        if self.pairing is not None and self.pairing["address"] == address:
            return
        model, kind = model_info(self.pairing_model, name)
        self.pairing = {
            "address": address,
            "path": path,
            "name": name or model,
            "model": model,
            "modelId": self.pairing_model,
            "kind": kind,
            "state": "ready",
        }
        self.changed()
        self.popup(address, "pairing")

    def pair(self, address):
        if self.pairing is None or self.pairing["address"] != address:
            return
        path = self.pairing["path"]
        self.pairing_target = path
        self.pairing["state"] = "pairing"
        self.changed()
        device = dbus.Interface(self.bus.get_object(BLUEZ, path), DEVICE)

        def done():
            self.pairing_target = None
            self.pairing = None
            self.pairing_scan_until = 0
            self.bus.get_object(BLUEZ, path).Set(DEVICE, "Trusted", True, dbus_interface=PROPERTIES)
            self.connect(address, path)
            self.update_scanning()
            self.changed()

        def failed(error):
            log("pairing failed:", error.get_dbus_message())
            self.pairing_target = None
            if self.pairing is not None:
                self.pairing["state"] = "failed"
            self.changed()

        device.Pair(reply_handler=done, error_handler=failed, timeout=60)

    # Connections.

    def connect(self, address, path=None):
        path = path or self.paths.get(address)
        if path is None:
            return
        self.requested[address] = time.monotonic()
        proxy = self.bus.get_object(BLUEZ, path)
        try:
            proxy.Set(DEVICE, "Trusted", True, dbus_interface=PROPERTIES)
        except dbus.DBusException:
            pass
        proxy.Connect(
            dbus_interface=DEVICE,
            reply_handler=lambda: None,
            error_handler=lambda error: log("connect", address, error.get_dbus_message()),
            timeout=30,
        )

    def disconnect(self, address):
        path = self.paths.get(address)
        if path is not None:
            self.bus.get_object(BLUEZ, path).Disconnect(
                dbus_interface=DEVICE,
                reply_handler=lambda: None,
                error_handler=lambda error: log("disconnect", address, error.get_dbus_message()),
            )

    # Automatic pause when a pod leaves an ear, and resume when it is back.

    def ear_changed(self, address, previous, current):
        device = self.devices.get(address)
        if device is None or device["kind"] != "buds":
            return
        if current < previous:
            if self.player_status() == "Playing":
                subprocess.run(["playerctl", "pause"], check=False)
                self.paused_by_us = True
        elif current > previous and self.paused_by_us and current >= 1:
            self.paused_by_us = False
            subprocess.run(["playerctl", "play"], check=False)

    @staticmethod
    def player_status():
        try:
            return subprocess.run(["playerctl", "status"], capture_output=True, text=True, timeout=2).stdout.strip()
        except (OSError, subprocess.TimeoutExpired):
            return ""

    # Shell side.

    def on_stdin(self, fd, _condition):
        chunk = os.read(fd, 4096)
        if not chunk:
            # The shell went away.
            loop.quit()
            return False
        self.stdin_buffer += chunk
        *lines, self.stdin_buffer = self.stdin_buffer.split(b"\n")
        for line in lines:
            self.run_command(line.decode(errors="replace"))
        return True

    def run_command(self, line):
        command, _, rest = line.strip().partition(" ")
        address, _, argument = rest.strip().partition(" ")
        address = address.upper()
        if command == "control":
            self.control(address, argument)
        elif command == "connect":
            self.connect(address)
        elif command == "disconnect":
            self.disconnect(address)
        elif command == "pair":
            self.pair(address)
        elif command == "ignore":
            self.pairing_ignored[address] = time.monotonic() + PAIRING_IGNORE_SECONDS
            if self.pairing is not None and self.pairing["address"] == address:
                self.pairing = None
                self.changed()

    def control(self, address, argument):
        name, _, value = argument.partition(" ")
        session = self.sessions.get(address)
        if session is None or name not in CONTROL_IDS:
            return
        try:
            value = int(value)
        except ValueError:
            return
        session.set_control(name, value)

    def changed(self):
        if not self.emit_pending:
            self.emit_pending = True
            GLib.timeout_add(150, self.flush)

    def images(self, model_id):
        """Paths of the pods and case renders of a model, None until downloaded."""
        name = IMAGE_NAMES.get(model_id)
        if name is None:
            return None
        paths = {part: os.path.join(IMAGES_DIR, f"{name}_{part}.png") for part in ("buds", "case")}
        if all(os.path.exists(path) for path in paths.values()):
            return paths
        if name not in self.downloads:
            self.downloads.add(name)
            threading.Thread(target=self.download, args=(name, paths), daemon=True).start()
        return None

    def download(self, name, paths):
        try:
            os.makedirs(IMAGES_DIR, exist_ok=True)
            for part, path in paths.items():
                with urllib.request.urlopen(IMAGE_URL.format(f"{name}_{part}"), timeout=20) as response:
                    data = response.read()
                with open(path + ".tmp", "wb") as file:
                    file.write(data)
                os.replace(path + ".tmp", path)
        except OSError as error:
            log("image download", name, error)
            # Tried again on a later state change.
            GLib.timeout_add_seconds(60, lambda: self.downloads.discard(name) and False)
            return
        GLib.idle_add(lambda: self.changed() and False)

    def flush(self):
        self.emit_pending = False
        pairing = None
        if self.pairing is not None:
            pairing = {key: value for key, value in self.pairing.items() if key != "path"}
            pairing["images"] = self.images(pairing["modelId"])
        for device in self.devices.values():
            device["images"] = self.images(device["modelId"])
        state = {"event": "state", "devices": list(self.devices.values()), "pairing": pairing}
        # Every advertisement lands here, most of them change nothing.
        serialized = json.dumps(state, sort_keys=True)
        if serialized != self.last_state:
            self.last_state = serialized
            emit(state)
        return False


if __name__ == "__main__":
    loop = GLib.MainLoop()
    daemon = Daemon()
    try:
        loop.run()
    except KeyboardInterrupt:
        pass
