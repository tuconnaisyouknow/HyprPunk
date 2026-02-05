#!/usr/bin/env bash

if [[ $# -gt 2 || $1 != "standalone" && $1 != "menu" ]]; then
  echo "Usage $0 [menu|standalone] [previous_menu]"
  exit 1
fi

THEME_PATH="$HOME/.config/rofi/catppuccin-script.rasi"
SCRIPT_DIR="$HOME/Scripts/Rofi"

MODE="${1:-menu}"
BACK="${2:-menu}"

options=$(printf " Hyprland\n Neovim\n Starship\n Kitty" | rofi -i -dmenu -p " Configuration" -theme "$THEME_PATH")

if [[ -z "$options" ]]; then
  if [[ "$MODE" == "menu" ]]; then
    exec "$SCRIPT_DIR/menu.sh" "$BACK"
  else
    exit 0
  fi
fi

case "$options" in
*Hyprland*)
  "$SCRIPT_DIR/hyprland-config.sh" menu config
  ;;
*Neovim*)
  kitty nvim +'lua Snacks.dashboard.pick("files", { cwd = vim.fn.stdpath("config") })'
  ;;
*Starship*)
  kitty nvim "$HOME/.config/starship.toml"
  ;;
*Kitty*)
  kitty nvim "$HOME/.config/kitty/kitty.conf"
  ;;
*)
  notify-send -u normal "This option doesn't exist."
  ;;
esac
