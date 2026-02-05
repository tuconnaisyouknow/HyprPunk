#!/usr/bin/env bash

if [[ $# -gt 2 || $1 != "standalone" && $1 != "menu" ]]; then
  echo "Usage $0 [mode] [previous_menu]"
  exit 1
fi

THEME_PATH="$HOME/.config/rofi/catppuccin-script.rasi"
SCRIPT_DIR="$HOME/Scripts/Rofi"

MODE="${1:-menu}"
BACK="${2:-menu}"

options=$(printf " Screenshot\n󰍹 Monitor" | rofi -i -dmenu -p " Action" -theme "$THEME_PATH")

if [[ -z "$options" ]]; then
  if [[ "$MODE" == "menu" ]]; then
    exec "$SCRIPT_DIR/menu.sh" "$BACK"
  else
    exit 0
  fi
fi

case "$options" in
*Screenshot*)
  "$SCRIPT_DIR/screenshot.sh" menu action
  ;;
*Monitor*)
  "$SCRIPT_DIR/monitor.sh" menu action
  ;;
*)
  notify-send -u normal "This option doesn't exist."
  ;;
esac
