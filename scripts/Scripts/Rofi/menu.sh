#!/usr/bin/env bash

set -u

THEME_PATH="$HOME/.config/rofi/catppuccin-script.rasi"
SCRIPT_DIR="$HOME/Scripts/Rofi"
BACK_TO_EXIT=false

menu() {
  local prompt="$1"
  local options="$2"
  rofi -i -dmenu -p "$prompt" -theme "$THEME_PATH" <<<"$options"
}

back_to() {
  local parent_fn="${1:-}"
  if [[ "$BACK_TO_EXIT" == "true" ]]; then
    exit 0
  fi
  if [[ -n "$parent_fn" ]]; then
    "$parent_fn"
  else
    show_main_menu
  fi
}

show_main_menu() {
  local options=$' Apps\n Action\n Clipboard\n Style\n Configuration\n System'
  local choice
  choice="$(menu '󰍜 Menu' "$options")"

  if [[ -z "$choice" ]]; then
    exit 0
  fi

  case "$choice" in
  *Apps*)
    rofi -show drun -show-icons -display-drun " Apps "
    ;;
  *Action*)
    "$SCRIPT_DIR/action.sh" menu menu
    ;;
  *Clipboard*)
    "$SCRIPT_DIR/cliphist.sh" menu menu
    ;;
  *Style*)
    "$SCRIPT_DIR/style.sh" menu menu
    ;;
  *Configuration*)
    "$SCRIPT_DIR/configuration.sh" menu menu
    ;;
  *System*)
    "$SCRIPT_DIR/system.sh" menu menu
    ;;
  *)
    notify-send -u normal "This option doesn't exist."
    ;;
  esac
}

go_to_menu() {
  case "${1,,}" in
  apps) rofi -show drun -show-icons -display-drun " Apps " ;;
  action) "$SCRIPT_DIR/action.sh" menu menu ;;
  style) "$SCRIPT_DIR/style.sh" menu menu ;;
  configuration | config) "$SCRIPT_DIR/configuration.sh" menu menu ;;
  *) show_main_menu ;;
  esac
}

if [[ -n "${1-}" ]]; then
  BACK_TO_EXIT=true
  go_to_menu "$1"
else
  show_main_menu
fi
