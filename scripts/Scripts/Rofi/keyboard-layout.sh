#!/usr/bin/env bash

set -euo pipefail

if [[ $# -gt 2 ]] || [[ $# -gt 0 && $1 != "standalone" && $1 != "menu" ]]; then
  echo "Usage: $0 [menu|standalone] [previous_menu]"
  exit 1
fi

THEME_PATH="$HOME/.config/rofi/catppuccin-script.rasi"
SCRIPT_DIR="$HOME/Scripts/Rofi"
CONTROLLER="$HOME/Scripts/keyboard-layoutctl.sh"
MODE="${1:-menu}"
BACK="${2:-config}"
current="$($CONTROLLER get)"

fr_label="FR — AZERTY · navigation j k l m"
us_label="US — QWERTY · navigation h j k l"
[[ "$current" == "fr" ]] && fr_label="● $fr_label" || us_label="● $us_label"

choice="$(printf '%s\n%s\n' "$fr_label" "$us_label" |
  rofi -i -dmenu -p " Keyboard" -theme "$THEME_PATH")"

if [[ -z "$choice" ]]; then
  if [[ "$MODE" == "menu" ]]; then
    exec "$SCRIPT_DIR/configuration.sh" menu "$BACK"
  fi
  exit 0
fi

case "$choice" in
  *FR*) layout="fr" ;;
  *US*) layout="us" ;;
  *) exit 0 ;;
esac

"$CONTROLLER" set "$layout"
notify-send "Keyboard layout" "${layout^^} layout enabled"
