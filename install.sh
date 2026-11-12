#!/usr/bin/env bash
# Sets up HyprPunk on a fresh minimal Arch install, then keeps it up to date. Every step
# describes a state to reach, so running them again only changes what differs: that's
# both how an update works and how a failed install resumes. Logs go to
# ~/.local/state/hyprpunk.
#   install.sh          installs on a fresh system, or resumes an interrupted install
#   install.sh update   pulls the dotfiles, then applies them with the new installer
#   install.sh apply    applies the repository as it is, without pulling, for when you
#                       edit it yourself

set -Eeuo pipefail

DOTFILES_REPO="https://github.com/tuconnaisyouknow/HyprPunk.git"
DOTFILES_DIR="$HOME/.dotfiles"
LOG_DIR="$HOME/.local/state/hyprpunk"
LOG_FILE=""
STATE_FILE="$LOG_DIR/install.state"
PACKAGES_FILE="$LOG_DIR/packages"
current_step="Initialisation"
sudo_keepalive_pid=""
keyboard_layout=""
locale_language=""
locale_regional=""

# What HyprPunk takes over in your home. Finding any of it means the system isn't fresh.
readonly -a USER_CONFIG_PATHS=(
  ".dotfiles"
  "Pictures/Wallpapers"
  "Scripts"
  ".oh-my-zsh"
  ".config/bat"
  ".config/btop"
  ".config/cava"
  ".config/fastfetch"
  ".config/fontconfig"
  ".config/gtk-3.0"
  ".config/gtk-4.0"
  ".config/hypr"
  ".config/kitty"
  ".config/kdeglobals"
  ".config/Kvantum"
  ".config/matugen"
  ".config/nvim"
  ".config/qt5ct"
  ".config/qt6ct"
  ".config/quickshell"
  ".config/tmux"
  ".config/yazi"
  ".zshrc"
  ".bindingrc"
  ".aliasrc"
  ".functionrc"
  ".highlightrc"
)

# Login screens and desktops that would mean someone already set this system up
readonly -a OTHER_DESKTOP_PACKAGES=(
  gdm lightdm lxdm ly greetd sddm
  gnome-shell plasma-workspace xfce4-session cinnamon mate-session-manager
  budgie-desktop lxqt-session i3-wm sway hyprland niri
)

# The folders that aren't linked into your home: installed system-wide by their own
# steps, or the README's images. Every other folder is a stow module.
readonly -a SYSTEM_MODULES=(assets battery brave grub keyboard sddm)

# Everything HyprPunk installs, by what it's for
readonly -a PACKAGES=(
  zsh kitty starship zoxide
  fzf eza bat fd
  ripgrep fastfetch btop tmux
  yazi cava bc stow brightnessctl jq pacman-contrib xdg-user-dirs
  webp-pixbuf-loader
  neovim lazygit cargo npm

  sddm networkmanager
  bluez bluez-utils power-profiles-daemon upower
  python-dbus python-gobject python-cryptography zenity
  pipewire-pulse wireplumber playerctl
  gnome-keyring seahorse

  hyprland awww hypridle
  grim wf-recorder hyprcursor hyprpicker
  quickshell cliphist wl-clipboard libnotify psmisc

  qt5ct-kde qt5-wayland qt5-tools
  qt5-quickcontrols2 layer-shell-qt5
  qt6ct-kde qt6-wayland qt6-tools
  layer-shell-qt kvantum kvantum-qt5

  xdg-desktop-portal
  xdg-desktop-portal-hyprland
  xdg-desktop-portal-gtk
  xwayland-satellite

  adw-gtk-theme matugen imagemagick
  papirus-icon-theme
  papirus-folders
  rose-pine-cursor
  rose-pine-hyprcursor nwg-look

  ttf-jetbrains-mono-nerd
  otf-font-awesome
  ttf-apple-emoji

  dolphin ffmpegthumbs kdegraphics-thumbnailers ark loupe papers
  ffmpeg mpv celluloid mate-media
  libreoffice-fresh brave-bin
  spotify-launcher obsidian

  qt6-multimedia
  qt6-multimedia-ffmpeg
)

############
# PLUMBING #
############

# Everything goes to the screen and to the log, one per run, named after the command
setup_logging() {
  LOG_FILE="$LOG_DIR/$1-$(date +%Y-%m-%d_%H-%M-%S).log"
  mkdir -p "$LOG_DIR"
  exec > >(tee -a "$LOG_FILE") 2>&1
  echo "Log: $LOG_FILE"
}

# The answers, kept until the install is done: the file also says an install is under
# way, so running it again resumes instead of refusing a system that isn't fresh anymore
save_state() {
  local state_tmp

  state_tmp=$(mktemp --tmpdir="$LOG_DIR" install-state.XXXXXX)
  {
    printf 'version=1\n'
    printf 'keyboard_layout=%s\n' "$keyboard_layout"
    printf 'locale_language=%s\n' "$locale_language"
    printf 'locale_regional=%s\n' "$locale_regional"
  } >"$state_tmp"
  mv -f "$state_tmp" "$STATE_FILE"
}

load_state() {
  local key value version=""

  while IFS='=' read -r key value; do
    case "$key" in
    version) version="$value" ;;
    keyboard_layout) keyboard_layout="$value" ;;
    locale_language) locale_language="$value" ;;
    locale_regional) locale_regional="$value" ;;
    esac
  done <"$STATE_FILE"

  [[ "$version" == "1" ]] || {
    echo "Unsupported installation state version: ${version:-missing}" >&2
    return 1
  }
  [[ -z "$keyboard_layout" || "$keyboard_layout" == "us" || "$keyboard_layout" == "fr" ]] || {
    echo "Invalid keyboard layout in installation state: $keyboard_layout" >&2
    return 1
  }
  [[ -z "$locale_language" || "$locale_language" == "us" || "$locale_language" == "fr" ]] || {
    echo "Invalid language locale in installation state: $locale_language" >&2
    return 1
  }
  [[ -z "$locale_regional" || "$locale_regional" == "us" || "$locale_regional" == "fr" ]] || {
    echo "Invalid regional locale in installation state: $locale_regional" >&2
    return 1
  }
}

initialize_state() {
  if [[ -f "$STATE_FILE" ]]; then
    load_state
    echo "Resuming the installation that was interrupted."
  else
    require_fresh_system
  fi

  save_state
}

cleanup() {
  if [[ -n "$sudo_keepalive_pid" ]]; then
    kill "$sudo_keepalive_pid" 2>/dev/null || true
  fi
}

# Asks for your password once, then keeps sudo awake in the background, so a long
# package build can't stop the install at a password prompt while you're away
keep_sudo_alive() {
  sudo -v
  while kill -0 "$$" 2>/dev/null; do
    sudo -n true 2>/dev/null || true
    sleep 50
  done &
  sudo_keepalive_pid=$!
}

# On failure, say which step, which line and where the log is
on_error() {
  local exit_code=$?
  local line_number="$1"
  local command="$2"

  if [[ "$BASHPID" != "$$" ]]; then
    return "$exit_code"
  fi

  trap - ERR
  printf '\nStopped on an error.\n' >&2
  printf 'Step    : %s\n' "$current_step" >&2
  printf 'Line    : %s\n' "$line_number" >&2
  printf 'Command : %s\n' "$command" >&2
  printf 'Exit code: %s\n' "$exit_code" >&2
  printf 'Log     : %s\n' "$LOG_FILE" >&2
  exit "$exit_code"
}

# Names the step, for the screen and for the error message if it fails
run_step() {
  current_step="$1"
  shift

  printf '\n==> %s\n' "$current_step"
  "$@"
}

trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR
trap cleanup EXIT

# Clone a repo, or update it if it's already there
clone_or_pull() {
  local repo="$1"
  local dir="$2"

  if [[ -d "$dir/.git" ]]; then
    git -C "$dir" pull
  else
    git clone "$repo" "$dir"
  fi
}

#############
# THE STEPS #
#############

# Your own user, in the wheel group, so the dotfiles land in your home and sudo works
require_regular_user() {
  if ((EUID == 0)); then
    echo "Run the installer as your own user, not as root." >&2
    echo "Create one first with: useradd -m -G wheel <name>, then let the wheel group use sudo with: EDITOR=nano visudo" >&2
    exit 1
  fi
  if ! command -v sudo &>/dev/null; then
    echo "sudo is missing. Install it as root with: pacman -S sudo" >&2
    exit 1
  fi
  if ! id -nG | grep -qw wheel; then
    echo "$USER isn't in the wheel group. Add it as root with: usermod -aG wheel $USER, then log in again." >&2
    exit 1
  fi
}

require_arch() {
  if ! command -v pacman &>/dev/null; then
    echo "This script is only designed for Arch Linux." >&2
    exit 1
  fi
}

# HyprPunk only goes on a fresh minimal Arch. Finding something it would take over, or
# another desktop, means the system is already set up, so it stops before touching it.
require_fresh_system() {
  local path package
  local -a found=()

  for path in "${USER_CONFIG_PATHS[@]}"; do
    if [[ -e "$HOME/$path" || -L "$HOME/$path" ]]; then
      found+=("$HOME/$path")
    fi
  done
  for package in "${OTHER_DESKTOP_PACKAGES[@]}"; do
    if pacman -Q "$package" &>/dev/null; then
      found+=("$package, already installed")
    fi
  done

  if ((${#found[@]})); then
    echo "HyprPunk only installs on a fresh minimal Arch Linux, and this one is already set up:" >&2
    printf '  - %s\n' "${found[@]}" >&2
    exit 1
  fi
}

# update and apply work on an installed HyprPunk, whose install went all the way
require_installed() {
  if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    echo "HyprPunk isn't installed: $DOTFILES_DIR is missing." >&2
    exit 1
  fi
  if [[ -f "$STATE_FILE" ]]; then
    echo "The installation didn't finish. Run install.sh again, without a command, to resume it." >&2
    exit 1
  fi
}

# The three questions, asked once at the start
ask_keyboard_layout() {
  while true; do
    read -rp "Keyboard layout [us/fr] (default: us): " keyboard_layout
    keyboard_layout="${keyboard_layout,,}"
    case "$keyboard_layout" in
    "" | us)
      keyboard_layout="us"
      break
      ;;
    fr)
      break
      ;;
    *)
      echo "Invalid layout. Please enter 'fr' or 'us'."
      ;;
    esac
  done
}

ask_locale_language() {
  while true; do
    read -rp "Interface language [us/fr] (default: us): " locale_language
    locale_language="${locale_language,,}"
    case "$locale_language" in
    "" | us)
      locale_language="us"
      break
      ;;
    fr)
      break
      ;;
    *)
      echo "Invalid language. Please enter 'fr' or 'us'."
      ;;
    esac
  done
}

ask_locale_regional() {
  while true; do
    read -rp "Regional formats [us/fr] (default: us): " locale_regional
    locale_regional="${locale_regional,,}"
    case "$locale_regional" in
    "" | us)
      locale_regional="us"
      break
      ;;
    fr)
      break
      ;;
    *)
      echo "Invalid regional format. Please enter 'fr' or 'us'."
      ;;
    esac
  done
}

# Everything else goes through yay, so pacman only brings what builds it, with the
# system up to date first. yay is built in /tmp, which Arch keeps in memory, so nothing
# is left in your home and a build cut short is gone at the next reboot.
install_yay() {
  local build_dir

  if command -v yay &>/dev/null; then
    return
  fi

  sudo pacman -Syu --needed --noconfirm git base-devel

  build_dir=$(mktemp -d "${TMPDIR:-/tmp}/hyprpunk-yay.XXXXXX")
  git clone "https://aur.archlinux.org/yay.git" "$build_dir"
  (
    cd "$build_dir"
    makepkg -si --noconfirm --rmdeps
  )
  rm -rf -- "$build_dir"
}

# The official repositories and the AUR together
update_system() {
  yay -Syu --noconfirm
}

# Arch's gtk4 with one patch, built daily by saneaspect, that makes open GTK 4 apps
# reload ~/.config/gtk-4.0/gtk.css: they follow the wallpaper's colors without a
# restart. It replaces gtk4, so pacman is told to accept the conflict (--ask=4).
# Its repository is new the first time, hence the sync.
install_gtk4_live_css() {
  if ! grep -q '^\[saneaspect\]' /etc/pacman.conf; then
    printf '\n[saneaspect]\nSigLevel = Optional TrustAll\nServer = https://github.com/saneaspect/gtk4-live-css/releases/download/repo\n' |
      sudo tee -a /etc/pacman.conf >/dev/null
  fi
  yay -Syu --needed --noconfirm --ask=4 gtk4-live-css
}

# Only the packages added to the list since the last time get installed, so one you
# removed doesn't come back. One that left the list becomes a dependency: it goes at
# your next orphan cleanup, once nothing needs it. The list is saved once they're all
# in. A machine without a saved list (a new install, or one from before) gets every
# missing package.
install_packages() {
  local -a new_packages=() dropped_packages=()

  if [[ -f "$PACKAGES_FILE" ]]; then
    mapfile -t new_packages < <(comm -23 <(printf '%s\n' "${PACKAGES[@]}" | sort -u) <(sort -u "$PACKAGES_FILE"))
    mapfile -t dropped_packages < <(comm -13 <(printf '%s\n' "${PACKAGES[@]}" | sort -u) <(sort -u "$PACKAGES_FILE") |
      xargs -r pacman -Qq 2>/dev/null)
  else
    new_packages=("${PACKAGES[@]}")
  fi

  if ((${#new_packages[@]})); then
    yay -S --needed --noconfirm --removemake "${new_packages[@]}"
  else
    echo "No new packages."
  fi

  if ((${#dropped_packages[@]})); then
    yay -D --asdeps "${dropped_packages[@]}"
  fi

  printf '%s\n' "${PACKAGES[@]}" | sort -u >"$PACKAGES_FILE.tmp"
  mv -f "$PACKAGES_FILE.tmp" "$PACKAGES_FILE"
}

# Oh My Zsh and its plugins, zsh as your shell. A default .zshrc left behind would stop
# stow from linking ours, so it goes, unless it's already our link.
install_oh_my_zsh() {
  clone_or_pull "https://github.com/ohmyzsh/ohmyzsh.git" "$HOME/.oh-my-zsh"

  clone_or_pull "https://github.com/zsh-users/zsh-autosuggestions" \
    "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"

  clone_or_pull "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
    "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"

  clone_or_pull "https://github.com/MichaelAquilina/zsh-you-should-use.git" \
    "$HOME/.oh-my-zsh/custom/plugins/you-should-use"

  clone_or_pull "https://github.com/fdellwing/zsh-bat.git" \
    "$HOME/.oh-my-zsh/custom/plugins/zsh-bat"

  sudo chsh -s "$(command -v zsh)" "$USER"
  [[ -L "$HOME/.zshrc" ]] || rm -f "$HOME/.zshrc"
}

# The dotfiles go straight to ~/.dotfiles, which the fresh system check found empty.
# A clone that got through is kept (an update pulls it instead), one cut short by an
# interruption starts over.
# Only today's files are downloaded: the history comes without the old screenshots,
# which git fetches if you ever go back to an older version.
clone_dotfiles() {
  if [[ -d "$DOTFILES_DIR/.git" ]] && git -C "$DOTFILES_DIR" rev-parse --verify HEAD &>/dev/null; then
    echo "The dotfiles are already downloaded."
    return
  fi

  rm -rf -- "$DOTFILES_DIR"
  git clone --filter=blob:none "$DOTFILES_REPO" "$DOTFILES_DIR"
}

# Links every module into your home, a new one included. Links left broken by a file or
# a module that left the repository go first, wherever they are: stow only cleans the
# folders a module still uses.
stow_dotfiles() {
  local link module
  local -a modules=()

  while IFS= read -r -d '' link; do
    if [[ "$(realpath -m -- "$link")" == "$DOTFILES_DIR"/* ]]; then
      rm -f -- "$link"
    fi
  done < <(find "$HOME" -xdev -path "$DOTFILES_DIR" -prune -o -xtype l -print0 2>/dev/null)

  for module in "$DOTFILES_DIR"/*/; do
    module=$(basename "$module")
    [[ " ${SYSTEM_MODULES[*]} " == *" $module "* ]] || modules+=("$module")
  done
  stow --dir "$DOTFILES_DIR" --target "$HOME" "${modules[@]}"

  # btop rewrites its settings whenever you change one, so it starts from a copy of
  # ours, kept out of git, and the settings you already have stay
  [[ -e "$HOME/.config/btop/btop.conf" ]] ||
    cp "$HOME/.config/btop/btop.default.conf" "$HOME/.config/btop/btop.conf"

  # Your Hyprland tweaks live in a folder of your own, out of git, so a pull never
  # touches them. It starts from the commented examples, which stow leaves out, and
  # files you have stay.
  mkdir -p "$HOME/.config/hypr/personal"
  cp --update=none "$DOTFILES_DIR/hyprland/.config/hypr/personal.example/"*.lua "$HOME/.config/hypr/personal/"
}

# qt5ct and qt6ct rewrite their file on every change, so they get a copy written by
# qt-configctl.sh instead of a link. Their look is HyprPunk's, so it's written again.
generate_qt_configs() {
  "$HOME/Scripts/qt-configctl.sh" restore all
}

# The polkit rule lets the shell send a new layout to the login screen and the TTYs
# without a password. The files generated from your layout are written again.
configure_keyboard() {
  sudo install -Dm644 "$DOTFILES_DIR/keyboard/polkit/50-hyprpunk-keymap.rules" \
    /etc/polkit-1/rules.d/50-hyprpunk-keymap.rules
  "$HOME/Scripts/keyboard-layoutctl.sh" ensure
}

# Each script applies what you picked in the shell again, or its default the first time
configure_locale_profiles() {
  "$HOME/Scripts/locale-profilectl.sh" ensure
}

configure_monitors() {
  "$HOME/Scripts/displayctl.sh" ensure
}

configure_touchpad() {
  "$HOME/Scripts/touchpadctl.sh" ensure
}

# Your wallpaper's look (the colors and its login screen) and the pickers' thumbnails,
# the default wallpaper's the first time. It comes after the login screens are installed.
configure_wallpaper() {
  "$HOME/Scripts/wallpaperctl.sh" ensure
}

# Your answers, given once: the shell is where you change them afterwards
seed_answers() {
  "$HOME/Scripts/keyboard-layoutctl.sh" init "$keyboard_layout"
  "$HOME/Scripts/locale-profilectl.sh" init "$locale_language" "$locale_regional"
}

# Which app opens images, PDFs, videos and documents. Only set at install, since you
# may pick others.
set_default_apps() {
  echo "Setting default applications..."

  local loupe="org.gnome.Loupe.desktop"
  local papers="org.gnome.Papers.desktop"
  local mpv="mpv.desktop"
  local celluloid="io.github.celluloid_player.Celluloid.desktop"
  local writer="libreoffice-writer.desktop"
  local calc="libreoffice-calc.desktop"
  local impress="libreoffice-impress.desktop"

  set_default() {
    local desktop_file="$1"
    shift

    if [[ ! -f "/usr/share/applications/$desktop_file" && ! -f "$HOME/.local/share/applications/$desktop_file" ]]; then
      echo "Warning: $desktop_file not found, skipping."
      return
    fi

    for mime in "$@"; do
      xdg-mime default "$desktop_file" "$mime"
    done
  }

  set_default "$loupe" \
    image/avif image/bmp image/x-dds image/gif image/heif image/vnd.microsoft.icon \
    image/jpeg image/jxl image/x-exr image/png image/x-portable-anymap \
    image/x-portable-bitmap image/x-portable-graymap image/x-portable-pixmap \
    image/qoi image/svg+xml image/x-tga image/tiff image/webp

  set_default "$papers" \
    application/pdf

  set_default "$mpv" \
    video/mp4 video/x-msvideo video/x-matroska video/webm video/ogg \
    video/quicktime video/mpeg video/x-ms-wmv video/x-flv video/3gpp \
    video/3gpp2 video/mp2t video/x-ogm+ogg video/x-theora+ogg \
    video/x-ms-asf video/x-m4v video/x-f4v video/x-fli video/x-mng \
    video/x-nsv video/vnd.rn-realvideo

  set_default "$celluloid" \
    audio/mpeg audio/mp4 audio/aac audio/x-aac audio/flac audio/x-flac \
    audio/ogg audio/opus audio/vorbis audio/webm audio/wav audio/x-wav \
    audio/x-aiff audio/aiff audio/basic audio/midi audio/x-midi \
    audio/x-ms-wma audio/x-m4a audio/x-mpegurl audio/vnd.rn-realaudio

  set_default "$writer" \
    application/vnd.openxmlformats-officedocument.wordprocessingml.document \
    application/msword application/vnd.oasis.opendocument.text \
    application/rtf text/rtf

  set_default "$calc" \
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet \
    application/vnd.ms-excel application/vnd.oasis.opendocument.spreadsheet

  set_default "$impress" \
    application/vnd.openxmlformats-officedocument.presentationml.presentation \
    application/vnd.ms-powerpoint application/vnd.oasis.opendocument.presentation
}

install_tmux_plugins() {
  local tpm_dir="$HOME/.config/tmux/plugins/tpm"

  clone_or_pull \
    "https://github.com/tmux-plugins/tpm" \
    "$tpm_dir"

  TMUX_PLUGIN_MANAGER_PATH="$HOME/.config/tmux/plugins" \
    "$tpm_dir/bin/install_plugins"
}

# Papirus-Dark with grey folders, which go with every wallpaper's palette, the font, dark
# mode and the GTK theme. The look is HyprPunk's, so anything changed here is put back.
# The colors inside the GTK theme come with the wallpaper.
apply_themes() {
  papirus-folders -C grey --theme Papirus-Dark

  gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
  gsettings set org.gnome.desktop.interface font-name 'JetBrainsMono Nerd Font 9'
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  gsettings set org.gnome.desktop.interface gtk-theme 'HyprPunk'
}

# Generate both locales the shell can switch between
install_locale() {
  local locale
  for locale in en_US.UTF-8 fr_FR.UTF-8; do
    if ! grep -q "^[[:space:]]*${locale}[[:space:]]\\+UTF-8" /etc/locale.gen; then
      sudo sed -i "/^[[:space:]]*#[[:space:]]*${locale}[[:space:]]\\+UTF-8/s/^[[:space:]]*#[[:space:]]*//" /etc/locale.gen
    fi
  done

  sudo locale-gen
}

# The login screens, one per subtheme. The wallpaper picks among them.
install_sddm_theme() {
  "$DOTFILES_DIR/scripts/Scripts/sddm.sh" install
}

# The boot menu theme, when GRUB is the bootloader
install_grub_theme() {
  local grub_theme_dir="$DOTFILES_DIR/grub/themes/CyberEXS"
  local grub_theme_target="/boot/grub/themes/CyberEXS"
  local grub_theme_config="$grub_theme_target/theme.txt"

  if ! command -v grub-mkconfig >/dev/null 2>&1; then
    echo "grub-mkconfig not found, skipping GRUB theme."
    return
  fi

  if [[ ! -f "$grub_theme_dir/theme.txt" ]]; then
    echo "GRUB theme not found: $grub_theme_dir/theme.txt"
    exit 1
  fi

  sudo mkdir -p /boot/grub/themes
  sudo cp -ru "$grub_theme_dir" /boot/grub/themes/

  # A broken GRUB config means a machine that won't boot, so its original is kept aside
  [[ -e /etc/default/grub.bak ]] || sudo cp /etc/default/grub /etc/default/grub.bak

  if grep -q '^#GRUB_THEME=' /etc/default/grub; then
    sudo sed -i "s|^#GRUB_THEME=.*|GRUB_THEME=$grub_theme_config|" /etc/default/grub
  elif grep -q '^GRUB_THEME=' /etc/default/grub; then
    sudo sed -i "s|^GRUB_THEME=.*|GRUB_THEME=$grub_theme_config|" /etc/default/grub
  else
    echo "GRUB_THEME=$grub_theme_config" | sudo tee -a /etc/default/grub >/dev/null
  fi

  sudo grub-mkconfig -o /boot/grub/grub.cfg
}

# Brave's managed settings, when Brave is installed. Copied rather than linked, so only
# root can change what applies to every account, like the rest of /etc. wallpaperctl.sh
# gives its theme the wallpaper's accent through the tool and its polkit rule.
install_brave_policy() {
  local policy_src="$DOTFILES_DIR/brave/policies/managed/policy.json"
  local policy_target_dir="/etc/brave/policies/managed"

  if ! command -v brave >/dev/null 2>&1; then
    echo "Brave not found, skipping policy installation."
    return
  fi

  sudo install -Dm644 "$policy_src" "$policy_target_dir/policy.json"
  sudo install -Dm755 "$DOTFILES_DIR/brave/hyprpunk-brave-color" /usr/local/bin/hyprpunk-brave-color
  sudo install -Dm644 "$DOTFILES_DIR/brave/polkit/50-hyprpunk-brave-color.rules" \
    /etc/polkit-1/rules.d/50-hyprpunk-brave-color.rules
}

# The battery charge limit you set from the control center, on laptops that support one.
# The service puts it back at boot and after sleep, and lets the wheel group change it.
install_battery_limit() {
  local battery_dir="$DOTFILES_DIR/battery"

  if ! compgen -G "/sys/class/power_supply/*/charge_control_end_threshold" >/dev/null; then
    echo "No battery charge limit on this computer, skipping."
    return
  fi

  sudo install -Dm755 "$battery_dir/battery-limit" /usr/local/bin/battery-limit
  sudo install -Dm644 "$battery_dir/battery-limit.service" /etc/systemd/system/battery-limit.service
  sudo install -Dm644 "$battery_dir/battery-limit.tmpfiles" /etc/tmpfiles.d/battery-limit.conf
  sudo systemd-tmpfiles --create battery-limit.conf
  sudo systemctl daemon-reload
  sudo systemctl enable --now battery-limit.service
}

enable_services() {
  sudo systemctl enable NetworkManager
  sudo systemctl enable sddm
  sudo systemctl enable bluetooth
  sudo systemctl enable power-profiles-daemon
}

ask_reboot() {
  local answer

  read -rp "Do you want to reboot now ? [y/n]: " answer

  case "$answer" in
  y | Y)
    sudo reboot
    ;;
  n | N | *)
    echo "Install complete. Please reboot manually."
    return 0
    ;;
  esac
}

########
# MAIN #
########

# Everything HyprPunk owns, in the order each step needs the previous ones. All of it is
# safe to run again: an update and a resumed install go through the same list.
converge() {
  run_step "Installing yay" install_yay
  run_step "Updating the system" update_system
  run_step "Installing GTK 4 with live colors" install_gtk4_live_css
  run_step "Installing packages" install_packages
  run_step "Installing Oh My Zsh" install_oh_my_zsh
  run_step "Downloading the dotfiles" clone_dotfiles
  run_step "Linking dotfiles" stow_dotfiles
  run_step "Generating Qt configuration" generate_qt_configs
  run_step "Configuring the keyboard" configure_keyboard
  run_step "Configuring locale profiles" configure_locale_profiles
  run_step "Configuring monitors" configure_monitors
  run_step "Configuring the touchpad" configure_touchpad
  run_step "Installing tmux plugins" install_tmux_plugins
  run_step "Applying themes" apply_themes
  run_step "Installing the locale" install_locale
  run_step "Installing the SDDM theme" install_sddm_theme
  run_step "Installing the Brave policy" install_brave_policy
  run_step "Configuring the wallpaper" configure_wallpaper
  run_step "Installing the GRUB theme" install_grub_theme
  run_step "Installing the battery charge limit" install_battery_limit
  run_step "Enabling services" enable_services
}

# The questions come first, then everything runs on its own until the reboot question.
# Answers are saved as they're given, so a resumed install only asks the missing ones.
install_hyprpunk() {
  require_regular_user
  require_arch
  setup_logging install
  initialize_state

  [[ -n "$keyboard_layout" ]] || run_step "Selecting the keyboard layout" ask_keyboard_layout
  save_state
  [[ -n "$locale_language" ]] || run_step "Selecting the interface language" ask_locale_language
  save_state
  [[ -n "$locale_regional" ]] || run_step "Selecting regional formats" ask_locale_regional
  save_state

  run_step "Asking for your password" keep_sudo_alive
  converge
  run_step "Applying your answers" seed_answers
  run_step "Setting default applications" set_default_apps

  rm -f -- "$STATE_FILE"
  run_step "Finishing installation" ask_reboot
}

# Pulls, then hands over to the installer it just pulled, so the new steps are the ones
# that run. A pull that isn't a fast-forward stops here, before anything changes.
update_hyprpunk() {
  require_regular_user
  require_installed
  run_step "Downloading the update" git -C "$DOTFILES_DIR" pull --ff-only
  exec "$DOTFILES_DIR/install.sh" apply
}

apply_hyprpunk() {
  require_regular_user
  require_arch
  require_installed
  setup_logging apply
  run_step "Asking for your password" keep_sudo_alive
  converge
  printf '\nHyprPunk is up to date.\n'
}

case "${1:-}" in
"") install_hyprpunk ;;
update) update_hyprpunk ;;
apply) apply_hyprpunk ;;
*)
  echo "Usage: install.sh [update|apply]" >&2
  exit 1
  ;;
esac
