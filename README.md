# 🌆 HyprPunk

> Arch Linux dotfiles for Hyprland, with a cyberpunk visual direction, Catppuccin Mocha colors, and Mauve accents.

HyprPunk is a complete personal Wayland setup built around **Hyprland**.  
It brings together the window manager, the desktop shell, themes, scripts, terminal, shell, and CLI tools in a modular **GNU Stow** based configuration.

The goal is simple: a cohesive, dark, readable, and responsive desktop inspired by cyberpunk visuals without getting in the way of daily work.

---

## 🖼️ Screenshots

![desktop](./assets/screenshots/desktop.png)

### 🧊 Shell

Everything below is drawn by the Quickshell configuration in [`quickshell/`](./quickshell/.config/quickshell/hyprpunk/).

#### 🔒 Lock screen

The screen blurs into the lock, with the date and time over the player and its synced lyrics, and the bar's pills carried over. Typing shows the password prompt, and the island turns into a padlock that opens on the right password.

![lock-animation](./assets/screenshots/lock-animation.webp)

| Locked | Typing the password |
|:-:|:-:|
| ![lock-screen](./assets/screenshots/lock-screen.png) | ![lock-password](./assets/screenshots/lock-password.png) |

#### 🏝️ Dynamic island

The clock's island grows into every panel and shows the volume, brightness, keyboard light, microphone and touchpad changes.

![osd](./assets/screenshots/osd.webp)

| Application Launcher | Main Menu |
|:-:|:-:|
| ![launcher](./assets/screenshots/launcher.png) | ![main-menu](./assets/screenshots/main-menu.png) |
| Clipboard History | Emoji Picker |
| ![clipboard](./assets/screenshots/clipboard.png) | ![emoji-picker](./assets/screenshots/emoji-picker.png) |
| Wallpaper Selector | Session Menu |
| ![wallpaper-selector](./assets/screenshots/wallpaper-selector.png) | ![session-menu](./assets/screenshots/session-menu.png) |

#### 🎛️ Control center and bar

| Control Center | Notifications |
|:-:|:-:|
| ![control-center](./assets/screenshots/control-center.png) | ![notifications](./assets/screenshots/notifications.png) |
| Player and Lyrics | Workspace Preview |
| ![music](./assets/screenshots/music.png) | ![workspace-preview](./assets/screenshots/workspace-preview.png) |

<details>
<summary>More shell screenshots</summary>

| Calendar | Resources |
|:-:|:-:|
| ![calendar](./assets/screenshots/calendar.png) | ![resources](./assets/screenshots/resources.png) |
| Screenshots and Recordings | Monitors |
| ![capture](./assets/screenshots/capture.png) | ![monitors](./assets/screenshots/monitors.png) |
| Keybindings | Configuration Files |
| ![keybindings](./assets/screenshots/keybindings.png) | ![config-files](./assets/screenshots/config-files.png) |
| SDDM Theme Selector | |
| ![sddm-theme-selector](./assets/screenshots/sddm-theme-selector.png) | |

</details>

### 🖥️ Desktop

The applications themed and configured by these dotfiles.

#### 💻 Terminal

**Kitty** with **Zsh**, the **Starship** prompt and **Tmux**, here running **Fastfetch**, **Btop** and **Cava**.

![terminal](./assets/screenshots/terminal.png)

| Neovim | Yazi |
|:-:|:-:|
| ![neovim](./assets/screenshots/neovim.png) | ![yazi](./assets/screenshots/yazi.png) |
| Dolphin (Qt, Kvantum) | Brave and Loupe (GTK) |
| ![dolphin](./assets/screenshots/dolphin.png) | ![brave-loupe](./assets/screenshots/brave-loupe.png) |

<details>
<summary>SDDM login screen</summary>

![sddm](./assets/screenshots/sddm.png)

</details>

---

## 🧰 What Is Included?

- 🪟 **Hyprland** as the main Wayland environment.
- 🧊 **Quickshell** for the bar, the dynamic island panels (launcher, clipboard, emoji, wallpapers, SDDM themes, session), the control center, the notifications, the OSD, the lock screen (with the player and its lyrics), and screenshots (annotated in place) and screen recordings.
- 🔋 A battery charge limit set from the control center, on laptops whose battery driver supports one.
- 🔒 **Hypridle** and **awww** for idle handling (locking, then suspending) and wallpapers with animated transitions.
- 🎬 **SDDM** with cyberpunk video themes.
- 💻 **Kitty**, **Zsh**, **Starship**, **Tmux**, and **Yazi** for the terminal workflow.
- 📝 **Neovim** with a Lua-based configuration.
- 🎨 **GTK 3/4**, **Qt5/Qt6**, and **Kvantum** themed around Catppuccin Mocha.
- 🛠️ **Cliphist**, **Fastfetch**, **Btop**, **Cava**, **Bat**, and utility scripts.
- 🦁 **Brave** managed policy (extensions, Rewards, Wallet, AI Chat) installed system-wide.
- 📦 Modular configuration managed with GNU Stow.

---

## 🎨 Visual Identity

HyprPunk uses **Catppuccin Mocha** as its dark base and **Mauve** as the main accent color.

Core palette:

- 🌑 Base: `#1e1e2e`
- 🌘 Mantle: `#181825`
- 🌌 Crust: `#11111b`
- ✨ Text: `#cdd6f4`
- 💜 Mauve: `#cba6f7`
- 🪻 Lavender: `#b4befe`

The overall look favors soft contrast, mauve borders, dark surfaces, compact menus, and night-city inspired visuals.

The shell's glass comes in two styles: **Classic**, with crisp rims, and **Liquid**, see-through like the lock screen's
minutes with a soft rim. Switch between them live from the control center's Display block, or with
`~/Scripts/glassctl.sh set classic|liquid|toggle`.

---

## ✅ Installation

> [!CAUTION]
> HyprPunk only installs on a **fresh minimal Arch Linux** installation, with nothing else set up yet.
>
> It takes over your user configuration, sets up SDDM and GRUB, installs its packages, and enables its services.
> So it checks first, and stops without changing anything if it finds configs it would take over (like
> `~/.config/hypr` or `~/.dotfiles`), another login screen, or another desktop. Nothing is backed up, apart from
> `/etc/default/grub`, kept as `/etc/default/grub.bak`.

### 📋 Requirements

- A fresh Arch Linux, installed with the minimal profile (for example `archinstall` with no desktop).
- A user account in the `wheel` group with `sudo` working. Run the installer as that user, not as root.
- An internet connection. The dotfiles alone weigh about 500 MB to download, mostly the screenshots, wallpapers and
  login screen videos, and the packages come on top.
- GRUB is optional: its theme is skipped with any other bootloader.

### ▶️ Run it

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/tuconnaisyouknow/HyprPunk/refs/heads/master/install.sh)
```

The script asks for the keyboard layout, interface language, and regional formats first, then your password once.
After that it runs on its own until it offers to reboot, so you can leave it during the long package builds. Left empty, the
answers give a US layout and English for both the interface and the formats (`en_US.UTF-8`). English and French
(`fr_FR.UTF-8`) are both generated during installation, so you can switch later. If the installation stops, run the
same command again and it picks up where it left off.

Reboot after the installation completes.

> [!NOTE]
> Only two keyboard layouts are supported, **QWERTY US** and **AZERTY FR**, and only two languages and regional
> formats, **English (`en_US`)** and **French (`fr_FR`)**. Other layouts and locales aren't handled.

### 📦 What gets installed

HyprPunk installs its own choice of applications, without asking. You can remove any of them afterwards with
`yay -Rns <package>`, and give its shortcut another app from your personal files (see [Customization](#-customization)).

- 🌐 **Brave**, with **uBlock Origin Lite** and the **Catppuccin Mocha** theme installed by its policy, and Rewards,
  Wallet and AI Chat turned off.
- 🎵 **Spotify** (`spotify-launcher`), 📓 **Obsidian** and 💬 **Discord**.
- 📄 **LibreOffice** for documents, **Papers** for PDFs, **Loupe** for images, **mpv** for videos and **Celluloid** for
  music files, set as the default apps for those files.
- 📁 **Dolphin** and **Ark** for files and archives, **Seahorse** for the keyring.
- 📝 **Neovim** and **Lazygit**, with `cargo` and `npm` for the language servers Neovim's Mason downloads on its first
  start, with their linters and formatters: Bash, Python, HTML, CSS, TypeScript and React, Java, Markdown, Docker,
  JSON and Hyprland.

---

## 🚀 First Steps

> [!TIP]
> These are enough to find your way around on the first login. **`Super + Ctrl + K`** lists every other shortcut,
> and clicking one in that list runs it.

| Shortcut | What it does |
|---|---|
| `Super + T` | Open the terminal (Kitty) |
| `Alt + Space` | Open the application launcher |
| `Ctrl + Alt + Space` | Open the main menu |
| `Super + C` | Open the control center (Wi-Fi, Bluetooth, sound, display, battery…) |
| `Super + N` | Open the notification center |
| `Super + Q` | Close the focused window |
| `Super + 1` … `Super + 0` | Switch to a workspace, add `Shift` to send the window there |
| `Super + Escape` | Open the session menu (lock, log out, reboot, shut down) |
| `Super + Ctrl + K` | Show all the keybindings |

`Super` is the Windows key. The arrows follow Vim, `h j k l` on QWERTY and `j k l m` on AZERTY: `Super` with one of
them moves the focus, and adding `Shift` moves the window.

### 🏝️ Shell panels

Every panel of the shell opens with `qs -c hyprpunk ipc call <panel> toggle` (or `open`, `close`), which is also what
you'd bind to your own shortcuts.

| Panel | Shortcut |
|---|---|
| `launcher` | `Alt + Space` |
| `menu` | `Ctrl + Alt + Space` |
| `clipboard` | `Ctrl + '` on QWERTY, `Ctrl + ù` on AZERTY |
| `emoji` | `Super + ;` |
| `keybindings` | `Super + Ctrl + K` |
| `wallpaper` | `Super + Ctrl + W` |
| `sddm` | `Super + Ctrl + G` |
| `session` | `Super + Escape` |
| `controlcenter` | `Super + C` |
| `notifications` | `Super + N` |
| `config`, `monitor`, `screenshot` | From the main menu |

### 📸 Screenshots and recordings

| Capture | Shortcut |
|---|---|
| The active screen | `Print` |
| A region or a window | `Super + Shift + S` |
| A region, annotated in place | `Super + Ctrl + S` |
| Record the active screen, or stop | `Shift + Print` |
| Record a region or a window, or stop | `Super + Shift + R` |

Screenshots are saved in `~/Pictures/Screenshots` and copied to the clipboard. Recordings, with the system's sound,
go to `~/Videos/Recordings`, and stop from the same shortcut or from their timer in the island. Both follow you if you
move your pictures or videos folder in `~/.config/user-dirs.dirs`.

### 🔒 Locking and sleep

The screen locks with `Super + Ctrl + L`, from the session menu, or after 5½ minutes without use. The screen dims
first, at 5 minutes, and the computer goes to sleep after 30 minutes. Before sleeping, the screen locks at once,
without its animation. The lock is held by Hyprland itself, so the screens stay locked even if the shell crashes.

### 🎵 Music player

The bar's spinning record, its player card and the lock screen's player and synced lyrics follow **Spotify only**.
Other players, like a video in the browser or mpv, still work with the media keys but don't show there. This is a
choice, not something you can switch: setting `hyprpunk.programs.music` to another app only changes what
`Super + P` opens.

### 🎧 AirPods

The shell talks to AirPods directly, every model included, once Bluetooth is on (it starts off at each login):

- AirPods in pairing mode near the computer show a card with a Connect button.
- Opening the case of paired AirPods, or connecting them, shows their batteries.
- Putting a pod in your ear connects them, unless they're busy playing or on a call with another device.
- Taking a pod out pauses the music, and putting it back resumes it.

The first connection saves their keys in `~/.local/state/hyprpunk/airpods-keys.json`, which tells your AirPods apart
from other people's nearby.

---

## 📁 Structure

```text
.
├── assets/screenshots/  # Images used by this README
├── bat/                 # Bat configuration and Catppuccin theme
├── battery/             # Battery charge limit script and service installed system-wide
├── brave/               # Brave managed policy installed system-wide
├── btop/                # Btop configuration and theme
├── cava/                # Audio visualizer configuration
├── fastfetch/           # Fastfetch system summary configuration and logo
├── fontconfig/          # JetBrainsMono Nerd Font preference
├── grub/                # CyberEXS GRUB theme installed system-wide
├── gtk3/                # GTK 3 theme settings
├── gtk4/                # GTK 4 theme settings
├── hypridle/            # Idle and suspend behavior
├── hyprland/            # Hyprland Lua config, keybindings, and monitors
├── kdeglobals/          # Minimal KDE integration for icons and Qt6ct
├── keyboard/            # Layout-specific application keymaps and the keymap polkit rule
├── kitty/               # Kitty terminal configuration
├── kvantum/             # Kvantum Catppuccin Mocha Mauve theme
├── nvim/                # Neovim Lua configuration
├── qt5/                 # Source palette for generated Qt5ct configuration
├── qt6/                 # Source palette for generated Qt6ct configuration
├── quickshell/          # Quickshell bar, island panels, control center, notifications, and captures
├── scripts/             # System, display, Qt, and lock-screen helpers
├── sddm/themes/         # Cyberpunk video themes installed system-wide
├── sddm/previews/       # Preview images of the SDDM themes
├── starship/            # Starship prompt configuration
├── tmux/                # Tmux configuration
├── wallpapers/          # Cyberpunk wallpapers
├── yazi/                # Yazi file manager configuration and theme
└── zsh/                 # Shell, aliases, bindings, and functions
```

Most top-level configuration directories are GNU Stow modules that symlink into `$HOME`. `assets/`, `battery/`, `brave/`, `grub/`, `keyboard/`, and `sddm/` are repository or system-wide resources handled separately by the installer and scripts. The `qt5/` and `qt6/` directories only store the versioned Catppuccin palettes: the installer generates complete local Qtct configurations so graphical changes do not modify the repository.

---

## ⌨️ Keyboard Layout

> [!NOTE]
> Only **AZERTY FR** and **QWERTY US** are supported. Any other layout would leave the Vim-style keys in the wrong place.

The installer offers two keyboard profiles:

- `FR` — AZERTY layout with Vim-style movements remapped from `h j k l` to `j k l m`.
- `US` — QWERTY layout with the standard `h j k l` Vim-style movements.

`US` is the default when no profile has been selected yet or when the installer prompt is left empty.

The active profile can be changed later from the command line:

```bash
~/Scripts/keyboard-layoutctl.sh set us
~/Scripts/keyboard-layoutctl.sh set fr
```

The selection is stored in `$XDG_STATE_HOME/hyprpunk/keyboard-layout` (or `~/.local/state/hyprpunk/keyboard-layout`).
It also becomes the system keymap through `localectl`, for the SDDM login screen and the TTYs, without asking for a
password: the installer adds a polkit rule (`keyboard/polkit/`) that lets the session change the keymap, and only that.
Hyprland, Kitty, and tmux pick up the change immediately. New Zsh and Yazi processes use it on startup;
an existing Neovim instance can reload its movement mappings with `:KeyboardLayoutReload` (restart Neovim to
also rebuild plugin-specific mappings such as Snacks Explorer).

The layout integration covers:

- 🪟 `hyprland/.config/hypr/input.lua`
- ⌨️ `hyprland/.config/hypr/keybindings.lua`
- 📖 `scripts/Scripts/keyboard-layoutctl.sh` (generated less bindings)
- 📝 `nvim/.config/nvim/lua/config/keymaps.lua`
- 💻 `tmux/.config/tmux/tmux.conf`
- 📁 `keyboard/yazi/fr.toml`
- ⌨️ `kitty/.config/kitty/kitty.conf`
- 🐚 `zsh/.bindingrc` and `zsh/.zshrc`
- 🔑 The system keymap (SDDM and TTYs), set with `localectl set-x11-keymap`

The clipboard history (`Ctrl + ù` in AZERTY) is bound to the same physical key in QWERTY: `Ctrl + '`.

Hyprland reads the selected XKB layout dynamically instead of hard-coding:

```lua
kb_layout = keyboard.xkb
```

### 🌍 Locale profiles

The interface language (`LANG` and `LC_MESSAGES`) and regional formats (the other `LC_*` categories) are independent,
and each is either English (`us`, `en_US.UTF-8`) or French (`fr`, `fr_FR.UTF-8`), the only two locales installed.
They can be changed after installation from the command line:

```bash
~/Scripts/locale-profilectl.sh set-language us
~/Scripts/locale-profilectl.sh set-language fr
~/Scripts/locale-profilectl.sh set-regional us
~/Scripts/locale-profilectl.sh set-regional fr
```

The profiles are stored in `$XDG_STATE_HOME/hyprpunk/locale-language` and `locale-regional`. Hyprland, D-Bus, and the
systemd user environment are refreshed immediately for newly started applications; already running applications need
to be restarted.

---

## 🖥️ Display Settings

Monitors are managed by `~/Scripts/displayctl.sh`: per-output resolution, refresh rate, scale, relative positioning, persistent output numbering, and workspace assignment, plus an automatic layout and a reset of all saved display settings. The settings are persisted in `$XDG_STATE_HOME/hyprpunk/monitor-state.conf` (or `~/.local/state/hyprpunk/monitor-state.conf`) and applied by Hyprland on reload. Run `~/Scripts/displayctl.sh` without arguments to list its commands.

---

## ⚙️ System Services And Components

The installer enables or configures:

- 🌐 `NetworkManager`
- 🎬 `sddm`
- 📶 `bluetooth`
- ⚡ `power-profiles-daemon`
- 🧱 `xwayland-satellite` for X11 apps, started with the session, with Hyprland's own XWayland turned off
- 🔋 `battery-limit.service`, on laptops whose battery driver has a charge limit: it lets the `wheel` group change the limit from the control center and applies the chosen one again at boot and around sleep
- 🔑 `gnome-keyring`
- 🛡️ `hyprpolkitagent`
- 🎨 GTK, Qt, and Kvantum themes
- 📁 Papirus Dark icons with Catppuccin Mocha Mauve folders
- 🕹️ CyberEXS GRUB theme when GRUB is present

---

## 🔧 Customization

Everything you're meant to change lives outside the dotfiles, so `git pull` brings you every update without
touching your preferences:

- 🎛️ **The shell's settings** (keyboard layout, displays, glass style, language…) are saved in
  `~/.local/state/hyprpunk/` as you pick them.
- 🧩 **Your Hyprland preferences** go in `~/.config/hypr/personal/`. The installer fills it with commented examples
  from `hyprland/.config/hypr/personal.example/`, one per subject, each loaded after HyprPunk's own file so
  whatever you set wins:
  - ⌨️ `keybindings.lua` to swap the apps the shortcuts open (`hyprpunk.programs.music = "spicetify auto"`), or
    add, rebind and free shortcuts with `hyprpunk.bind`, `hyprpunk.rebind` and `hyprpunk.unbind`.
  - 🪟 `rules.lua` to send your apps to a workspace with `hyprpunk.app("org.gnome.Geary", 6)`, plus any window rule.
  - 🖱️ `input.lua` for the mouse, touchpad and gestures. The keyboard layout comes from the shell's settings.
  - 🚀 `autostart.lua` to start more with the session with `hyprpunk.autostart.add`, or drop a default with
    `hyprpunk.autostart.remove`.
- 🐚 **Your shell tweaks** go in files of your own, each skipped when it doesn't exist:
  - `~/.personalrc`, read at the very end of `.zshrc`, so your aliases, functions, options and variables win over
    HyprPunk's, fzf's and the prompt's.
  - `~/.completionrc`, read before Oh My Zsh sets up completion, the place to add your own completions to `fpath`.

We advise you to leave the rest of the dotfiles as they are. They're linked straight from the repository, so any
edit there clashes with the next `git pull`, and the modules expect each other as they ship. If something you need
can't be done from these files, open an issue rather than patching HyprPunk itself.

---

## 🚧 Roadmap

- 📦 Add a dependency table per module.
- 🩺 Add troubleshooting notes for SDDM and Hyprland.
- 🌆 Update the installer to use the `HyprPunk` name everywhere.
- ♻️ Add uninstall or backup restore instructions.

---

## 🙏 Credits

- 🕹️ The CyberEXS GRUB theme comes from [HenriqueLopes42/themeGrub.CyberEXS](https://github.com/HenriqueLopes42/themeGrub.CyberEXS).
- 🎬 The SDDM themes are inspired by [Darkkal44/qylock](https://github.com/Darkkal44/qylock).
- 🔒 The lock screen is inspired by the one in [andreumassanet/impasto](https://github.com/andreumassanet/impasto): the date over a big clock with see-through minutes, and the island holding a padlock.
- 🎧 The AirPods protocol details come from [kavishdevar/librepods](https://github.com/kavishdevar/librepods), and so do the AirPods renders the shell downloads on first use.
- 😀 The emoji list comes from [rofi-emoji](https://github.com/Mange/rofi-emoji) 4.1.0 by Magnus Bergmark (MIT), generated from the Unicode CLDR data.
- 🔤 The login screens use [Pixelify Sans](https://github.com/eifetx/Pixelify-Sans) by Stefie Justprince, under the SIL Open Font License 1.1 (`OFL.txt` next to the font).
- 💤 The Neovim configuration starts from the [LazyVim starter](https://github.com/LazyVim/starter), under the Apache License 2.0 (`nvim/.config/nvim/LICENSE`).

---

## 📎 Related

Looking for my Windows configuration?

[dotfiles-windows](https://github.com/tuconnaisyouknow/dotfiles-windows)

---

## 📜 License

The code and configuration are under the MIT license. Feel free to explore, fork, and adapt.

The MIT license doesn't cover the artwork. The wallpapers, the Fastfetch logo, the login screen videos and the
CyberEXS GRUB theme belong to their respective authors and are shared here for personal use only, without any
license from them. If you made one of them and want it credited or removed, please open an issue.

The parts listed in the [Credits](#-credits) keep their own licenses.
