# HyprPunk Quickshell

The HyprPunk desktop shell: the bar with its dynamic island, the control center,
the notifications and the island panels (launcher, clipboard, emoji, keybindings,
wallpaper, SDDM theme, configuration files, monitors, session and main menu).

## Run from the repository

```sh
qs -p "$HOME/.dotfiles/quickshell/.config/quickshell/hyprpunk/shell.qml"
```

## Run after stowing

```sh
stow --dir "$HOME/.dotfiles" --target "$HOME" quickshell
qs -c hyprpunk
```

## Panels

Each panel opens through IPC, which the Hyprland keybindings use:

```sh
qs -c hyprpunk ipc call <panel> toggle   # or open, close
```

| Panel | Keybinding |
|---|---|
| `launcher` | `Alt + Space` |
| `menu` | `Ctrl + Alt + Space` |
| `clipboard` | `Ctrl + ù` |
| `emoji` | `Super + ;` |
| `keybindings` | `Super + Ctrl + K` |
| `wallpaper` | `Super + Ctrl + W` |
| `sddm` | `Super + Ctrl + G` |
| `session` | `Super + Escape` |
| `controlcenter` | `Super + C` |
| `notifications` | `Super + N` |
| `config`, `monitor` | from the main menu |

## AirPods

`~/Scripts/airpodsd.py` (started by the shell) reads the AirPods' Bluetooth LE
advertisements and their accessory protocol, for every AirPods model:

- AirPods in pairing mode next to the computer show a card with a Connect button.
- Opening the case of paired AirPods, or connecting them, shows their batteries.
- Putting them in an ear connects them, unless they are playing or on a call
  with another device. The connection they make on their own when their case
  opens is dropped while no pod is in an ear.
- Taking a pod out of an ear pauses the music, putting it back resumes it.

On the first connection it stores the AirPods' proximity keys in
`~/.local/state/hyprpunk/airpods-keys.json`, which tell their advertisements apart
from other people's AirPods (until then, only very close AirPods of the same model
count). `qs -c hyprpunk ipc call airpods popup` shows the card again.

The card shows Apple's renders of the pods and their case (the iOS ones LibrePods
ships), downloaded to `~/.cache/hyprpunk/airpods` on first use rather than kept
here. AirPods Max have none and get an icon instead.

The emoji list (`data/emojis.tsv`) comes from rofi-emoji 4.1.0 (MIT, Magnus
Bergmark), generated from the Unicode CLDR data.
