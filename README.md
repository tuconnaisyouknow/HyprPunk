# 🌆 HyprPunk

> Arch Linux dotfiles for Hyprland, with a cyberpunk visual direction and two themes, neon and daydream, where the wallpaper you pick colors the whole desktop.

HyprPunk is a complete personal Wayland setup built around **Hyprland**.  
It brings together the window manager, the desktop shell, themes, scripts, terminal, shell, and CLI tools in a modular **GNU Stow** based configuration.

The goal is simple: a cohesive, dark, readable, and responsive desktop inspired by cyberpunk visuals without getting in the way of daily work.

---

## 🎭 Philosophy

HyprPunk has one art direction, and every part of it is built for it: the two themes, their wallpapers and the
palette each one brings, the glass, the shapes, the font and the motion. Each piece is tuned against the others, so
the look is a whole, not a set of options.

- ✅ **How it works is yours to change.** Your apps, shortcuts, window rules, input, environment, autostart, terminal
  and shell: everything under [Customization](#-customization) is meant for you, and survives updates.
- 🚫 **How it looks isn't.** Other GTK, Qt or icon themes, fonts, color schemes, a light mode or another bar aren't
  supported, and nothing is built to allow them. The colors come from the wallpapers HyprPunk ships, each with a
  palette picked by hand.

If you want another look, HyprPunk isn't the right base: fork it, or take the parts you like into your own setup.

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

The clock's island grows into every panel, the password prompts for admin rights, the apps' file pickers and the screen share picker included, and shows the volume, brightness, keyboard light, microphone and touchpad changes, with new notifications stacking out of it.

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
- 🧊 **Quickshell** for the bar, the dynamic island panels (launcher, clipboard, emoji, wallpapers, themes, session), the control center, the notifications (popping out of the island), the OSD, the lock screen (with the player and its lyrics), and screenshots (annotated in place) and screen recordings.
- 🔋 A battery charge limit set from the control center, on laptops whose battery driver supports one.
- 🪫 Battery warnings at the levels you choose in the settings, and the computer sleeping or shutting down when
  it stays critical.
- 🔒 **Hypridle**, **hyprsunset** and **awww** for locking around sleep, the night light, and wallpapers with animated
  transitions.
- 🎬 **SDDM** with a video login screen for each subtheme, in the wallpaper's colors.
- 💻 **Kitty**, **Zsh**, **Starship**, **Tmux**, and **Yazi** for the terminal workflow.
- 📝 **Neovim** with a Lua-based configuration.
- 🎨 **GTK 3/4**, **Qt5/Qt6** and **Kvantum** with one libadwaita look, the shell and the terminal tools, all in the
  wallpaper's own palette, written by **matugen** (see [Visual Identity](#-visual-identity)).
- 🛠️ **Cliphist**, **Fastfetch**, **Btop**, **Cava**, **Bat**, and utility scripts.
- 🦁 **Brave** managed policy (extensions, Rewards, Wallet, AI Chat) installed system-wide.
- 📦 Modular configuration managed with GNU Stow.

---

## 🎨 Visual Identity

HyprPunk comes in two themes, **neon** and **daydream**: the city never sleeps, but it dreams. Each has its own
wallpapers, sorted into subthemes in `~/Pictures/Wallpapers/<theme>/<subtheme>/`, and the wallpaper you pick decides
the whole look:

- 🎨 Its own palette, picked by hand (`matugen/.config/matugen/palettes/`): the wallpaper's hues at Catppuccin Mocha's
  lightness, so the desktop stays dark and readable.
- ✨ An accent, in Mocha's mauve role, for titles and what's selected or active, and a secondary color, in lavender's
  role, for everything else you read.
- 🌑 Surfaces and grays tinted with the wallpaper's mood.
- 🚦 Red, green, yellow, peach and blue never change, since they mean something: errors, the battery, the camera and
  the microphone.

matugen fills every app's template with it: GTK, Qt and Kvantum, the shell, Hyprland's borders, the login screen, the
terminal and its tools (Catppuccin Mocha tinted with the palette), and Brave's Classic theme, through its policy. The
shell, open GTK apps, terminals, the prompt, tmux, Neovim, btop and Brave change at once, Qt apps, yazi and fastfetch
the next time they start. Papirus's folders stay grey, which goes with every palette.

The theme picker (`Super + Ctrl + T`) switches theme and brings back the last wallpaper you had in it.

The shell's glass comes in two styles: **Classic**, with crisp rims, and **Liquid**, see-through like the lock screen's
minutes with a soft rim. Switch between them live from the control center's Display block, the settings' Appearance
page, or with `hyprpunk glass set classic|liquid|toggle`.

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
- An internet connection. The dotfiles alone weigh about 180 MB to download, mostly the screenshots, wallpapers and
  login screen videos, and the packages come on top.
- GRUB is optional: its theme is skipped with any other bootloader.

### 🖥️ Hardware

> [!IMPORTANT]
> HyprPunk doesn't install any graphics driver. Install the ones your GPU needs yourself, before or right after
> HyprPunk, following the Arch Wiki for [Intel](https://wiki.archlinux.org/title/Intel_graphics),
> [AMD](https://wiki.archlinux.org/title/AMDGPU) or [NVIDIA](https://wiki.archlinux.org/title/NVIDIA), and
> Hyprland's own [NVIDIA page](https://wiki.hypr.land/Nvidia/) for NVIDIA cards.

The rest adapts to the machine on its own:

- 🔋 The battery pill, alerts and charge limit only show on a laptop with a battery, the charge limit only when its
  driver has one.
- 💡 Brightness follows the screen's backlight, and the keyboard light where there is one.
- 🖱️ The touchpad toggle only matters when there's a touchpad.
- 🖥️ Several monitors are handled by `displayctl.sh` (see Display Settings below).

Some of the looks are heavy for a small machine or a virtual machine: the liquid glass (switch to **Classic** in the
control center's Display block), the login screen's videos, and the 4-pass blur (`passes` in
`~/.config/hypr/looknfeel.lua`).

### ▶️ Run it

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/tuconnaisyouknow/HyprPunk/refs/heads/master/install.sh)
```

The script asks for the keyboard layout, interface language, and regional formats first, then your password once.
After that it runs on its own until it offers to reboot, so you can leave it during the long package builds. Left empty, the
answers give a US layout and English for both the interface and the formats (`en_US.UTF-8`). English and French
(`fr_FR.UTF-8`) are both generated during installation, so you can switch later in the settings (`Super + I`). If the installation stops, run the
same command again and it picks up where it left off.

Reboot after the installation completes.

> [!NOTE]
> Only two keyboard layouts are supported, **QWERTY US** and **AZERTY FR**, and only two languages and regional
> formats, **English (`en_US`)** and **French (`fr_FR`)**. Other layouts and locales aren't handled.

### 📦 What gets installed

HyprPunk installs its own choice of applications, without asking. You can remove any of them afterwards with
`yay -Rns <package>`, which no update brings back, and give its shortcut another app from your personal files (see
[Customization](#-customization)).

- 🌐 **Brave**, with **uBlock Origin Lite** installed by its policy, its Classic theme in the wallpaper's colors, and
  Rewards, Wallet and AI Chat turned off.
- 🎵 **Spotify** (`spotify-launcher`) and 📓 **Obsidian**.
- 📄 **LibreOffice** for documents, **Papers** for PDFs, **Loupe** for images, **mpv** for videos and **Celluloid** for
  music files, set as the default apps for those files (an update leaves the ones you picked).
- 📁 **Thunar** for files, with thumbnails of videos, audio covers, PDFs, office documents, EPUBs, RAW photos and
  fonts (Tumbler), your phone and network shares (gvfs), and an "Open Terminal Here" that opens your terminal.
  **xarchiver** for archives (7z, RAR, ZIP…), from Thunar's right-click menu too. **Seahorse** for the keyring.
- 📝 **Neovim** and **Lazygit**, with `cargo` and `npm` for the language servers Neovim's Mason downloads on its first
  start, with their linters and formatters: Bash, Python, HTML, CSS, TypeScript and React, Java, Markdown, Docker,
  JSON and Hyprland.
- 🎨 **gtk4-live-css** in place of Arch's `gtk4`: the same package with one patch, so open GTK 4 apps take a new
  wallpaper's colors at once. [saneaspect](https://github.com/saneaspect/gtk4-live-css) builds it every day from Arch's
  own recipe, in a repository the installer adds to `pacman.conf`. Its packages aren't signed, so pacman installs them
  without checking who made them.

### 🔄 Updating

```sh
hyprpunk update
```

`hyprpunk` is the one command HyprPunk adds to your `PATH` (in `~/.local/bin`): run it alone to list what else it does.
When an update is waiting, a notification tells you at login, and its **Update** button runs it in your terminal
(turn it off in the settings, `Super + I`, Updates, where a button also updates HyprPunk). `hyprpunk check` asks
the same from a terminal.

It pulls the latest HyprPunk, then runs the installer's steps again with the new version. Each step describes how
things should be rather than what to do, so running it again only changes what differs, and a machine installed months
ago catches up on everything at once.

- 🔁 **Put back as HyprPunk ships it:** the look (GTK, Qt and icon themes, the font, dark mode, Papirus's grey
  folders), the login screens, the GRUB theme, Brave's policy, the services and system files, and the links into your
  home, a new module included. Links left broken by a file HyprPunk removed go away.
- 🎛️ **Kept as you set it:** what you picked in the shell (layout, language, displays, touchpad, wallpaper), the
  default apps, and your personal files (see [Customization](#-customization)). An example HyprPunk adds to
  `~/.config/hypr/personal/` is copied in, the files you have stay.
- 📦 **Packages:** the system and the AUR are upgraded, and only the packages new to HyprPunk's list since your last
  update get installed, so an app you removed stays removed. One HyprPunk no longer installs becomes a dependency: it
  leaves at your next orphan cleanup (`yay -Yc`), if nothing else needs it.

It asks for your password once. If it stops, run it again: it finishes what's left. If you edited a file of the
repository that the update changes, git refuses the pull and nothing changes.

---

## 🚀 First Steps

> [!TIP]
> These are enough to find your way around on the first login. **`Super + Ctrl + K`** lists every other shortcut,
> and clicking one in that list runs it.

| Shortcut | What it does |
|---|---|
| `Super + T` | Open the terminal (Kitty, or the one picked in the settings) |
| `Super + Space` | Open the application launcher |
| `Super + Ctrl + Space` | Open the main menu |
| `Super + C` | Open the control center (Wi-Fi, Bluetooth, sound, display, battery, background apps…) |
| `Super + I` | Open the settings (displays, mouse and touchpad, keyboard and language, sound, battery, idle and sleep, lock screen, night light, appearance, notifications, island, default apps, launcher, screenshots, clipboard and history, updates), also from the main menu |
| `Super + N` | Open the calendar and notifications |
| `Super + V` | Open the clipboard history |
| `Super + Q` | Close the focused window |
| `Super + F` | Maximize the focused window, add `Shift` to make it float instead |
| `Super + 1` … `Super + 0` | Switch to a workspace, add `Shift` to send the window there |
| `Super + Tab` | Switch back to the previous workspace |
| `Super + Escape` | Open the session menu (lock, log out, reboot, shut down) |
| `Super + Ctrl + K` | Show all the keybindings |

`Super` is the Windows key. The arrows follow Vim, `h j k l` on QWERTY and `j k l m` on AZERTY: `Super` with one of
them, or with a real arrow, moves the focus, and adding `Shift` moves the window.

### 🏝️ Shell panels

Every panel of the shell opens with `qs -c hyprpunk ipc call <panel> toggle` (or `open`, `close`), which is also what
you'd bind to your own shortcuts.

| Panel | Shortcut |
|---|---|
| `launcher` | `Super + Space` |
| `menu` | `Super + Ctrl + Space` |
| `clipboard` | `Super + V` |
| `emoji` | `Super + .` or `Super + ;` |
| `keybindings` | `Super + Ctrl + K` |
| `wallpaper` | `Super + Ctrl + W` |
| `theme` (neon or daydream) | `Super + Ctrl + T` |
| `session` | `Super + Escape` |
| `controlcenter` | `Super + C` |
| `settings` (a floating window) | `Super + I` |
| `notifications` | `Super + N` |
| `workspaces` (preview of the others) | `Super + W` |
| `systemmonitor` | `Ctrl + Shift + Escape` |
| `player` (the bar's player card, while Spotify runs) | `Super + Shift + P` |
| `config`, `screenshot` | From the main menu |

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
move your pictures or videos folder in `~/.config/user-dirs.dirs`. The settings (`Super + I`, Screenshots) choose
other folders, whether a screenshot is copied, saved or both, and what a recording hears.

### 🔒 Locking and sleep

The screen locks with `Super + Ctrl + L`, from the session menu, or after 5½ minutes without use. The screen dims
first, at 5 minutes, and the computer goes to sleep after 30 minutes. These delays, plugged in and on battery, are in
the settings (`Super + I`, Idle and sleep). Before sleeping, the screen locks at once,
without its animation. The lock is held by Hyprland itself, so the screens stay locked even if the shell crashes.

### 🎵 Music player

The bar's spinning record, its player card and the lock screen's player and synced lyrics follow **Spotify only**.
Other players, like a video in the browser or mpv, still work with the media keys but don't show there. This is a
choice, not something you can switch: picking another music app in the settings, or setting
`hyprpunk.programs.music`, only changes what `Super + P` opens.

The record spins while the music plays, and a wave moves with it at the bottom of the desktop. Both keep the screen
redrawing, which a laptop's GPU feels: the settings' Appearance page, or `hyprpunk music set cover spinning|still|off`
and `hyprpunk music set wave true|false`, keeps the record still or leaves its cover out, and turns the wave off, on
the lock screen too.

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
├── bat/                 # Bat configuration
├── battery/             # Battery charge limit script and service installed system-wide
├── brave/               # Brave's policy, and the tool that gives its theme the wallpaper's colors, installed system-wide
├── btop/                # Btop configuration
├── cava/                # Audio visualizer configuration
├── fastfetch/           # Fastfetch's logos
├── fontconfig/          # JetBrainsMono Nerd Font preference
├── grub/                # CyberEXS GRUB theme installed system-wide
├── gtk3/                # GTK 3 settings, and the HyprPunk theme that takes matugen's colors
├── gtk4/                # GTK 4 settings
├── hypridle/            # Locking for logind, and before sleep
├── hyprland/            # Hyprland Lua config, keybindings, and monitors
├── kdeglobals/          # Minimal KDE integration for icons and Qt6ct
├── keyboard/            # Layout-specific application keymaps and the keymap polkit rule
├── kitty/               # Kitty terminal configuration
├── kvantum/             # Kvantum's theme choice
├── matugen/             # Each wallpaper's palette, and the templates matugen fills for the apps, the shell and the terminal tools
├── nvim/                # Neovim Lua configuration
├── portal/              # Sends the apps' Open and Save dialogs and screen sharing to the shell's pickers
├── quickshell/          # Quickshell bar, island panels, control center, notifications, captures, and prompts
├── scripts/             # The hyprpunk command, and the helpers the shell and Hyprland run from ~/.local/lib/hyprpunk
├── sddm/                # The tool that gives the login screen the wallpaper's subtheme and colors, installed system-wide
├── sddm/base/           # What every login screen shares: the layout, its settings and the font
├── sddm/themes/         # Each subtheme's login screen: its own video and name, assembled with the base system-wide
├── thunar/              # Thunar's custom actions, copied in once
├── tmux/                # Tmux configuration
├── wallpapers/          # Wallpapers, sorted into the neon and daydream themes and their subthemes
├── yazi/                # Yazi file manager configuration
└── zsh/                 # Shell, aliases, bindings, and functions
```

Every top-level directory is a GNU Stow module that symlinks into `$HOME`, except `assets/`, `battery/`, `brave/`, `grub/`, `keyboard/`, `sddm/`, and `thunar/`, repository, system-wide or copied resources handled separately by the installer and scripts. The themes' colors aren't linked: matugen fills `matugen/`'s templates with the wallpaper's palette, and `qt-configctl.sh` writes the Qtct configurations, so graphical changes don't modify the repository.

---

## ⌨️ Keyboard Layout

> [!NOTE]
> Only **AZERTY FR** and **QWERTY US** are supported. Any other layout would leave the Vim-style keys in the wrong place.

The installer offers two keyboard profiles:

- `FR` — AZERTY layout with Vim-style movements remapped from `h j k l` to `j k l m`.
- `US` — QWERTY layout with the standard `h j k l` Vim-style movements.

`US` is the default when no profile has been selected yet or when the installer prompt is left empty.

The active profile can be changed later in the settings (`Super + I`, Keyboard and language), or from the command
line:

```bash
hyprpunk keyboard set us
hyprpunk keyboard set fr
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
- 📖 `scripts/.local/lib/hyprpunk/keyboard-layoutctl.sh` (generated less bindings)
- 📝 `nvim/.config/nvim/lua/config/keymaps.lua`
- 💻 `tmux/.config/tmux/tmux.conf`
- 📁 `keyboard/yazi/fr.toml`
- ⌨️ `kitty/.config/kitty/kitty.conf`
- 🐚 `zsh/.bindingrc` and `zsh/.zshrc`
- 🔑 The system keymap (SDDM and TTYs), set with `localectl set-x11-keymap`

Hyprland reads the selected XKB layout dynamically instead of hard-coding:

```lua
kb_layout = keyboard.xkb
```

### 🌍 Locale profiles

The interface language (`LANG` and `LC_MESSAGES`) and regional formats (the other `LC_*` categories) are independent,
and each is either English (`us`, `en_US.UTF-8`) or French (`fr`, `fr_FR.UTF-8`), the only two locales installed.
They can be changed after installation from the command line:

```bash
hyprpunk locale set-language us
hyprpunk locale set-language fr
hyprpunk locale set-regional us
hyprpunk locale set-regional fr
```

The profiles are stored in `$XDG_STATE_HOME/hyprpunk/locale-language` and `locale-regional`. Hyprland, D-Bus, and the
systemd user environment are refreshed immediately for newly started applications; already running applications need
to be restarted. The shell follows the regional formats on the spot: the clocks run on 12 hours with AM/PM with `us`
and on 24 hours with `fr`, and the calendar starts the week on the right day.

---

## 🖥️ Display Settings

Monitors are set up in the settings' Displays page (`Super + I`), where you drag a screen against another to place
it, or with `hyprpunk display`: per-output resolution, refresh rate, scale, relative positioning, persistent output numbering, and workspace assignment, plus an automatic layout and a reset of all saved display settings. The settings are persisted in `$XDG_STATE_HOME/hyprpunk/monitor-state.conf` (or `~/.local/state/hyprpunk/monitor-state.conf`) and applied by Hyprland on reload. Run `hyprpunk display` without arguments to list its commands.

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
- 🎨 GTK, Qt, and Kvantum themes
- 📁 Papirus Dark icons, with grey folders
- 🕹️ CyberEXS GRUB theme when GRUB is present

---

## 🔧 Customization

Everything you're meant to change lives outside the dotfiles, so an [update](#-updating) brings you every change
without touching your preferences:

- 🎛️ **The shell's settings** (keyboard layout, displays, the mouse and touchpad, glass style, language, when the
  computer dims, locks and sleeps, which apps' notifications pop up, what the island shows, the default apps, the
  launcher's pinned and hidden apps, how screenshots and recordings are kept, the clipboard history, the night light,
  the volume limit…) are saved in `~/.local/state/hyprpunk/` as you pick them, in the control center or the settings
  window (`Super + I`).
- 🧩 **Your Hyprland preferences** go in `~/.config/hypr/personal/`. The installer fills it with commented examples
  from `hyprland/.config/hypr/personal.example/`, one per subject, each loaded after HyprPunk's own file so
  whatever you set wins:
  - ⌨️ `keybindings.lua` to swap the apps the shortcuts open (`hyprpunk.programs.music = "spicetify auto"`), over
    the terminal, browser, files and music apps picked in the settings, or
    add, rebind and free shortcuts with `hyprpunk.bind`, `hyprpunk.rebind` and `hyprpunk.unbind`. Your terminal
    and editor (`hyprpunk.programs.terminal` and `.editor`) are also what the shell opens your config files and
    commands in. Only terminals that run a command given with `-e` are supported (Kitty, Alacritty, foot,
    Ghostty…).
  - 🪟 `rules.lua` to send your apps to a workspace with `hyprpunk.app("org.gnome.Geary", 6)`, float the dialogs of
    an app that lets them get tiled with `hyprpunk.float_dialogs(class, main window's title)`, plus any window rule.
  - 🖱️ `input.lua` for the mouse, touchpad and gestures, over what the settings set. The keyboard layout comes
    from the shell's settings.
  - 🌱 `env.lua` for environment variables, like a bigger cursor. Your own scripts go in `~/.local/bin`, already in
    your `PATH`. The language comes from the shell's settings, and the terminal and editor from `hyprpunk.programs`.
  - 🚀 `autostart.lua` to start more with the session with `hyprpunk.autostart.add`, or drop a default with
    `hyprpunk.autostart.remove`.
- 🖥️ **Your tmux and Kitty settings** go in `~/.config/tmux/personal.conf` and `~/.config/kitty/personal.conf`,
  read last so they win, kept out of git and skipped when they don't exist. Plugins you add to tmux's get installed
  by tpm too.
- 🐚 **Your shell tweaks** go in files of your own, each skipped when it doesn't exist:
  - `~/.personalrc`, read at the very end of `.zshrc`, so your aliases, functions, options and variables win over
    HyprPunk's, fzf's and the prompt's.
  - `~/.completionrc`, read before Oh My Zsh sets up completion, the place to add your own completions to `fpath`.

We advise you to leave the rest of the dotfiles as they are. They're linked straight from the repository, so any
edit there stops the next update, and the modules expect each other as they ship. If something you need
can't be done from these files, open an issue rather than patching HyprPunk itself. The look isn't part of what you
customize (see [Philosophy](#-philosophy)).

---

## 🩺 Troubleshooting

- 📜 **The installer or an update stopped halfway.** Run the same command again, it picks up where it left off.
  Every run is logged to `~/.local/state/hyprpunk/`, in `install-<date>.log` or `apply-<date>.log`, the place to look
  for what failed.
- 🧊 **The shell froze or vanished.** `Super + Alt + Q` restarts it. To see why it went wrong, run
  `qs -c hyprpunk log` in a terminal, or add `-f` to follow it live.
- 🪟 **Hyprland doesn't take your change.** It rereads its config on its own when you save. Run `hyprctl reload` to
  force it, and `hyprctl configerrors` to list the mistakes it found. Its full log is in
  `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log`.
- 💤 **The screen doesn't lock or dim.** The shell does it after the delays in its settings (`Super + I`):
  `Super + Alt + Q` restarts it. If it doesn't lock before sleep, `Super + Alt + I` restarts hypridle.
- 🎬 **The login screen stays black or falls back to a plain one.** `journalctl -b -u sddm` shows what SDDM
  complained about at the last boot.

---

## 🙏 Credits

- 🎨 The Kvantum theme is [GabePoel/KvLibadwaita](https://github.com/GabePoel/KvLibadwaita) by Gabriel Perko-Engel, under the GPL-3.0, with its colors swapped for the palette's. GTK 3 apps get libadwaita's look from [adw-gtk3](https://github.com/lassekongo83/adw-gtk3).
- 🕹️ The CyberEXS GRUB theme comes from [HenriqueLopes42/themeGrub.CyberEXS](https://github.com/HenriqueLopes42/themeGrub.CyberEXS).
- 🎬 The SDDM themes are inspired by [Darkkal44/qylock](https://github.com/Darkkal44/qylock).
- 🐱 The terminal tools' colors (Kitty, Btop, Yazi, Bat) start from [Catppuccin](https://github.com/catppuccin)'s Mocha themes (MIT), tinted with the wallpaper's palette.
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

The Kvantum theme's templates (`matugen/.config/matugen/templates/kvantum.*`) stay under KvLibadwaita's GPL-3.0.

The MIT license doesn't cover the artwork. The wallpapers, the Fastfetch logo, the login screen videos and the
CyberEXS GRUB theme belong to their respective authors and are shared here for personal use only, without any
license from them. If you made one of them and want it credited or removed, please open an issue.

The parts listed in the [Credits](#-credits) keep their own licenses.
