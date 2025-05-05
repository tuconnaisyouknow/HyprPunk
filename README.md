# 🧪 dotfiles

> ⚙️ My personal Arch Linux dotfiles – optimized for Hyprland + Wayland workflow.

This repository contains my full system configuration for Arch Linux using **Hyprland**, designed to be clean, minimal, and efficient.  
Everything is managed with [GNU Stow](https://www.gnu.org/software/stow/) for modularity and ease of maintenance.

> [!NOTE]
> My dotfiles are designed for the **AZERTY** layout, so if you use a different keyboard layout you will need to adjust manually some of the following settings :
> - Hyprland config (~/.config/hypr/hyprland.conf);
>   - Change `kb_layout = fr` by `kb_layout = us`
> - `Less` config (~/.lesskey);
>   - Remove this file to use US layout;
> - `Nvim` config (~/.config/nvim/lua/config/keymaps.lua);
>   - Remove the full content of this file;
> - `Fzf` config (~/.zshrc);
>   - Remove the following line `export FZF_DEFAULT_OPTS="--bind=ctrl-k:down,ctrl-l:up"`;

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
> The script modifies your `GRUB` and `SDDM` configurations to apply themes.

To install, run the following command :

```shell
sh -c "$(curl -fsSL https://raw.githubusercontent.com/tuconnaisyouknow/dotfiles/refs/heads/master/install.sh)"
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

