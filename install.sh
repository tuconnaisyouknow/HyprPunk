#!/bin/bash

# Asking user if he has a desktop or a laptop pc
while [[ true ]]; do
  read -p "Are you on a laptop or desktop ? [l/d]: " pc_input
  case "$pc_input" in
  l | L)
    pc_type=laptop
    break
    ;;
  d | D)
    pc_type=desktop
    break
    ;;
  *)
    echo "Invalid option. Please enter 'l' for laptop or 'd' for desktop."
    ;;
  esac
done

# Installing yay
if ! command -v yay &>/dev/null; then
  sudo pacman -S --needed git base-devel
  mkdir ~/GitHub
  cd ~/GitHub
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si
fi

# Installing all needed packages
yay -S --needed zsh kitty neovim fzf eza \
  fastfetch starship hyprland waybar hyprcursor \
  hypridle hyprlock hyprshot hyprpaper sddm \
  wlogout rofi bat thunar stow \
  ark cava waybar-module-pacman-updates-git network-manager-applet blueman \
  fd ripgrep lazygit cliphist bc \
  qt5ct qt5-quickcontrols2 qt5-wayland kvantum qt6ct-kde \
  qt6-tools qt6-wayland layer-shell-qt5 layer-shell-qt ttf-jetbrains-mono-nerd \
  ttf-font-awesome ttf-apple-emoji rose-pine-cursor rose-pine-gtk-theme-full rose-pine-hyprcursor

# Installing oh my zsh and its plugins
[[ -d ~/.oh-my-zsh ]] && mv ~/.oh-my-zsh ~/.backup
RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/MichaelAquilina/zsh-you-should-use.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/you-should-use
git clone https://github.com/fdellwing/zsh-bat.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-bat

# Creating required folders
mkdir -p ~/.backup ~/.dotfiles

# Creating a backup of all configuration files if they exist
[[ -d ~/.config/nvim ]] && mv ~/.config/nvim ~/.backup
[[ -d ~/.config/bat ]] && mv ~/.config/bat ~/.backup
[[ -d ~/.config/cava ]] && mv ~/.config/cava ~/.backup
[[ -d ~/.config/fastfetch ]] && mv ~/.config/fastfetch ~/.backup
[[ -d ~/.config/gtk-3.0 ]] && mv ~/.config/gtk-3.0 ~/.backup
[[ -f ~/.config/hypr/hyprland.conf ]] && mv ~/.config/hypr/hyprland.conf ~/.backup
[[ -f ~/.config/hypr/hyprlock.conf ]] && mv ~/.config/hypr/hyprlock.conf ~/.backup
[[ -f ~/.config/hypr/hyprpaper.conf ]] && mv ~/.config/hypr/hyprpaper.conf ~/.backup
[[ -f ~/.config/hypr/hypridle.conf ]] && mv ~/.config/hypr/hypridle.conf ~/.backup
[[ -d ~/.config/kitty ]] && mv ~/.config/kitty ~/.backup
[[ -d ~/.config/Kvantum ]] && mv ~/.config/Kvantum ~/.backup
[[ -f ~/.lesskey ]] && mv ~/.lesskey ~/.backup
[[ -d ~/.config/qt5ct ]] && mv ~/.config/qt5ct ~/.backup
[[ -d ~/.config/qt6ct ]] && mv ~/.config/qt6ct ~/.backup
[[ -d ~/.config/rofi ]] && mv ~/.config/rofi ~/.backup
[[ -d ~/Scripts ]] && mv ~/Scripts ~/.backup
[[ -f ~/.config/starship.toml ]] && mv ~/.config/starship.toml ~/.backup
[[ -d ~/.config/waybar ]] && mv ~/.config/waybar ~/.backup
[[ -d ~/.config/wlogout ]] && mv ~/.config/wlogout ~/.backup
[[ -f ~/.zshrc ]] && mv ~/.zshrc ~/.backup
[[ -f /boot/grub/grub.cfg ]] && sudo cp /boot/grub/grub.cfg ~/.backup
[[ -f /etc/default/grub ]] && sudo cp /etc/default/grub ~/.backup

# Stowing dotfiles
cd ~/.dotfiles
git clone https://github.com/tuconnaisyouknow/dotfiles.git .
if [[ "$pc_type" == "laptop" ]]; then
  stow bat cava fastfetch hypridle hyprland hyprlock hyprpaper kitty kvantum less nvim qt5 qt6 rofi scripts starship waybar wlogout zsh
else
  stow bat cava fastfetch hypridle hyprland hyprlock-desktop hyprpaper kitty kvantum less nvim qt5 qt6 rofi scripts starship waybar-desktop wlogout zsh
fi

# Applying GTK theme
gsettings set org.gnome.desktop.interface gtk-theme 'rose-pine-moon-gtk'
gsettings set org.gnome.desktop.interface icon-theme 'rose-pine-moon-icons'
gsettings set org.gnome.desktop.interface font-name 'JetBrainsMono Nerd Font 9'

# Installing french locale
grep -q '^[[:space:]]*fr_FR.UTF-8[[:space:]]\+UTF-8' /etc/locale.gen ||
  sudo sed -i '/^[[:space:]]*#\s*fr_FR.UTF-8\s\+UTF-8/s/^#\s*//' /etc/locale.gen ||
  echo "fr_FR.UTF-8 UTF-8" | sudo tee -a /etc/locale.gen >/dev/null

# Generating french locale
sudo locale-gen

# Applying sddm theme
git clone https://github.com/Davi-S/sddm-theme-minesddm.git ~/GitHub/sddm-theme-minesddm
sudo cp -r ~/GitHub/sddm-theme-minesddm/minesddm /usr/share/sddm/themes/
if grep -q '^\[Theme\]' /etc/sddm.conf 2>/dev/null; then
  sudo sed -i '/^\[Theme\]/,/^\[/{ 
    /^\[Theme\]/b
    /^Current=/cCurrent=minesddm
    t
    $aCurrent=minesddm
  }' /etc/sddm.conf
else
  echo -e "\n[Theme]\nCurrent=minesddm" | sudo tee -a /etc/sddm.conf >/dev/null
fi

# Applying grub theme
git clone https://github.com/Lxtharia/minegrub-theme.git ~/GitHub/minegrub-theme
cd ~/GitHub/minegrub-theme
sudo cp -ruv ./minegrub /boot/grub/themes/
if grep -q '^#GRUB_THEME=' /etc/default/grub; then
  # Décommenter et modifier la ligne existante
  sudo sed -i 's|^#GRUB_THEME=.*|GRUB_THEME=/boot/grub/themes/minegrub/theme.txt|' /etc/default/grub
elif ! grep -q '^GRUB_THEME=' /etc/default/grub; then
  # Ajouter la ligne si absente
  echo 'GRUB_THEME=/boot/grub/themes/minegrub/theme.txt' | sudo tee -a /etc/default/grub >/dev/null
fi
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Enabling sddm
sudo systemctl enable sddm

# Asking if the user want to reboot now
read -p "Do you want to reboot now ? [y/n]: " answer
case "$answer" in
[yY])
  sudo reboot
  ;;
[nN] | *)
  exit 1
  ;;
esac
