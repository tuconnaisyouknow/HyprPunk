#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 2 || "${1:-menu}" != "standalone" && "${1:-menu}" != "menu" ]]; then
  echo "Usage: $0 [standalone|menu] [previous_menu]"
  exit 1
fi

WALL_DIR="$HOME/Pictures/Wallpapers"
THEME_PATH="$HOME/.config/rofi/catppuccin-wallpaper.rasi"
SCRIPT_DIR="$HOME/Scripts/Rofi"
WALLPAPERCTL="$HOME/Scripts/wallpaperctl.sh"

MODE="${1:-menu}"
BACK="${2:-menu}"

generate_rofi_list() {
  find -L "$WALL_DIR" -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.jpeg' \) -print0 |
    while IFS= read -r -d '' img; do
      name="$(basename "$img")"
      printf '%s\0icon\x1f%s\n' "$name" "$img"
    done
}

set +e
selection=$(
  generate_rofi_list | rofi -dmenu -show-icons \
    -p ' Choose wallpaper' \
    -theme "$THEME_PATH"
)
set -e

if [[ -z "${selection:-}" ]]; then
  if [[ "$MODE" == "menu" ]]; then
    exec "$SCRIPT_DIR/menu.sh" "$BACK"
  else
    exit 0
  fi
fi

selected_path="$WALL_DIR/$selection"

if ! error="$("$WALLPAPERCTL" set "$selected_path" 2>&1)"; then
  notify-send -u critical "Unable to change wallpaper" "$error"
  exit 1
fi
