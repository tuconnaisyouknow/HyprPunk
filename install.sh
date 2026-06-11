#!/usr/bin/env bash

set -euo pipefail

DOTFILES_REPO="https://github.com/tuconnaisyouknow/HyprPunk.git"
DOTFILES_DIR="$HOME/.dotfiles"
GITHUB_DIR="$HOME/GitHub"
BACKUP_DIR="$HOME/.backup/system-$(date +%Y-%m-%d_%H-%M-%S)"

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
    yazi cava bc stow \
    neovim lazygit cargo npm \
    \
    sddm networkmanager network-manager-applet blueman \
    gcr gnome-keyring seahorse \
    \
    hyprland hyprpaper hyprlock hypridle \
    hyprshot hyprcursor waybar swaync \
    swayosd cliphist rofi \
    waybar-module-pacman-updates-git \
    \
    qt5ct qt5-wayland qt5-tools \
    qt5-quickcontrols2 layer-shell-qt5 \
    qt6ct qt6-wayland qt6-tools \
    layer-shell-qt kvantum-qt6-git \
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
    \
    qt6-multimedia \
    qt6-multimedia-ffmpeg \
    gst-plugins-bad \
    gst-plugins-ugly
}

clean_user_configs() {
  echo "Cleaning previous user configs..."

  rm -rf \
    "$HOME/Pictures/Avatars" \
    "$HOME/Pictures/Wallpapers" \
    "$HOME/Scripts" \
    "$HOME/.oh-my-zsh" \
    "$HOME/.config/bat" \
    "$HOME/.config/btop" \
    "$HOME/.config/cava" \
    "$HOME/.config/fastfetch" \
    "$HOME/.config/gtk-3.0" \
    "$HOME/.config/gtk-4.0" \
    "$HOME/.config/hypr/hypridle.conf" \
    "$HOME/.config/hypr/hyprland.conf" \
    "$HOME/.config/hypr/hyprlock.conf" \
    "$HOME/.config/hypr/hyprpaper.conf" \
    "$HOME/.config/kitty" \
    "$HOME/.config/Kvantum" \
    "$HOME/.config/nvim" \
    "$HOME/.config/qt5ct" \
    "$HOME/.config/qt6ct" \
    "$HOME/.config/rofi" \
    "$HOME/.config/starship.toml" \
    "$HOME/.config/swaync" \
    "$HOME/.config/tmux" \
    "$HOME/.config/waybar" \
    "$HOME/.config/yazi" \
    "$HOME/.lesskey" \
    "$HOME/.zshrc" \
    "$HOME/.aliasrc" \
    "$HOME/.functionrc" \
    "$HOME/.highlightrc"
}

backup_system_configs() {
  mkdir -p "$BACKUP_DIR"

  [[ -f /boot/grub/grub.cfg ]] && sudo cp /boot/grub/grub.cfg "$BACKUP_DIR/"
  [[ -f /etc/default/grub ]] && sudo cp /etc/default/grub "$BACKUP_DIR/"
  [[ -f /etc/sddm.conf ]] && sudo cp /etc/sddm.conf "$BACKUP_DIR/"

  echo "System config backup created in: $BACKUP_DIR"
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

install_dotfiles() {
  rm -rf "$DOTFILES_DIR"
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"

  if [[ "$pc_type" == "laptop" ]]; then
    stow --dir "$DOTFILES_DIR" --target "$HOME" avatars bat btop cava fastfetch gtk3 gtk4 hypridle hyprland hyprlock hyprpaper kitty kvantum less nvim qt5 qt6 rofi scripts starship swaync tmux wallpapers waybar yazi zsh
  else
    stow --dir "$DOTFILES_DIR" --target "$HOME" avatars bat btop cava fastfetch gtk3 gtk4 hypridle hyprland hyprlock-desktop hyprpaper kitty kvantum less nvim qt5 qt6 rofi scripts starship swaync tmux wallpapers waybar-desktop yazi zsh
  fi
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
  papirus-folders -C cat-mocha-mauve --theme Papirus-Dark || true

  gsettings set org.gnome.desktop.interface gtk-theme 'catppuccin-mocha-mauve-standard+default'
  gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
  gsettings set org.gnome.desktop.interface font-name 'JetBrainsMono Nerd Font 9'
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
}

install_locale() {
  if ! grep -q '^[[:space:]]*fr_FR.UTF-8[[:space:]]\+UTF-8' /etc/locale.gen; then
    sudo sed -i '/^[[:space:]]*#\s*fr_FR.UTF-8\s\+UTF-8/s/^#\s*//' /etc/locale.gen
  fi

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

  if [[ ! -d /boot/grub ]]; then
    echo "GRUB directory not found, skipping GRUB theme."
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

  systemctl --user enable xwayland-satellite.service || true
}

ask_reboot() {
  read -rp "Do you want to reboot now ? [y/n]: " answer

  case "$answer" in
  y | Y)
    sudo reboot
    ;;
  n | N | *)
    echo "Install complete. Please reboot manually."
    exit 0
    ;;
  esac
}

main() {
  require_arch
  update_system
  ask_pc_type

  mkdir -p "$GITHUB_DIR"

  install_yay
  install_packages
  backup_system_configs
  clean_user_configs
  install_oh_my_zsh
  install_dotfiles
  set_default_apps
  install_tmux_plugins
  apply_themes
  install_locale
  install_sddm_theme
  install_grub_theme
  enable_services
  ask_reboot
}

main "$@"
