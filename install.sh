#!/usr/bin/env bash

set -Eeuo pipefail

DOTFILES_REPO="https://github.com/tuconnaisyouknow/HyprPunk.git"
DOTFILES_DIR="$HOME/.dotfiles"
GITHUB_DIR="$HOME/GitHub"
BACKUP_DIR="$HOME/.backup/system-$(date +%Y-%m-%d_%H-%M-%S)"
LOG_DIR="$HOME/.local/state/hyprpunk"
LOG_FILE="$LOG_DIR/install-$(date +%Y-%m-%d_%H-%M-%S).log"
STATE_FILE="$LOG_DIR/install.state"
current_step="Initialisation"
prepared_dotfiles_dir=""
pc_type=""
keyboard_layout=""
locale_language="us"
locale_regional="fr"

declare -A COMPLETED_STEPS=()

readonly -a USER_CONFIG_PATHS=(
  "Pictures/Avatars"
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
  ".config/hypr/hypridle.conf"
  ".config/hypr/hyprland.conf"
  ".config/hypr/hyprlock.conf"
  ".config/hypr/hyprpaper.conf"
  ".config/kitty"
  ".config/kdeglobals"
  ".config/Kvantum"
  ".config/nvim"
  ".config/qt5ct"
  ".config/qt6ct"
  ".config/rofi"
  ".config/starship.toml"
  ".config/swaync"
  ".config/tmux"
  ".config/waybar"
  ".config/yazi"
  ".lesskey"
  ".zshrc"
  ".bindingrc"
  ".aliasrc"
  ".functionrc"
  ".highlightrc"
)

setup_logging() {
  mkdir -p "$LOG_DIR"
  exec > >(tee -a "$LOG_FILE") 2>&1
  echo "Installation log: $LOG_FILE"
}

save_state() {
  local state_tmp
  local step

  state_tmp=$(mktemp --tmpdir="$LOG_DIR" install-state.XXXXXX)
  {
    printf 'version=1\n'
    printf 'backup_dir=%s\n' "$BACKUP_DIR"
    printf 'pc_type=%s\n' "$pc_type"
    printf 'keyboard_layout=%s\n' "$keyboard_layout"
    printf 'locale_language=%s\n' "$locale_language"
    printf 'locale_regional=%s\n' "$locale_regional"
    for step in "${!COMPLETED_STEPS[@]}"; do
      printf 'completed=%s\n' "$step"
    done
  } >"$state_tmp"
  mv -f "$state_tmp" "$STATE_FILE"
}

load_state() {
  local key value version=""

  COMPLETED_STEPS=()
  while IFS='=' read -r key value; do
    case "$key" in
    version) version="$value" ;;
    backup_dir) BACKUP_DIR="$value" ;;
    pc_type) pc_type="$value" ;;
    keyboard_layout) keyboard_layout="$value" ;;
    locale_language) locale_language="$value" ;;
    locale_regional) locale_regional="$value" ;;
    completed) [[ -n "$value" ]] && COMPLETED_STEPS["$value"]=1 ;;
    esac
  done <"$STATE_FILE"

  [[ "$version" == "1" ]] || {
    echo "Unsupported installation state version: ${version:-missing}" >&2
    return 1
  }
  [[ "$BACKUP_DIR" == "$HOME/.backup/system-"* ]] || {
    echo "Invalid backup directory in installation state: $BACKUP_DIR" >&2
    return 1
  }
  [[ -z "$pc_type" || "$pc_type" == "laptop" || "$pc_type" == "desktop" ]] || {
    echo "Invalid computer type in installation state: $pc_type" >&2
    return 1
  }
  [[ -z "$keyboard_layout" || "$keyboard_layout" == "us" || "$keyboard_layout" == "fr" ]] || {
    echo "Invalid keyboard layout in installation state: $keyboard_layout" >&2
    return 1
  }
  [[ "$locale_language" == "us" || "$locale_language" == "fr" ]] || {
    echo "Invalid language locale in installation state: $locale_language" >&2
    return 1
  }
  [[ "$locale_regional" == "us" || "$locale_regional" == "fr" ]] || {
    echo "Invalid regional locale in installation state: $locale_regional" >&2
    return 1
  }
}

initialize_state() {
  local answer

  if [[ -f "$STATE_FILE" ]]; then
    read -rp "An unfinished installation was found. Resume it? [Y/n]: " answer
    case "$answer" in
    n | N)
      rm -f -- "$STATE_FILE"
      ;;
    *)
      load_state
      echo "Resuming installation. Backup directory: $BACKUP_DIR"
      ;;
    esac
  fi

  save_state
}

cleanup() {
  if [[ -n "$prepared_dotfiles_dir" && -d "$prepared_dotfiles_dir" ]]; then
    rm -rf -- "$prepared_dotfiles_dir"
  fi
}

on_error() {
  local exit_code=$?
  local line_number="$1"
  local command="$2"

  if [[ "$BASHPID" != "$$" ]]; then
    return "$exit_code"
  fi

  trap - ERR
  printf '\nInstallation failed.\n' >&2
  printf 'Step    : %s\n' "$current_step" >&2
  printf 'Line    : %s\n' "$line_number" >&2
  printf 'Command : %s\n' "$command" >&2
  printf 'Exit code: %s\n' "$exit_code" >&2
  printf 'Log     : %s\n' "$LOG_FILE" >&2
  exit "$exit_code"
}

run_step() {
  local step_id="$1"
  current_step="$2"
  shift 2

  if [[ -n "${COMPLETED_STEPS[$step_id]:-}" ]]; then
    printf '\n==> %s (already completed, skipping)\n' "$current_step"
    return
  fi

  printf '\n==> %s\n' "$current_step"
  "$@"
  COMPLETED_STEPS["$step_id"]=1
  save_state
}

trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR
trap cleanup EXIT

clone_or_pull() {
  local repo="$1"
  local dir="$2"

  if [[ -d "$dir/.git" ]]; then
    git -C "$dir" pull
  else
    git clone "$repo" "$dir"
  fi
}

require_arch() {
  if ! command -v pacman &>/dev/null; then
    echo "This script is only designed for Arch Linux."
    exit 1
  fi
}

ask_pc_type() {
  while true; do
    read -rp "Are you on a laptop or desktop ? [l/d]: " pc_input
    case "$pc_input" in
    l | L)
      pc_type="laptop"
      break
      ;;
    d | D)
      pc_type="desktop"
      break
      ;;
    *)
      echo "Invalid option. Please enter 'l' for laptop or 'd' for desktop."
      ;;
    esac
  done
}

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
    read -rp "Regional formats [us/fr] (default: fr): " locale_regional
    locale_regional="${locale_regional,,}"
    case "$locale_regional" in
    "" | fr)
      locale_regional="fr"
      break
      ;;
    us)
      break
      ;;
    *)
      echo "Invalid regional format. Please enter 'fr' or 'us'."
      ;;
    esac
  done
}

install_yay() {
  if ! command -v yay &>/dev/null; then
    sudo pacman -S --needed --noconfirm git base-devel

    mkdir -p "$GITHUB_DIR"
    clone_or_pull "https://aur.archlinux.org/yay.git" "$GITHUB_DIR/yay"

    (
      cd "$GITHUB_DIR/yay"
      makepkg -si --noconfirm --rmdeps
    )
  fi
}

update_system() {
  sudo pacman -Syyu --noconfirm
}

install_packages() {
  yay -S --needed --noconfirm --removemake \
    zsh kitty starship zoxide \
    fzf eza bat fd \
    ripgrep fastfetch btop tmux \
    yazi cava bc stow brightnessctl jq \
    webp-pixbuf-loader gvfs \
    neovim lazygit cargo npm \
    \
    sddm networkmanager network-manager-applet blueman \
    gcr gnome-keyring seahorse \
    \
    hyprland hyprpaper hyprlock hypridle \
    hyprshot satty hyprcursor waybar swaync \
    swayosd cliphist rofi \
    waybar-module-pacman-updates-git \
    \
    qt5ct-kde qt5-wayland qt5-tools \
    qt5-quickcontrols2 layer-shell-qt5 \
    qt6ct-kde qt6-wayland qt6-tools \
    layer-shell-qt kvantum kvantum-qt5 \
    \
    xdg-desktop-portal \
    xdg-desktop-portal-hyprland \
    xwayland-satellite \
    \
    catppuccin-gtk-theme-mocha \
    papirus-icon-theme \
    papirus-folders-catppuccin-git \
    kvantum-theme-catppuccin-git \
    rose-pine-cursor \
    rose-pine-hyprcursor nwg-look \
    \
    ttf-jetbrains-mono-nerd \
    otf-font-awesome \
    ttf-apple-emoji \
    \
    thunar ark loupe papers \
    mpv celluloid mate-media \
    libreoffice-fresh brave-bin \
    spotify-launcher obsidian \
    \
    qt6-multimedia \
    qt6-multimedia-ffmpeg \
    gst-plugin-pipewire \
    gst-plugins-bad \
    gst-plugins-ugly
}

clean_user_configs() {
  echo "Cleaning previous user configs..."

  local path
  for path in "${USER_CONFIG_PATHS[@]}"; do
    rm -rf -- "${HOME:?}/$path"
  done
}

backup_configs() {
  local path
  local -a existing_user_configs=()

  mkdir -p "$BACKUP_DIR"

  [[ -f /boot/grub/grub.cfg ]] && sudo cp /boot/grub/grub.cfg "$BACKUP_DIR/"
  [[ -f /etc/default/grub ]] && sudo cp /etc/default/grub "$BACKUP_DIR/"
  [[ -f /etc/sddm.conf ]] && sudo cp /etc/sddm.conf "$BACKUP_DIR/"

  for path in "${USER_CONFIG_PATHS[@]}"; do
    [[ -e "$HOME/$path" || -L "$HOME/$path" ]] && existing_user_configs+=("$path")
  done

  if ((${#existing_user_configs[@]})); then
    (
      cd "$HOME"
      tar -czf "$BACKUP_DIR/user-configs.tar.gz" -- "${existing_user_configs[@]}"
    )
  fi

  echo "Configuration backup created in: $BACKUP_DIR"
}

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
  rm -f "$HOME/.zshrc"
}

prepare_dotfiles() {
  prepared_dotfiles_dir=$(mktemp -d "${TMPDIR:-/tmp}/hyprpunk-dotfiles.XXXXXX")
  git clone "$DOTFILES_REPO" "$prepared_dotfiles_dir"
  git -C "$prepared_dotfiles_dir" rev-parse --verify HEAD >/dev/null
}

activate_dotfiles() {
  if [[ -d "$BACKUP_DIR/dotfiles" && -d "$DOTFILES_DIR/.git" ]]; then
    rm -rf -- "$prepared_dotfiles_dir"
    prepared_dotfiles_dir=""
    echo "Dotfiles were already activated before the previous interruption."
    return
  fi

  if [[ -d "$DOTFILES_DIR" ]]; then
    mv "$DOTFILES_DIR" "$BACKUP_DIR/dotfiles"
  fi

  mv "$prepared_dotfiles_dir" "$DOTFILES_DIR"
  prepared_dotfiles_dir=""
}

stow_dotfiles() {
  if [[ "$pc_type" == "laptop" ]]; then
    stow --dir "$DOTFILES_DIR" --target "$HOME" avatars bat btop cava fastfetch fontconfig gtk3 gtk4 hypridle hyprland hyprlock hyprpaper kdeglobals kitty kvantum nvim rofi scripts starship swaync tmux wallpapers waybar yazi zsh
  else
    stow --dir "$DOTFILES_DIR" --target "$HOME" avatars bat btop cava fastfetch fontconfig gtk3 gtk4 hypridle hyprland hyprlock-desktop hyprpaper kdeglobals kitty kvantum nvim rofi scripts starship swaync tmux wallpapers waybar-desktop yazi zsh
  fi
}

generate_qt_configs() {
  install -Dm644 \
    "$DOTFILES_DIR/qt5/.config/qt5ct/colors/catppuccin-mocha-mauve.conf" \
    "$HOME/.config/qt5ct/colors/catppuccin-mocha-mauve.conf"
  install -Dm644 \
    "$DOTFILES_DIR/qt6/.config/qt6ct/colors/catppuccin-mocha-mauve.conf" \
    "$HOME/.config/qt6ct/colors/catppuccin-mocha-mauve.conf"

  cat >"$HOME/.config/qt5ct/qt5ct.conf" <<EOF
[Appearance]
color_scheme_path=$HOME/.config/qt5ct/colors/catppuccin-mocha-mauve.conf
custom_palette=true
icon_theme=Papirus-Dark
standard_dialogs=default
style=kvantum-dark

[Fonts]
fixed="JetBrainsMono Nerd Font,9,-1,5,50,0,0,0,0,0,Regular"
general="JetBrainsMono Nerd Font,9,-1,5,50,0,0,0,0,0,Regular"

[Interface]
activate_item_on_single_click=1
buttonbox_layout=0
cursor_flash_time=1000
dialog_buttons_have_icons=1
double_click_interval=400
keyboard_scheme=2
menus_have_icons=true
show_shortcuts_in_context_menus=true
toolbutton_style=4
underline_shortcut=1
wheel_scroll_lines=3

[Troubleshooting]
force_raster_widgets=1
EOF

  cat >"$HOME/.config/qt6ct/qt6ct.conf" <<EOF
[Appearance]
color_scheme_path=$HOME/.config/qt6ct/colors/catppuccin-mocha-mauve.conf
custom_palette=true
icon_theme=Papirus-Dark
standard_dialogs=default
style=kvantum-dark

[Fonts]
fixed="JetBrainsMono Nerd Font,9,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0"
general="JetBrainsMono Nerd Font,9,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0"

[Interface]
activate_item_on_single_click=1
buttonbox_layout=0
cursor_flash_time=1000
dialog_buttons_have_icons=1
double_click_interval=400
keyboard_scheme=2
menus_have_icons=true
show_shortcuts_in_context_menus=true
toolbutton_style=4
underline_shortcut=1
wheel_scroll_lines=3

[Troubleshooting]
force_raster_widgets=1
EOF
}

configure_keyboard() {
  "$HOME/Scripts/keyboard-layoutctl.sh" init "$keyboard_layout"
}

configure_locale_profiles() {
  "$HOME/Scripts/locale-profilectl.sh" init "$locale_language" "$locale_regional"
}

configure_monitors() {
  "$HOME/Scripts/displayctl.sh" init preferred
}

configure_wallpaper() {
  "$HOME/Scripts/wallpaperctl.sh" init
}

configure_touchpad() {
  "$HOME/Scripts/touchpadctl.sh" init true
}

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

apply_themes() {
  papirus-folders -C cat-mocha-mauve --theme Papirus-Dark

  gsettings set org.gnome.desktop.interface gtk-theme 'catppuccin-mocha-mauve-standard+default'
  gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
  gsettings set org.gnome.desktop.interface font-name 'JetBrainsMono Nerd Font 9'
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
}

install_locale() {
  local locale
  for locale in en_US.UTF-8 fr_FR.UTF-8; do
    if ! grep -q "^[[:space:]]*${locale}[[:space:]]\\+UTF-8" /etc/locale.gen; then
      sudo sed -i "/^[[:space:]]*#[[:space:]]*${locale}[[:space:]]\\+UTF-8/s/^[[:space:]]*#[[:space:]]*//" /etc/locale.gen
    fi
  done

  sudo locale-gen
}

install_sddm_theme() {
  local sddm_script="$DOTFILES_DIR/scripts/Scripts/sddm.sh"

  "$sddm_script" install
  "$sddm_script" welcome-to-the-metro
}

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

  if grep -q '^#GRUB_THEME=' /etc/default/grub; then
    sudo sed -i "s|^#GRUB_THEME=.*|GRUB_THEME=$grub_theme_config|" /etc/default/grub
  elif grep -q '^GRUB_THEME=' /etc/default/grub; then
    sudo sed -i "s|^GRUB_THEME=.*|GRUB_THEME=$grub_theme_config|" /etc/default/grub
  else
    echo "GRUB_THEME=$grub_theme_config" | sudo tee -a /etc/default/grub >/dev/null
  fi

  sudo grub-mkconfig -o /boot/grub/grub.cfg
}

enable_services() {
  sudo systemctl enable NetworkManager
  sudo systemctl enable sddm
  sudo systemctl enable swayosd-libinput-backend.service

  systemctl --user enable xwayland-satellite.service
}

ask_reboot() {
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

main() {
  setup_logging
  initialize_state

  run_step "require_arch" "Checking the operating system" require_arch
  run_step "update_system" "Updating the system" update_system
  run_step "ask_pc_type" "Selecting the computer type" ask_pc_type
  run_step "ask_keyboard_layout" "Selecting the keyboard layout" ask_keyboard_layout
  run_step "ask_locale_language" "Selecting the interface language" ask_locale_language
  run_step "ask_locale_regional" "Selecting regional formats" ask_locale_regional

  run_step "create_github_dir" "Creating the GitHub directory" mkdir -p "$GITHUB_DIR"
  run_step "install_yay" "Installing yay" install_yay
  run_step "install_packages" "Installing packages" install_packages

  if [[ -z "${COMPLETED_STEPS[activate_dotfiles]:-}" ]]; then
    current_step="Downloading and validating dotfiles"
    printf '\n==> %s\n' "$current_step"
    prepare_dotfiles
  fi

  run_step "backup_configs" "Backing up existing configuration" backup_configs
  run_step "clean_user_configs" "Cleaning previous user configs" clean_user_configs
  run_step "install_oh_my_zsh" "Installing Oh My Zsh" install_oh_my_zsh
  run_step "activate_dotfiles" "Activating the downloaded dotfiles" activate_dotfiles
  run_step "stow_dotfiles" "Linking dotfiles" stow_dotfiles
  run_step "generate_qt_configs" "Generating Qt configuration" generate_qt_configs
  run_step "configure_keyboard" "Configuring the keyboard" configure_keyboard
  run_step "configure_locale_profiles" "Configuring locale profiles" configure_locale_profiles
  run_step "configure_monitors" "Configuring monitors" configure_monitors
  run_step "configure_wallpaper" "Configuring the wallpaper" configure_wallpaper
  run_step "configure_touchpad" "Configuring the touchpad" configure_touchpad
  run_step "set_default_apps" "Setting default applications" set_default_apps
  run_step "install_tmux_plugins" "Installing tmux plugins" install_tmux_plugins
  run_step "apply_themes" "Applying themes" apply_themes
  run_step "install_locale" "Installing the locale" install_locale
  run_step "install_sddm_theme" "Installing the SDDM theme" install_sddm_theme
  run_step "install_grub_theme" "Installing the GRUB theme" install_grub_theme
  run_step "enable_services" "Enabling services" enable_services
  run_step "ask_reboot" "Finishing installation" ask_reboot

  rm -f -- "$STATE_FILE"
}

main "$@"
