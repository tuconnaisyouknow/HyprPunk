#!/usr/bin/env bash

set -euo pipefail

DOTFILES_REPO="https://github.com/tuconnaisyouknow/dotfiles.git"
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

    cd "$GITHUB_DIR/yay"
    makepkg -si --noconfirm --rmdeps
  fi
}

install_packages() {
  yay -S --needed --noconfirm --removemake \
    ttf-jetbrains-mono-nerd otf-font-awesome ttf-apple-emoji \
    kitty starship zoxide fzf eza fastfetch bat zsh npm cargo fd ripgrep lazygit neovim stow \
    sddm networkmanager network-manager-applet blueman \
    waybar waybar-module-pacman-updates-git cliphist rofi bc \
    hyprcursor hypridle hyprlock hyprshot hyprpaper hyprland \
    qt5ct qt5-wayland qt5-tools qt5-quickcontrols2 layer-shell-qt5 \
    qt6ct qt6-wayland qt6-tools layer-shell-qt kvantum-qt6-git \
    xdg-desktop-portal xdg-desktop-portal-hyprland xwayland-satellite \
    catppuccin-gtk-theme-mocha papirus-icon-theme papirus-folders-catppuccin-git \
    kvantum-theme-catppuccin-git rose-pine-cursor rose-pine-hyprcursor nwg-look \
    vlc vlc-plugins-all thunar ark brave-bin \
    gcr gnome-keyring seahorse \
    btop cava swaync swayosd yazi tmux
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

  cd "$DOTFILES_DIR"

  if [[ "$pc_type" == "laptop" ]]; then
    stow avatars bat btop cava fastfetch gtk3 gtk4 hypridle hyprland hyprlock hyprpaper kitty kvantum less nvim qt5 qt6 rofi scripts starship swaync tmux wallpapers waybar yazi zsh
  else
    stow avatars bat btop cava fastfetch gtk3 gtk4 hypridle hyprland hyprlock-desktop hyprpaper kitty kvantum less nvim qt5 qt6 rofi scripts starship swaync tmux wallpapers waybar-desktop yazi zsh
  fi
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
  mkdir -p "$GITHUB_DIR"

  clone_or_pull "https://github.com/Davi-S/sddm-theme-minesddm.git" \
    "$GITHUB_DIR/sddm-theme-minesddm"

  sudo rm -rf /usr/share/sddm/themes/minesddm
  sudo cp -r "$GITHUB_DIR/sddm-theme-minesddm/minesddm" /usr/share/sddm/themes/

  sudo mkdir -p /etc/sddm.conf.d
  sudo tee /etc/sddm.conf.d/theme.conf >/dev/null <<EOF
[Theme]
Current=minesddm
EOF
}

install_grub_theme() {
  if [[ ! -d /boot/grub ]]; then
    echo "GRUB directory not found, skipping GRUB theme."
    return
  fi

  mkdir -p "$GITHUB_DIR"

  clone_or_pull "https://github.com/Lxtharia/minegrub-theme.git" \
    "$GITHUB_DIR/minegrub-theme"

  sudo mkdir -p /boot/grub/themes
  sudo cp -ru "$GITHUB_DIR/minegrub-theme/minegrub" /boot/grub/themes/

  if grep -q '^#GRUB_THEME=' /etc/default/grub; then
    sudo sed -i 's|^#GRUB_THEME=.*|GRUB_THEME=/boot/grub/themes/minegrub/theme.txt|' /etc/default/grub
  elif grep -q '^GRUB_THEME=' /etc/default/grub; then
    sudo sed -i 's|^GRUB_THEME=.*|GRUB_THEME=/boot/grub/themes/minegrub/theme.txt|' /etc/default/grub
  else
    echo 'GRUB_THEME=/boot/grub/themes/minegrub/theme.txt' | sudo tee -a /etc/default/grub >/dev/null
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
  ask_pc_type

  mkdir -p "$GITHUB_DIR"

  install_yay
  install_packages
  backup_system_configs
  clean_user_configs
  install_oh_my_zsh
  install_dotfiles
  install_tmux_plugins
  apply_themes
  install_locale
  install_sddm_theme
  install_grub_theme
  enable_services
  ask_reboot
}

main "$@"
