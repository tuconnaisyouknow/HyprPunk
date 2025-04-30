# 🧪 dotfiles

> ⚙️ My personal Arch Linux dotfiles – optimized for Hyprland + Wayland workflow.

This repository contains my full system configuration for Arch Linux using **Hyprland**, designed to be clean, minimal, and efficient.  
Everything is managed with [GNU Stow](https://www.gnu.org/software/stow/) to keep things modular and easy to maintain.

---

## 🧰 What’s inside?

- 🌐 **Hyprland** (Wayland window manager)
- 💻 **Kitty**, **Zsh**, and **Starship**
- 📝 **Neovim** (Lua-based config)
- 🎨 GTK, Qt5/6, Kvantum theming
- 🧱 Waybar, Wlogout, Hyprlock, Hypridle, Hyprpaper
- 🛠️ CLI tools: bat, lazygit, scripts, etc.
- 📁 All configurations symlinked with GNU Stow

---

## ✅ Installation

This script is designed to work for a minimal [Arch Linux](https://wiki.archlinux.org/title/Arch_Linux) install and it may break your system. Use it at your own risk.

> [!CAUTION]
> The script modifies your `grub` and `sddm` config to apply themes

To install, execute the following commands :

```shell
sh -c "$(curl -fsSL https://raw.githubusercontent.com/tuconnaisyouknow/dotfiles/refs/heads/master/install.sh"
```

> [!IMPORTANT]
> Please reboot after the install script completes.

## 🚧 Coming soon

- 📸 **Screenshots** of my setup
- 📃 **Explanations** of each component

---

## 📎 Related

Looking for my Windows configuration (PowerShell, Windows Terminal, etc.)?  
➡️ Check out [dotfiles-windows](https://github.com/tuconnaisyouknow/dotfiles-windows)

---

## 📜 License

MIT — Feel free to explore, fork, and adapt.

