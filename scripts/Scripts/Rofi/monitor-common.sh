#!/usr/bin/env bash

THEME_PATH="$HOME/.config/rofi/catppuccin-script.rasi"
SCRIPT_DIR="$HOME/Scripts/Rofi"
DISPLAYCTL="$HOME/Scripts/displayctl.sh"

monitor_choose() {
  local prompt="$1"
  local options="$2"
  rofi -i -dmenu -p "$prompt" -theme "$THEME_PATH" <<<"$options"
}

monitor_back_to_main() {
  exec "$SCRIPT_DIR/monitor.sh" "${MONITOR_ROOT_MODE:-menu}" "${MONITOR_ROOT_BACK:-config}"
}

monitor_outputs() {
  local outputs
  outputs="$("$DISPLAYCTL" outputs)" || {
    notify-send -u critical "No running Hyprland session."
    return 1
  }
  printf '%s\n' "$outputs"
}
