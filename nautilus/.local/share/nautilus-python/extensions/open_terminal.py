# Nautilus's "Open Terminal Here", in the right-click menu of a folder or of the
# folder's background. nautilus-python loads it from
# ~/.local/share/nautilus-python/extensions when Nautilus starts.
import os
import subprocess

from gi.repository import GObject, Nautilus


class OpenTerminal(GObject.GObject, Nautilus.MenuProvider):
    def _item(self, name, folder):
        item = Nautilus.MenuItem(name=name, label="Open Terminal Here")
        item.connect("activate", lambda _item: self._open(folder))
        return item

    # Your terminal (hyprpunk.programs), which Hyprland hands every app as $TERMINAL.
    # Its own session, so closing Nautilus leaves it open.
    def _open(self, folder):
        subprocess.Popen(
            [os.environ.get("TERMINAL", "kitty")],
            cwd=folder.get_location().get_path(),
            start_new_session=True,
        )

    # Only folders with a path: a terminal can't stand in the trash or Recent
    def _local(self, folder):
        return folder.is_directory() and folder.get_location().get_path() is not None

    def get_file_items(self, files):
        if len(files) == 1 and self._local(files[0]):
            return [self._item("HyprPunk::OpenTerminalHere", files[0])]
        return []

    def get_background_items(self, folder):
        if self._local(folder):
            return [self._item("HyprPunk::OpenTerminalHereBackground", folder)]
        return []
