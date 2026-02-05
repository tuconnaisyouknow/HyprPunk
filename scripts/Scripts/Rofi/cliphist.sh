#!/usr/bin/env bash

set -euo pipefail

if [[ $# -gt 2 || $1 != "standalone" && $1 != "menu" ]]; then
  echo "Usage $0 [mode] [previous_menu]"
  exit 1
fi

THEME_PATH="$HOME/.config/rofi/catppuccin-list.rasi"
SCRIPT_DIR="$HOME/Scripts/Rofi"

MODE="${1:-menu}"
BACK="${2:-menu}"

raw="$(cliphist list)"
display="$(printf '%s\n' "$raw" | sed 's/^[^[:space:]]\+[[:space:]]\+//')"

set +e
idx=$(printf '%s\n' "$display" | rofi -dmenu -i -p ' Clipboard' -format i -theme "$THEME_PATH")
set -e

if [[ -z "$idx" ]]; then
  if [[ "$MODE" == "menu" ]]; then
    exec "$SCRIPT_DIR/menu.sh" "$BACK"
  else
    exit 0
  fi
fi

line="$(printf '%s\n' "$raw" | sed -n "$((idx + 1))p")"

printf '%s' "$line" | cliphist decode | wl-copy
