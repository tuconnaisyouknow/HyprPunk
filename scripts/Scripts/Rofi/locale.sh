#!/usr/bin/env bash

set -euo pipefail

if [[ $# -gt 2 || ${1:-menu} != "standalone" && ${1:-menu} != "menu" ]]; then
  echo "Usage: $0 [standalone|menu] [previous_menu]"
  exit 1
fi

THEME_PATH="$HOME/.config/rofi/catppuccin-script.rasi"
SCRIPT_DIR="$HOME/Scripts/Rofi"
CONTROLLER="$HOME/Scripts/locale-profilectl.sh"
MODE="${1:-menu}"
BACK="${2:-config}"

profile_label() {
  [[ "$1" == "fr" ]] && printf 'FR' || printf 'US'
}

choose_profile() {
  local category="$1" current="$2" prompt="$3" fr_label us_label choice profile
  fr_label="FR — fr_FR.UTF-8"
  us_label="US — en_US.UTF-8"
  [[ "$current" == "fr" ]] && fr_label="● $fr_label" || us_label="● $us_label"

  choice="$(printf '%s\n%s\n' "$fr_label" "$us_label" |
    rofi -i -dmenu -p "$prompt" -theme "$THEME_PATH")" || true
  [[ -n "$choice" ]] || return 1

  case "$choice" in
  *FR*) profile="fr" ;;
  *US*) profile="us" ;;
  *) return 1 ;;
  esac

  "$CONTROLLER" "set-$category" "$profile"
  notify-send "Locale" "$(profile_label "$profile") $category profile enabled. Restart open applications to apply it."
}

language="$($CONTROLLER get-language)"
regional="$($CONTROLLER get-regional)"
choice="$(
  printf '%s\n%s\n' \
    "󰗊 Interface language · $(profile_label "$language")" \
    "󰞇 Regional formats · $(profile_label "$regional")" |
    rofi -i -dmenu -p "󰗊 Locale" -theme "$THEME_PATH"
)" || true

if [[ -z "$choice" ]]; then
  if [[ "$MODE" == "menu" ]]; then
    exec "$SCRIPT_DIR/configuration.sh" menu "$BACK"
  fi
  exit 0
fi

case "$choice" in
*Interface*)
  if choose_profile language "$language" "󰗊 Interface language"; then
    exit 0
  fi
  ;;
*Regional*)
  if choose_profile regional "$regional" "󰞇 Regional formats"; then
    exit 0
  fi
  ;;
*) notify-send -u normal "This option doesn't exist." ;;
esac

if [[ "$MODE" == "menu" ]]; then
  exec "$0" "$MODE" "$BACK"
fi
