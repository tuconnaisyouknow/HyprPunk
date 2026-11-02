#!/usr/bin/env python3
"""File chooser portal of the HyprPunk shell, started by quickshell.

Answers xdg-desktop-portal's org.freedesktop.impl.portal.FileChooser (OpenFile,
SaveFile, SaveFiles), so the apps going through the portal get the shell's own
file picker. xdg-desktop-portal picks it through hyprland-portals.conf.

Writes one JSON object per line on stdout, one dialog at a time:
    {"event": "open", "id": "...", "mode": "open" | "save" | "saveFiles",
     "title", "acceptLabel", "app", "multiple", "directory", "folder", "name",
     "files": [names to save], "filters": [{"name", "globs"}], "filter": index}
    {"event": "close", "id": "..."}   (the app gave up on its dialog)
and reads one answer per line on stdin:
    {"id": "...", "paths": [...], "filter": index}   (no paths: cancelled)
"""

import json
import os
import sys
import urllib.parse
from collections import deque

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

BUS_NAME = "org.freedesktop.impl.portal.desktop.hyprpunk"
OBJECT_PATH = "/org/freedesktop/portal/desktop"
FILE_CHOOSER = "org.freedesktop.impl.portal.FileChooser"
REQUEST = "org.freedesktop.impl.portal.Request"
PROPERTIES = "org.freedesktop.DBus.Properties"
# What the portal's Response codes mean.
SUCCESS, CANCELLED, ENDED = 0, 1, 2


def load_mime_globs():
    """Mime type → its globs, from shared-mime-info, since the shell's file list
    only knows globs."""
    globs = {}
    dirs = [os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))]
    dirs += os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
    for directory in dirs:
        try:
            with open(os.path.join(directory, "mime", "globs2"), encoding="utf-8") as file:
                for line in file:
                    if line.startswith("#"):
                        continue
                    fields = line.rstrip("\n").split(":")
                    if len(fields) >= 3:
                        globs.setdefault(fields[1], []).append(fields[2])
        except OSError:
            pass
    return globs


MIME_GLOBS = load_mime_globs()


def filter_globs(rules):
    """The globs of one portal filter, whose rules are globs (0) or mime types (1).
    A mime wildcard like image/* takes every image type's globs."""
    globs = []
    for kind, pattern in rules:
        if kind == 0:
            globs.append(str(pattern))
        elif pattern.endswith("/*"):
            prefix = pattern[:-1]
            for mime, patterns in MIME_GLOBS.items():
                if mime.startswith(prefix):
                    globs += patterns
        else:
            globs += MIME_GLOBS.get(str(pattern), [])
    return sorted(set(globs))


def decode_path(value):
    """The portal sends paths as null-terminated bytes."""
    if value is None:
        return ""
    return bytes(value).rstrip(b"\0").decode("utf-8", "replace")


def to_uri(path):
    return "file://" + urllib.parse.quote(path)


def send(message):
    print(json.dumps(message), flush=True)


class Request(dbus.service.Object):
    """The handle the app can close its dialog with."""

    def __init__(self, portal, handle, dialog_id):
        super().__init__(portal.bus, handle)
        self.portal = portal
        self.dialog_id = dialog_id

    @dbus.service.method(REQUEST, in_signature="", out_signature="")
    def Close(self):
        self.portal.finish(self.dialog_id, ENDED, {})


class Portal(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(bus, OBJECT_PATH)
        self.bus = bus
        self.next_id = 0
        # Dialogs waiting their turn, and the one on screen.
        self.queue = deque()
        self.shown = None
        self.dialogs = {}

    @dbus.service.method(PROPERTIES, in_signature="ss", out_signature="v")
    def Get(self, interface, name):
        if interface == FILE_CHOOSER and name == "version":
            return dbus.UInt32(4)
        raise dbus.exceptions.DBusException("No such property " + name, name="org.freedesktop.DBus.Error.InvalidArgs")

    @dbus.service.method(PROPERTIES, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        return {"version": dbus.UInt32(4)} if interface == FILE_CHOOSER else {}

    @dbus.service.method(FILE_CHOOSER, in_signature="osssa{sv}", out_signature="ua{sv}", async_callbacks=("reply", "error"))
    def OpenFile(self, handle, app_id, parent_window, title, options, reply, error):
        self.add("open", handle, app_id, title, options, reply)

    @dbus.service.method(FILE_CHOOSER, in_signature="osssa{sv}", out_signature="ua{sv}", async_callbacks=("reply", "error"))
    def SaveFile(self, handle, app_id, parent_window, title, options, reply, error):
        self.add("save", handle, app_id, title, options, reply)

    @dbus.service.method(FILE_CHOOSER, in_signature="osssa{sv}", out_signature="ua{sv}", async_callbacks=("reply", "error"))
    def SaveFiles(self, handle, app_id, parent_window, title, options, reply, error):
        self.add("saveFiles", handle, app_id, title, options, reply)

    def add(self, mode, handle, app_id, title, options, reply):
        self.next_id += 1
        dialog_id = str(self.next_id)
        filters = list(options.get("filters", []))
        current = options.get("current_filter")
        folder = decode_path(options.get("current_folder"))
        name = str(options.get("current_name", ""))
        # Saving over a file the app already knows: start next to it, with its name.
        current_file = decode_path(options.get("current_file"))
        if current_file:
            folder, name = os.path.split(current_file)
        message = {
            "event": "open",
            "id": dialog_id,
            "mode": mode,
            "title": str(title),
            "acceptLabel": str(options.get("accept_label", "")).replace("_", ""),
            "app": str(app_id),
            "multiple": bool(options.get("multiple", False)),
            "directory": bool(options.get("directory", False)) or mode == "saveFiles",
            "folder": folder if os.path.isdir(folder) else os.path.expanduser("~"),
            "name": name,
            "files": [os.path.basename(decode_path(file)) for file in options.get("files", [])],
            "filters": [{"name": str(item[0]), "globs": filter_globs(item[1])} for item in filters],
            "filter": next((index for index, item in enumerate(filters) if current is not None and item[0] == current[0]), 0),
        }
        self.dialogs[dialog_id] = {
            "message": message,
            "reply": reply,
            "filters": filters,
            "request": Request(self, handle, dialog_id),
        }
        self.queue.append(dialog_id)
        self.show_next()

    def show_next(self):
        if self.shown is None and self.queue:
            self.shown = self.queue.popleft()
            send(self.dialogs[self.shown]["message"])

    def finish(self, dialog_id, response, results):
        dialog = self.dialogs.pop(dialog_id, None)
        if dialog is None:
            return
        if dialog_id in self.queue:
            self.queue.remove(dialog_id)
        dialog["request"].remove_from_connection()
        dialog["reply"](dbus.UInt32(response), dbus.Dictionary(results, signature="sv"))
        if self.shown == dialog_id:
            if response == ENDED:
                send({"event": "close", "id": dialog_id})
            self.shown = None
            self.show_next()

    def answer(self, line):
        try:
            message = json.loads(line)
        except ValueError:
            return
        dialog_id = str(message.get("id", ""))
        dialog = self.dialogs.get(dialog_id)
        if dialog is None:
            return
        paths = message.get("paths") or []
        if not paths:
            self.finish(dialog_id, CANCELLED, {})
            return
        # SaveFiles: the shell picks a folder, the app's names go in it.
        if dialog["message"]["mode"] == "saveFiles":
            paths = [os.path.join(paths[0], name) for name in dialog["message"]["files"]]
        results = {"uris": dbus.Array([to_uri(path) for path in paths], signature="s")}
        filter_index = message.get("filter")
        if isinstance(filter_index, int) and 0 <= filter_index < len(dialog["filters"]):
            results["current_filter"] = dialog["filters"][filter_index]
        self.finish(dialog_id, SUCCESS, results)


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    if bus.request_name(BUS_NAME, dbus.bus.NAME_FLAG_DO_NOT_QUEUE) != dbus.bus.REQUEST_NAME_REPLY_PRIMARY_OWNER:
        print("filechooser-portal: already running", file=sys.stderr)
        sys.exit(1)
    portal = Portal(bus)
    loop = GLib.MainLoop()

    # Leaves with the shell, which closes stdin when it stops.
    def on_stdin(source, condition):
        if condition & GLib.IO_IN:
            line = sys.stdin.readline()
            if line:
                portal.answer(line)
                return True
        loop.quit()
        return False

    GLib.io_add_watch(sys.stdin, GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, on_stdin)
    loop.run()


if __name__ == "__main__":
    main()
