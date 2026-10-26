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

The emoji list (`data/emojis.tsv`) comes from rofi-emoji 4.1.0 (MIT, Magnus
Bergmark), generated from the Unicode CLDR data.
