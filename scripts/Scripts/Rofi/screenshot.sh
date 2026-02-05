#!/usr/bin/env bash

if [[ $# -gt 2 || $1 != "standalone" && $1 != "menu" ]]; then
  echo "Usage $0 [mode] [previous_menu]"
  exit 1
fi

THEME_PATH="$HOME/.config/rofi/catppuccin-script.rasi"
SCRIPT_DIR="$HOME/Scripts/Rofi"

MODE="${1:-menu}"
BACK="${2:-menu}"

options=$(printf "󰩬 Region\n Annotate\n󰍹 Screen" | rofi -i -dmenu -p " Screenshot" -theme "$THEME_PATH")

if [[ -z "$options" ]]; then
  if [[ "$MODE" == "menu" ]]; then
    exec "$SCRIPT_DIR/menu.sh" "$BACK"
  else
    exit 0
  fi
fi

case "$options" in
*Region*)
  hyprshot -m region -o ~/Pictures/Screenshots
  ;;
*Annotate*)
  hyprshot -m region --raw | satty --filename -
  ;;
*Screen*)
  hyprshot -m active -m output -o ~/Pictures/Screenshots
  ;;
*)
  notify-send -u normal "This option doesn't exist."
  ;;
esac
