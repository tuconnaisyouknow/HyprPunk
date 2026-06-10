#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 2 || ( $# -ge 1 && "$1" != "standalone" && "$1" != "menu" ) ]]; then
  echo "Usage $0 [mode] [previous_menu]"
  exit 1
fi

THEMES_DIR="$HOME/.dotfiles/sddm/themes"
PREVIEW_DIR="$HOME/Scripts/Rofi/preview"
SCRIPT_DIR="$HOME/Scripts/Rofi"
THEME_PATH="$HOME/.config/rofi/catppuccin-sddm.rasi"
SDDM_SCRIPT="$HOME/Scripts/sddm.sh"
ASKPASS_SCRIPT="$SCRIPT_DIR/sudo-askpass.sh"

MODE="${1:-menu}"
BACK="${2:-style}"

preview_for_theme() {
  local theme_name="$1"
  local ext

  for ext in png jpg jpeg webp; do
    if [[ -f "$PREVIEW_DIR/$theme_name.$ext" ]]; then
      printf '%s\n' "$PREVIEW_DIR/$theme_name.$ext"
      return 0
    fi
  done

  return 1
}

generate_rofi_list() {
  local theme_path theme_name preview_path

  find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d -print0 |
    sort -z |
    while IFS= read -r -d '' theme_path; do
      theme_name="$(basename "$theme_path")"

      if preview_path="$(preview_for_theme "$theme_name")"; then
        printf '%s\0icon\x1f%s\n' "$theme_name" "$preview_path"
      else
        printf '%s\n' "$theme_name"
      fi
    done
}

set +e
selection=$(
  generate_rofi_list | rofi -dmenu -show-icons \
    -p '󰔎 Choose SDDM theme' \
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

askpass_state="$(mktemp)"
trap 'rm -f "$askpass_state"' EXIT
sudo_cached=false

if sudo -n true 2>/dev/null; then
  sudo_cached=true
fi

if SDDM_ASKPASS_STATE="$askpass_state" SUDO_ASKPASS="$ASKPASS_SCRIPT" sudo -A env HOME="$HOME" "$SDDM_SCRIPT" "$selection"; then
  notify-send -u normal "SDDM theme applied" "$selection"
elif [[ "$sudo_cached" == "false" ]] && ! grep -qx "provided" "$askpass_state" 2>/dev/null; then
  exit 0
else
  notify-send -u critical "Failed to apply SDDM theme" "$selection"
  exit 1
fi
